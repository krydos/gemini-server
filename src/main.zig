const std = @import("std");
const tls = @import("tls");
const thread = std.Thread;

// we just return "/" if we can't parse the uri
fn parsePath(uri: []u8) []const u8 {
    const parsed_uri = std.Uri.parse(uri) catch {
        return "/";
    };
    return parsed_uri.path.percent_encoded;
}

fn handleConnection(raw_connection: std.net.Server.Connection, auth: *tls.config.CertKeyPair, root_dir: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // TODO: this should probably be a temp buffer.
    // When connection.read(&buffer) is called
    // it can return the same amount of bytes
    // as the buffer size.
    // It means that we tried to read from connection
    // and we filled in our buffer completely which in turn means
    // that there is POSSIBLY more data on the other end and
    // we should read it again.
    // Should come up with a dynamically allocated buffer.
    var read_buffer: [1024]u8 = undefined;

    // gemini clients won't show the response until connection is closed
    defer raw_connection.stream.close();

    var connection = try tls.server(raw_connection.stream, .{ .auth = auth });

    const read_len = try connection.read(&read_buffer);

    // TODO: this should be a loop in case we got
    // an input greater than the buffer size.
    if (read_len < read_buffer.len) {
        std.debug.print("We've read everything from buffer {s}\n", .{read_buffer[0..read_len]});
    } else {
        std.debug.print("we haven't read everything from buffer\n", .{});
    }

    const parsed_path = std.mem.trimRight(u8, parsePath(read_buffer[0..read_len]), "\r\n");

    // path to a file
    const path_to_requested_file = std.mem.join(allocator, "", &.{ root_dir, parsed_path }) catch {
        _ = try connection.write("50\r\n");
        _ = try connection.write("Cannot constract a path to resource.");
        return;
    };

    // can we open a file? default mode is readonly
    const requested_file = std.fs.openFileAbsolute(path_to_requested_file, .{}) catch {
        _ = try connection.write("51\r\n");
        _ = try connection.write("Resource not found.");
        return;
    };

    var requested_file_buffer: [1024]u8 = undefined;

    _ = try connection.write("20\r\n");

    var bytes_read = try requested_file.readAll(&requested_file_buffer);
    while (bytes_read == requested_file_buffer.len) {
        _ = try connection.write(requested_file_buffer[0..bytes_read]);
        @memset(&requested_file_buffer, 0);
        bytes_read = try requested_file.readAll(&requested_file_buffer);
    }
    _ = try connection.write(requested_file_buffer[0..bytes_read]);
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
        var t = try thread.spawn(.{}, handleConnection, .{ connection, &auth, root_dir });
        t.detach();
    }
}
