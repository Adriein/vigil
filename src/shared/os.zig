const std: type = @import("std");
const util: type = @import("util.zig");

const LINUX_PROCESS_DIR: *const [5:0]u8 = "/proc";

fn isDir(entry: std.fs.Dir.Entry) bool {
    return entry.kind == std.fs.File.Kind.directory;
}

pub fn pid() !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();

    var directory: std.fs.Dir = try std.fs.openDirAbsolute(LINUX_PROCESS_DIR, .{ .iterate = true });

    defer directory.close();

    var iterator: std.fs.Dir.Iterator = directory.iterate();

    while (try iterator.next()) |entry| {
        if (isDir(entry) and util.isNumber(entry.name)) {
            const buffer: []u8 = try arena.allocator().alloc(u8, LINUX_PROCESS_DIR.len + entry.name.len + 1);

            const path: []u8 = try std.fmt.bufPrint(buffer, "{s}{s}{s}", .{ LINUX_PROCESS_DIR, "/", entry.name });

            std.debug.print("File name: {s} ------------------------------------------------\n", .{entry.name});

            var subdir: std.fs.Dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });

            var subdir_iterator: std.fs.Dir.Iterator = subdir.iterate();

            while (try subdir_iterator.next()) |subdir_entry| {
                std.debug.print("File name: {s}\n", .{subdir_entry.name});
                std.debug.print("File type: {}\n", .{subdir_entry.kind});
                //if (isDir(subdir_entry)) {
                //std.debug.print("File name: {s}\n", .{subdir_entry.name});
                //}
            }
        }
    }

    //var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    //defer arena.deinit();

    //const buffer: []u8 = try arena.allocator().alloc(u8, file_size);

    //const bytes_read: usize = try file.readAll(buffer);

    //std.debug.print("File contents: {}\n", .{bytes_read});*/
}
