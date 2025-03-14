const std = @import("std");
const tls = @import("tls");
const thread = std.Thread;

fn parseUrl(uri: []u8) ?std.Uri {
    return std.Uri.parse(uri) catch {
        return null;
    };
}

fn handleConnection(raw_connection: std.net.Server.Connection, auth: *tls.config.CertKeyPair, root_dir: []u8, port: i32) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // 1024 is hard limit specified by the spec but it's for URI part.
    // Use 1026 as buffer size because URI should be followed by "\r\n"
    var read_buffer: [1026]u8 = undefined;

    var connection = try tls.server(raw_connection.stream, .{ .auth = auth });
    // gemini clients won't show the response until connection is closed
    defer connection.close() catch {}; // nothing to catch in here really.

    const read_len = try connection.read(&read_buffer);

    // no response should be send if request doesn't end with \r\n
    // this one also protects us from too big request body and sends
    if (!std.mem.endsWith(u8, read_buffer[0..read_len], "\r\n")) {
        return;
    }

    const uri = parseUrl(read_buffer[0..read_len]) orelse {
        _ = try connection.write("59\r\n");
        return;
    };

    if (uri.port) |p| {
        if (p != port) {
            _ = try connection.write("53\r\n");
            return;
        }
    }

    const parsed_path = std.mem.trimRight(u8, uri.path.percent_encoded, "\r\n");

    // path to a file
    var path_to_requested_file = std.mem.join(allocator, "", &.{ root_dir, parsed_path }) catch {
        _ = try connection.write("50\r\n");
        _ = try connection.write("Cannot construct a path to resource.");
        return;
    };

    // if path ends with .gmi then it's a file.
    // TODO: this is very naive and quick/bad way of doing that.
    // I should use std.fs to check if path is a file or a folder.
    if (!std.mem.endsWith(u8, path_to_requested_file, ".gmi")) {
        path_to_requested_file = try std.mem.concat(allocator, u8, &.{ std.mem.trimRight(u8, path_to_requested_file, "/"), "/", "index.gmi" });
    }

    // can we open a file? default mode is readonly
    const requested_file = std.fs.openFileAbsolute(path_to_requested_file, .{}) catch {
        _ = try connection.write("51\r\n");
        return;
    };

    var requested_file_buffer: [1024]u8 = undefined;

    // success header
    _ = try connection.write("20 text/gemini \r\n"); // TODO: unhardcode mimetype

    var bytes_read = try requested_file.readAll(&requested_file_buffer);
    while (bytes_read == requested_file_buffer.len) {
        _ = try connection.write(requested_file_buffer[0..bytes_read]);
        @memset(&requested_file_buffer, 0);
        bytes_read = try requested_file.readAll(&requested_file_buffer);
    }
    _ = try connection.write(requested_file_buffer[0..bytes_read]);

    // send \r\n as a way to tell "it's all done"
    _ = try connection.write("\r\n");
}

pub fn main() !void {
    std.debug.print("Starting the server...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Must specify the cert as first arg...\n", .{});
        std.process.exit(1);
    }

    if (args.len < 3) {
        std.debug.print("Must root folder as second arg...\n", .{});
        std.process.exit(1);
    }

    const cert_file_name = args[1];
    const root_dir = args[2];

    const pg_file = try std.fs.cwd().openFile(cert_file_name, .{});
    defer pg_file.close();

    // const cert_file_name = if (args.len > 1) args[1] else "example/cert/pg2600.txt";
    const dir = try std.fs.cwd().openDir(".", .{});
    var auth = try tls.config.CertKeyPair.load(allocator, dir, "certificate.crt", "private.key");

    const ADDR = "0.0.0.0";
    const PORT = 1965;

    const address = try std.net.Address.parseIp(ADDR, PORT);
    var server = std.net.Address.listen(address, .{}) catch |e| {
        std.debug.print("Error happened during listen ({s}).\n", .{@typeName(@TypeOf(e))});
        std.process.exit(1);
    };
    defer server.deinit();

    // indefinitely listen for new connections
    while (true) {
        std.debug.print("Listen for new connection.\n", .{});
        const connection = try server.accept();
        std.debug.print("Got new connection.\n", .{});
        var t = try thread.spawn(.{}, handleConnection, .{ connection, &auth, root_dir, PORT });
        t.detach();
    }
}
