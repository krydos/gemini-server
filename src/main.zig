const std = @import("std");

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
        var buffer: [1024]u8 = undefined;
        _ = try connection.stream.read(&buffer);
        std.debug.print("Input {any}.\n", .{buffer});
        _ = try connection.stream.write(&buffer);
        connection.stream.close();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
