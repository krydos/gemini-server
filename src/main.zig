const std = @import("std");
const tls = @import("tls");
const thread = std.Thread;

fn handleConnection(raw_connection: std.net.Server.Connection, auth: *tls.config.CertKeyPair) !void {
    // TODO: this should probably be a temp buffer.
    // When connection.read(&buffer) is called
    // it can return the same amount of bytes
    // as the buffer size.
    // It means that we tried to read from connection
    // and we filled in our buffer completely which in turn means
    // that there is POSSIBLY more data on the other end and
    // we should read it again.
    // Should come up with a dynamically allocated buffer.
    var buffer: [1024]u8 = undefined;
    errdefer raw_connection.stream.close();

    var connection = try tls.server(raw_connection.stream, .{ .auth = auth });

    const readLen = try connection.read(&buffer);

    // TODO: this should be a loop in case we got
    // an input greater than the buffer size.
    if (readLen < buffer.len) {
        std.debug.print("We've read everything from buffer {s}\n", .{buffer});
    } else {
        std.debug.print("we haven't read everything from buffer\n", .{});
    }

    _ = try connection.write("20\r\n");
    // only reply with the content and not the whole buffer
    // because the rest of the buffer may contain some 0xFF stuff
    _ = try connection.write(buffer[0..readLen]);

    // gemini clients won't show the response until connection is closed
    _ = try connection.close();
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

    const file_name = args[1];

    const pg_file = try std.fs.cwd().openFile(file_name, .{});
    defer pg_file.close();

    // const file_name = if (args.len > 1) args[1] else "example/cert/pg2600.txt";
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
        var t = try thread.spawn(.{}, handleConnection, .{ connection, &auth });
        t.detach();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
