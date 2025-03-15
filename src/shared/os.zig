const std: type = @import("std");
const Dir: type = std.fs.Dir;
const util: type = @import("util.zig");

const LINUX_PROCESS_DIR: *const [5:0]u8 = "/proc";
const CWD_SYMLINK: *const [3:0]u8 = "cwd";

fn isDir(entry: std.fs.Dir.Entry) bool {
    return entry.kind == std.fs.File.Kind.directory;
}

fn isSymLink(entry: std.fs.Dir.Entry) bool {
    return entry.kind == std.fs.File.Kind.sym_link;
}

pub fn pid(bin_name: []u8) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();

    var directory: Dir = try std.fs.openDirAbsolute(LINUX_PROCESS_DIR, .{ .iterate = true });

    defer directory.close();

    var iterator: Dir.Iterator = directory.iterate();

    while (try iterator.next()) |entry| {
        if (isDir(entry) and util.isNumber(entry.name)) {
            const path_buffer: []u8 = try arena.allocator().alloc(u8, LINUX_PROCESS_DIR.len + entry.name.len + 1);

            const path: []u8 = try std.fmt.bufPrint(path_buffer, "{s}{s}{s}", .{ LINUX_PROCESS_DIR, "/", entry.name });

            std.debug.print("Path: {s} ------------------------------------------------\n", .{path});

            var subdir: Dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });

            arena.allocator().free(path_buffer);

            var subdir_iterator: Dir.Iterator = subdir.iterate();

            while (try subdir_iterator.next()) |subdir_entry| {
                if (isSymLink(subdir_entry) and std.mem.eql(u8, subdir_entry.name, CWD_SYMLINK)) {
                    const symlink_buffer: []u8 = try arena.allocator().alloc(u8, std.fs.MAX_PATH_BYTES);

                    const sym_link: []u8 = subdir.readLink(subdir_entry.name, symlink_buffer) catch |err| {
                        switch (err) {
                            Dir.ReadLinkError.AccessDenied => {
                                continue;
                            },
                            Dir.ReadLinkError.FileNotFound => {
                                continue;
                            },
                            else => {
                                std.debug.print("Error: {}\n", .{err});
                                std.debug.print("File: {s}\n", .{subdir_entry.name});
                                return err;
                            },
                        }
                    };

                    if (std.mem.eql(u8, bin_name, sym_link)) {
                        std.debug.print("Pid: {s}\n", .{subdir_entry.name});
                    }

                    arena.allocator().free(path_buffer);
                }
            }
        }
    }

    //var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    //defer arena.deinit();

    //const buffer: []u8 = try arena.allocator().alloc(u8, file_size);

    //const bytes_read: usize = try file.readAll(buffer);  and std.mem.eql(u8, subdir_entry.name, "cwd")

    //std.debug.print("File contents: {}\n", .{bytes_read});*/
}
