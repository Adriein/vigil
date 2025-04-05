const std: type = @import("std");
const os: type = @import("shared/os.zig");
const entity: type = @import("vigil/entity.zig");

fn handleSigint(_: c_int) callconv(.C) void {
    std.debug.print("Received SIGINT (Ctrl+C). Exiting...\n", .{});
    std.os.linux.exit(0);
}

pub fn main() !void {
    std.debug.print("Starting Vigil on watch mode.\n", .{});

    // Set up a signal handler for SIGINT
    const act: std.os.linux.Sigaction = std.os.linux.Sigaction{
        .handler = .{ .handler = handleSigint },
        .mask = std.os.linux.empty_sigset,
        .flags = 0,
    };

    const result: usize = std.os.linux.sigaction(std.os.linux.SIG.INT, &act, null);

    if (result != 0) {
        std.debug.print("Failed to set up signal handler: {}\n", .{result});

        std.process.exit(1);

        return;
    }

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();

    const process: os.TibiaClientProcess = try os.TibiaClientProcess.init(arena.allocator());

    std.debug.print("Tibia pid: {d}\n", .{process.pid});

    _ = try entity.Game.init(process);

    // Main loop
    //while (true) {
    //  std.debug.print("Running...\n", .{});
    //  std.time.sleep(1 * std.time.ns_per_s); // Sleep for 1 second
    //}

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
