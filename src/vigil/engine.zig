const std: type = @import("std");
const os: type = @import("../shared/os.zig");
const entity: type = @import("../game/entity.zig");

fn handleSigint(_: c_int) callconv(.C) void {
    std.debug.print("Received SIGINT (Ctrl+C). Exiting...\n", .{});
    std.os.linux.exit(0);
}

pub const VigilEngine: type = struct {
    pub fn init() VigilEngine {
        return VigilEngine{};
    }

    pub fn execute(self: *const VigilEngine) !void {
        self.setupProgramExit();

        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        defer arena.deinit();

        const process: os.TibiaClientProcess = try os.TibiaClientProcess.init(arena.allocator());

        std.debug.print("Tibia pid: {d}\n", .{process.pid});

        const tibia: entity.Game = try entity.Game.init(process);

        const player: entity.Player = tibia.player();

        while (true) {
            std.debug.print("Running...\n", .{});

            try player.health(tibia.health_address);
            try player.mana(tibia.mana_address);
            try player.speed(tibia.speed_address);

            std.time.sleep(0.5 * std.time.ns_per_s); // Sleep for 1 second
        }
    }

    fn setupProgramExit(_: *const VigilEngine) void {
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
        }
    }
};
