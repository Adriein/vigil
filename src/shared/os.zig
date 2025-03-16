const std: type = @import("std");
const util: type = @import("util.zig");
const fs: type = @import("fs.zig");

const Dir: type = std.fs.Dir;
const File: type = std.fs.File;

const LINUX_PROCESS_DIR: *const [5:0]u8 = "/proc";
const CWD_SYMLINK: *const [3:0]u8 = "cwd";
const EXE_SYMLINK: *const [3:0]u8 = "exe";

const ProcessError: type = error{
    PidNotActive,
};

pub const TibiaClientProcess = struct {
    const WINE_SPAWNED_CLIENT: *const [37:0]u8 = "/opt/wine-stable/bin/wine64-preloader";
    const CLIENT_BIN_PATH: *const [39:0]u8 = "/home/aclaret/Programs/Ezodus 14.12/bin";

    pid: i32,

    pub fn init() !TibiaClientProcess {
        const client_pid: i32 = try pid();

        return TibiaClientProcess{ .pid = client_pid };
    }

    fn pid() !i32 {
        var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        defer arena.deinit();

        var directory: Dir = try std.fs.openDirAbsolute(LINUX_PROCESS_DIR, .{ .iterate = true });

        defer directory.close();

        var iterator: Dir.Iterator = directory.iterate();

        while (try iterator.next()) |entry| {
            if (fs.isDir(entry) and util.isNumber(entry.name)) {
                const path_buffer: []u8 = try arena.allocator().alloc(u8, LINUX_PROCESS_DIR.len + entry.name.len + 1);

                const path: []u8 = try std.fmt.bufPrint(path_buffer, "{s}{s}{s}", .{ LINUX_PROCESS_DIR, "/", entry.name });

                var subdir: Dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });

                var subdir_iterator: Dir.Iterator = subdir.iterate();

                while (try subdir_iterator.next()) |subdir_entry| {
                    if (fs.isSymLink(subdir_entry) and std.mem.eql(u8, subdir_entry.name, CWD_SYMLINK)) {
                        const cwd_symlink_buffer: []u8 = try arena.allocator().alloc(u8, std.fs.MAX_PATH_BYTES);

                        const cwd_symlink: []u8 = subdir.readLink(subdir_entry.name, cwd_symlink_buffer) catch |err| {
                            switch (err) {
                                Dir.ReadLinkError.AccessDenied => {
                                    arena.allocator().free(cwd_symlink_buffer);
                                    continue;
                                },
                                Dir.ReadLinkError.FileNotFound => {
                                    arena.allocator().free(cwd_symlink_buffer);
                                    continue;
                                },
                                else => {
                                    return err;
                                },
                            }
                        };

                        if (std.mem.eql(u8, CLIENT_BIN_PATH, cwd_symlink)) {
                            const exe_symlink_buffer: []u8 = try arena.allocator().alloc(u8, std.fs.MAX_PATH_BYTES);

                            const exe_symlink: []u8 = subdir.readLink(EXE_SYMLINK, exe_symlink_buffer) catch |err| {
                                switch (err) {
                                    Dir.ReadLinkError.AccessDenied => {
                                        arena.allocator().free(cwd_symlink_buffer);
                                        arena.allocator().free(exe_symlink_buffer);
                                        continue;
                                    },
                                    Dir.ReadLinkError.FileNotFound => {
                                        arena.allocator().free(cwd_symlink_buffer);
                                        arena.allocator().free(exe_symlink_buffer);
                                        continue;
                                    },
                                    else => {
                                        return err;
                                    },
                                }
                            };

                            if (std.mem.eql(u8, exe_symlink, WINE_SPAWNED_CLIENT)) {
                                return std.fmt.parseInt(i32, entry.name, 10);
                            }

                            arena.allocator().free(exe_symlink_buffer);
                        }

                        arena.allocator().free(cwd_symlink_buffer);
                    }
                }

                arena.allocator().free(path_buffer);
            }
        }

        return ProcessError.PidNotActive;
    }
};

pub fn resolveLibraryVirtualMemoryAddress(pid: i32) !void {
    var arena: std.heap.ArenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();

    const pid_virtual_memory_path: []u8 = try std.fmt.allocPrint(arena.allocator(), "/proc/{d}/mem", .{pid});

    //7693f4a16000

    const file: File = try std.fs.openFileAbsolute(pid_virtual_memory_path, .{ .mode = File.OpenMode.read_only });

    //std.io.BufferedReader(4096, @TypeOf(file.reader()))

    var bufferedReader = std.io.bufferedReader(file.reader());

    const buffer = try arena.allocator().alloc(u8, 4096);

    const a = try bufferedReader.reader().readUntilDelimiterOrEof(buffer, '\n');

    std.debug.print("content {any}\n", .{a});
}
