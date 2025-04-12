const std: type = @import("std");
const os: type = @import("../shared/os.zig");

pub const Game: type = struct {
    //POINTERS
    pub const SPEED_POINTER: []const u8 = "libdbus-1.so.3.19.13[5]+1E8->D8->3E8->F0->80";

    //ADDRESS
    speed_address: u64,
    mana_address: u64, // -16 bytes from speed_address
    health_address: u64, // -72 bytes from health_address

    pub fn init(process: os.TibiaClientProcess) !Game {
        const speed_pointer: os.Pointer = try os.Pointer.init(SPEED_POINTER);
        const speed_address: u64 = try process.resolvePointer(speed_pointer);
        const mana_address: u64 = speed_address - 0x10;
        const health_address: u64 = mana_address - 0x48;

        std.debug.print("Speed memory address 0x{x}", .{speed_address});

        return Game{
            .speed_address = speed_address,
            .mana_address = mana_address,
            .health_address = health_address,
        };
    }
};

pub const Player: type = struct {
    pub fn init() !Player {
        return Player{};
    }

    pub fn speed(_: *const Player) !void {}
};
