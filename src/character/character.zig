const std: type = @import("std");

pub const Character: type = struct {
    pub fn init() Character {
        return Character{};
    }

    pub fn speed(_: *const Character) !void {
        const base: u64 = 0x7ae992816000;
        const offsets = [_]usize{ 0xCB0, 0x40, 0x140, 0x28, 0xA8 };
        var address = base;

        for (offsets) |offset| {
            address += offset;
        }

        std.debug.print("Final address: {x}\n", .{address});
    }
};
