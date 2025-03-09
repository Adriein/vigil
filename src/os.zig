const std: type = @import("std");

const LINUX_PROCESS_FILE: *const [5:0]u8 = "/proc";

pub fn program_pid() !void {
    const file: std.fs.File = try std.fs.openFileAbsolute(LINUX_PROCESS_FILE, .{ .mode = std.fs.File.OpenMode.read_only });

    defer file.close();

    const file_stat: std.fs.File.Stat = try file.stat();

    const file_size: usize = @intCast(file_stat.size);

    std.debug.print("File contents: {}\n", .{file_size});

    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();

    const buffer: []u8 = try arena.allocator().alloc(u8, file_size);

    const bytes_read: usize = try file.readAll(buffer);

    std.debug.print("File contents: {}\n", .{bytes_read});
}
