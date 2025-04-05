const std: type = @import("std");
const os: type = @import("../shared/os.zig");

pub const Game: type = struct {
    //POINTERS
    pub const SPEED_POINTER: []const u8 = "libdbus-1.so.3.19.13[5]+1E8->D8->3E8->F0->80";

    pub fn init(process: os.TibiaClientProcess) !Game {
        const speed_pointer: os.Pointer = try os.Pointer.init(SPEED_POINTER);
        try process.resolvePointer(speed_pointer);
        return Game{};
    }
};

pub const Player: type = struct {
    pub fn init() !void {}

    pub fn speed(_: *const Player) !void {
        const base: u64 = 0x7ae992816000;
        const offsets = [_]usize{ 0xCB0, 0x40, 0x140, 0x28, 0xA8 };
        var address = base;

        for (offsets) |offset| {
            address += offset;
        }

        std.debug.print("Final address: {x}\n", .{address});
    }
};
