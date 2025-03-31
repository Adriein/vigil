const std: type = @import("std");
const os: type = @import("../shared//os.zig");

//POINTERS
const RAW_SPEED_POINTER: []const u8 = "libdbus-1.so.3.19.13[5]+1E8->D8->3E8->F0->80";

const TibiaPointerError: type = error{WrongFormattedPointer};

pub const TibiaPointer: type = struct {
    base_module: []const u8,
    base_module_load_pos: u8,
    pointer_chain: []const u8,

    pub fn init(raw_pointer: []const u8) !TibiaPointer {
        var iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            raw_pointer,
            "]",
        );

        const raw_base_module: []const u8 = iterator.first();
        const raw_not_processed_pointer: ?[]const u8 = iterator.next();

        const pointer: []const u8 = raw_not_processed_pointer orelse return TibiaPointerError.WrongFormattedPointer;

        var base_module_iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            raw_base_module,
            "[",
        );

        const base_module: []const u8 = base_module_iterator.first();
        const base_module_load_pos: []const u8 = base_module_iterator.next() orelse return TibiaPointerError.WrongFormattedPointer;

        const pointer_without_sum_char: []const u8 = pointer[1..];

        return TibiaPointer{
            .base_module = base_module,
            .base_module_load_pos = base_module_load_pos[0],
            .pointer_chain = pointer_without_sum_char,
        };
    }
};

pub const Player: type = struct {
    //const SPEED_POINTER: []const u8 = [_]u8{ "libdbus-1.so.3.19.13", "0x1E8", "0xD8", "0x3E8", "0xF0", "0x80" };

    pub fn init(process: os.TibiaClientProcess) !void {
        const pointer: TibiaPointer = try TibiaPointer.init(RAW_SPEED_POINTER);

        _ = try resolvePointer(process, pointer);
    }

    fn resolvePointer(process: os.TibiaClientProcess, pointer: TibiaPointer) !void {
        std.debug.print("a: {s}\n", .{pointer.base_module});
        std.debug.print("b: {d}\n", .{pointer.base_module_load_pos});
        const base_address: []const u8 = try process.getModuleVirtualMemoryAddress(
            pointer.base_module,
            pointer.base_module_load_pos,
        );

        const decimal_base_address: u64 = try std.fmt.parseInt(u64, base_address, 16);

        var pointer_chain_iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            pointer.pointer_chain,
            "->",
        );

        const decimal_offset: u64 = try std.fmt.parseInt(u64, pointer_chain_iterator.first(), 16);

        const a = decimal_base_address + decimal_offset;

        try process.readContentFromMemoryAddress(a);

        //while (pointer_chain_iterator.next()) | offset| {
        //    const decimal_offset: u64 = try std.fmt.parseInt(u64, offset, 16);

        //    process.readContentFromMemoryAddress(decimal_offset);
        //}
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
