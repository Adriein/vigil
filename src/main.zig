const std: type = @import("std");
const os: type = @import("shared/os.zig");
const engine: type = @import("vigil/engine.zig");

fn handleSigint(_: c_int) callconv(.C) void {
    std.debug.print("Received SIGINT (Ctrl+C). Exiting...\n", .{});
    std.os.linux.exit(0);
}

pub fn main() !void {
    std.debug.print("Starting Vigil on watch mode.\n", .{});

    const vigil: engine.VigilEngine = engine.VigilEngine.init();

    try vigil.execute();

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // const stdout_file= std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
