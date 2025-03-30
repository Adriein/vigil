const std: type = @import("std");

//POINTERS
const SPEED_POINTER: []const u8 = "libdbus-1.so.3.19.13[5]+1E8->D8->3E8->F0->80";

pub const Player: type = struct {
    //const SPEED_POINTER: []const u8 = [_]u8{ "libdbus-1.so.3.19.13", "0x1E8", "0xD8", "0x3E8", "0xF0", "0x80" };

    pub fn init() Player {
        const iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(u8, SPEED_POINTER, "]");

        iterator.first();
        return Player{};
    }

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
