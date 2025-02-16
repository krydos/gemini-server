const std = @import("std");
const thread = std.Thread;

fn handleConnection(connection: std.net.Server.Connection) !void {
    var buffer: [1024]u8 = undefined;
    errdefer connection.stream.close();

    // how do I break the loop on connection close?
    // read or write should throw an error if connection close
    // so it should break the loop... hopefully.
    while (true) {
        _ = try connection.stream.read(&buffer);
        _ = try connection.stream.write(&buffer);
        @memset(&buffer, 0);
    }
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("Starting the server...\n", .{});

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
        var t = try thread.spawn(.{}, handleConnection, .{connection});
        t.detach();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
