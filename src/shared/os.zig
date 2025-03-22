const std: type = @import("std");
const util: type = @import("util.zig");
const fs: type = @import("fs.zig");

const Dir: type = std.fs.Dir;
const File: type = std.fs.File;

const LINUX_PROCESS_DIR: *const [5:0]u8 = "/proc";
const CWD_SYMLINK: *const [3:0]u8 = "cwd";
const EXE_SYMLINK: *const [3:0]u8 = "exe";

const ProcessError: type = error{ PidNotActive, LibraryNotPresentInVirtualMemory };

pub const TibiaClientProcess = struct {
    const WINE_SPAWNED_CLIENT: *const [37:0]u8 = "/opt/wine-stable/bin/wine64-preloader";
    const CLIENT_BIN_PATH: *const [39:0]u8 = "/home/aclaret/Programs/Ezodus 14.12/bin";

    pid: i32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TibiaClientProcess {
        const client_pid: i32 = try pid(allocator);

        return TibiaClientProcess{ .pid = client_pid, .allocator = allocator };
    }

    fn pid(allocator: std.mem.Allocator) !i32 {
        var directory: Dir = try std.fs.openDirAbsolute(LINUX_PROCESS_DIR, .{ .iterate = true });

        defer directory.close();

        var iterator: Dir.Iterator = directory.iterate();

        while (try iterator.next()) |entry| {
            if (fs.isDir(entry) and util.isNumber(entry.name)) {
                const path_buffer: []u8 = try allocator.alloc(u8, LINUX_PROCESS_DIR.len + entry.name.len + 1);

                const path: []u8 = try std.fmt.bufPrint(path_buffer, "{s}{s}{s}", .{ LINUX_PROCESS_DIR, "/", entry.name });

                var subdir: Dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });

                var subdir_iterator: Dir.Iterator = subdir.iterate();

                while (try subdir_iterator.next()) |subdir_entry| {
                    if (fs.isSymLink(subdir_entry) and std.mem.eql(u8, subdir_entry.name, CWD_SYMLINK)) {
                        const cwd_symlink_buffer: []u8 = try allocator.alloc(u8, std.fs.MAX_PATH_BYTES);

                        const cwd_symlink: []u8 = subdir.readLink(subdir_entry.name, cwd_symlink_buffer) catch |err| {
                            switch (err) {
                                Dir.ReadLinkError.AccessDenied => {
                                    allocator.free(cwd_symlink_buffer);
                                    continue;
                                },
                                Dir.ReadLinkError.FileNotFound => {
                                    allocator.free(cwd_symlink_buffer);
                                    continue;
                                },
                                else => {
                                    return err;
                                },
                            }
                        };

                        if (std.mem.eql(u8, CLIENT_BIN_PATH, cwd_symlink)) {
                            const exe_symlink_buffer: []u8 = try allocator.alloc(u8, std.fs.MAX_PATH_BYTES);

                            const exe_symlink: []u8 = subdir.readLink(EXE_SYMLINK, exe_symlink_buffer) catch |err| {
                                switch (err) {
                                    Dir.ReadLinkError.AccessDenied => {
                                        allocator.free(cwd_symlink_buffer);
                                        allocator.free(exe_symlink_buffer);
                                        continue;
                                    },
                                    Dir.ReadLinkError.FileNotFound => {
                                        allocator.free(cwd_symlink_buffer);
                                        allocator.free(exe_symlink_buffer);
                                        continue;
                                    },
                                    else => {
                                        allocator.free(cwd_symlink_buffer);
                                        allocator.free(exe_symlink_buffer);

                                        return err;
                                    },
                                }
                            };

                            if (std.mem.eql(u8, exe_symlink, WINE_SPAWNED_CLIENT)) {
                                return std.fmt.parseInt(i32, entry.name, 10);
                            }

                            allocator.free(exe_symlink_buffer);
                        }

                        allocator.free(cwd_symlink_buffer);
                    }
                }

                allocator.free(path_buffer);
            }
        }

        return ProcessError.PidNotActive;
    }

    pub fn getModuleVirtualMemoryAddress(self: *const TibiaClientProcess, module: []const u8, load_pos: u8) ![]const u8 {
        const pid_vm_maps_path: []u8 = try std.fmt.allocPrint(self.allocator, "/proc/{d}/maps", .{self.pid});

        const file: File = try std.fs.openFileAbsolute(pid_vm_maps_path, .{ .mode = File.OpenMode.read_only });

        var bufferedReader = std.io.bufferedReader(file.reader());

        const buffer: []u8 = try self.allocator.alloc(u8, 200);

        var counter: u8 = 0;

        while (true) {
            const content: ?[]u8 = try bufferedReader.reader().readUntilDelimiterOrEof(buffer, '\n');

            if (content) |line| {
                const index: ?usize = std.mem.indexOf(u8, line, module);

                if (index) |_| {
                    counter += 1;

                    if (counter == load_pos) {
                        break;
                    }
                }

                continue;
            }

            return ProcessError.LibraryNotPresentInVirtualMemory;
        }

        var iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(u8, buffer, "-");

        return iterator.first();
    }
};
