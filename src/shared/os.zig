const std: type = @import("std");

const LINUX_PROCESS_DIR: *const [5:0]u8 = "/proc";

pub fn program_pid() !void {
    var directory: std.fs.Dir = try std.fs.openDirAbsolute(LINUX_PROCESS_DIR, .{ .iterate = true });

    defer directory.close();

    var iterator: std.fs.Dir.Iterator = directory.iterate();

    while (try iterator.next()) |entry| {
        if (entry.kind == std.fs.File.Kind.directory) {
            const path: []u8 = LINUX_PROCESS_DIR ++ entry.name;

            var child_dir: std.fs.Dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });

            var child_dir_iterator: std.fs.Dir.Iterator = child_dir.iterate();

            while (try child_dir_iterator.next()) |child_entry| {
                std.debug.print("File name: {s}\n", .{child_entry.name});
                std.debug.print("File kind: {}\n", .{child_entry.kind});
            }
        }
    }

    //var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    //defer arena.deinit();

    //const buffer: []u8 = try arena.allocator().alloc(u8, file_size);

    //const bytes_read: usize = try file.readAll(buffer);

    //std.debug.print("File contents: {}\n", .{bytes_read});*/
}
