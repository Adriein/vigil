const std: type = @import("std");
const util: type = @import("util.zig");
const fs: type = @import("fs.zig");

const Dir: type = std.fs.Dir;
const File: type = std.fs.File;

const LINUX_PROCESS_DIR: []const u8 = "/proc";
const CWD_SYMLINK: []const u8 = "cwd";
const EXE_SYMLINK: []const u8 = "exe";

const ProcessError: type = error{ PidNotActive, LibraryNotPresentInVirtualMemory };

pub const TibiaClientProcess: type = struct {
    const WINE_SPAWNED_CLIENT: []const u8 = "/opt/wine-stable/bin/wine64-preloader";
    const CLIENT_BIN_PATH: []const u8 = "/home/aclaret/Programs/Ezodus 14.12/bin";

    pid: i32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !TibiaClientProcess {
        const client_pid: i32 = try pid(allocator);

        return TibiaClientProcess{
            .pid = client_pid,
            .allocator = allocator,
        };
    }

    fn pid(allocator: std.mem.Allocator) !i32 {
        var directory: Dir = try std.fs.openDirAbsolute(
            LINUX_PROCESS_DIR,
            .{ .iterate = true },
        );

        defer directory.close();

        var iterator: Dir.Iterator = directory.iterate();

        while (try iterator.next()) |entry| {
            if (fs.isDir(entry) and util.isNumber(entry.name)) {
                const path_buffer: []u8 = try allocator.alloc(
                    u8,
                    LINUX_PROCESS_DIR.len + entry.name.len + 1,
                );

                const path: []u8 = try std.fmt.bufPrint(
                    path_buffer,
                    "{s}{s}{s}",
                    .{ LINUX_PROCESS_DIR, "/", entry.name },
                );

                var subdir: Dir = try std.fs.openDirAbsolute(
                    path,
                    .{ .iterate = true },
                );

                defer subdir.close();

                var subdir_iterator: Dir.Iterator = subdir.iterate();

                while (try subdir_iterator.next()) |subdir_entry| {
                    if (fs.isSymLink(subdir_entry) and std.mem.eql(u8, subdir_entry.name, CWD_SYMLINK)) {
                        const cwd_symlink_buffer: []u8 = try allocator.alloc(
                            u8,
                            std.fs.MAX_PATH_BYTES,
                        );

                        const cwd_symlink: []u8 = subdir.readLink(
                            subdir_entry.name,
                            cwd_symlink_buffer,
                        ) catch |err| {
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
                            const exe_symlink_buffer: []u8 = try allocator.alloc(
                                u8,
                                std.fs.MAX_PATH_BYTES,
                            );

                            const exe_symlink: []u8 = subdir.readLink(
                                EXE_SYMLINK,
                                exe_symlink_buffer,
                            ) catch |err| {
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
                                allocator.free(cwd_symlink_buffer);
                                allocator.free(exe_symlink_buffer);
                                allocator.free(path_buffer);

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
        const pid_vm_maps_path: []u8 = try std.fmt.allocPrint(
            self.allocator,
            "/proc/{d}/maps",
            .{self.pid},
        );

        defer self.allocator.free(pid_vm_maps_path);

        const file: File = try std.fs.openFileAbsolute(
            pid_vm_maps_path,
            .{ .mode = File.OpenMode.read_only },
        );

        defer file.close();

        var bufferedReader = std.io.bufferedReader(file.reader());

        const buffer: []u8 = try self.allocator.alloc(u8, 200);

        defer self.allocator.free(buffer);

        var counter: u8 = 0;

        while (true) {
            const content: ?[]u8 = try bufferedReader.reader().readUntilDelimiterOrEof(
                buffer,
                '\n',
            );

            if (content) |line| {
                const index: ?usize = std.mem.indexOf(u8, line, module);

                if (index) |_| {
                    if (counter == load_pos) {
                        break;
                    }

                    counter += 1;
                }

                continue;
            }

            return ProcessError.LibraryNotPresentInVirtualMemory;
        }

        var iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            buffer,
            "-",
        );

        const result: []u8 = try self.allocator.alloc(u8, iterator.first().len);

        iterator.reset();

        @memcpy(result, iterator.first());

        return result;
    }

    pub fn readContentFromMemoryAddress(self: *const TibiaClientProcess, comptime T: type, address: u64) !T {
        const pid_mem_path: []u8 = try std.fmt.allocPrint(
            self.allocator,
            "/proc/{d}/mem",
            .{self.pid},
        );

        defer self.allocator.free(pid_mem_path);

        const file: File = try std.fs.openFileAbsolute(
            pid_mem_path,
            .{ .mode = File.OpenMode.read_only },
        );

        defer file.close();

        try file.seekTo(address);

        var bufferedReader = std.io.bufferedReader(file.reader());

        const size = @sizeOf(T);

        const buffer: []u8 = try self.allocator.alloc(u8, size);

        defer self.allocator.free(buffer);

        _ = try bufferedReader.reader().readAtLeast(buffer, size);

        return std.mem.readInt(T, buffer[0..size], .little);
    }

    pub fn resolvePointer(self: *const TibiaClientProcess, pointer: Pointer) !u64 {
        const base_address: []const u8 = try self.getModuleVirtualMemoryAddress(
            pointer.base_module,
            pointer.base_module_load_pos,
        );

        defer self.allocator.free(base_address);

        const decimal_base_address: u64 = try std.fmt.parseInt(u64, base_address, 16);

        var pointer_chain_iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            pointer.pointer_chain,
            "->",
        );

        var address: u64 = decimal_base_address;
        var index: usize = 0;

        while (pointer_chain_iterator.next()) |offset| : (index += 1) {
            const decimal_offset: u64 = try std.fmt.parseInt(u64, offset, 16);

            if (pointer_chain_iterator.peek() == null) {
                address = address + decimal_offset;

                break;
            }

            address = try self.readContentFromMemoryAddress(u64, address + decimal_offset);
        }

        return address;
    }

    pub fn emit(_: *const TibiaClientProcess, comptime T: type, event: Event(T)) void {
        switch (@typeInfo(T)) {
            .Int, .ComptimeInt => {
                std.debug.print("{s}: {d}\n", .{ event.name, event.value });
            },
            .Float, .ComptimeFloat => {
                std.debug.print("{s}: {d}\n", .{ event.name, event.value });
            },
            .Bool => {
                std.debug.print("{s}: {}\n", .{ event.name, event.value });
            },
            .Pointer => |ptr| {
                if (ptr.size == .Slice and ptr.child == u8) {
                    // Handle string slices ([]const u8 or []u8)
                    std.debug.print("{s}: {s}\n", .{ event.name, event.value });
                } else {
                    // Handle other pointer types
                    std.debug.print("{s}: {any}\n", .{ event.name, event.value });
                }
            },
            else => {
                // Default fallback for other types
                std.debug.print("{s}: {any}\n", .{ event.name, event.value });
            },
        }
    }
};

const PointerError: type = error{WrongFormattedPointer};

pub const Pointer: type = struct {
    base_module: []const u8,
    base_module_load_pos: u8,
    pointer_chain: []const u8,

    pub fn init(raw_pointer: []const u8) !Pointer {
        var iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            raw_pointer,
            "]",
        );

        const raw_base_module: []const u8 = iterator.first();
        const raw_not_processed_pointer: ?[]const u8 = iterator.next();

        const pointer: []const u8 = raw_not_processed_pointer orelse return PointerError.WrongFormattedPointer;

        var base_module_iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            raw_base_module,
            "[",
        );

        const base_module: []const u8 = base_module_iterator.first();
        const base_module_load_pos: []const u8 = base_module_iterator.next() orelse return PointerError.WrongFormattedPointer;

        const pointer_without_sum_char: []const u8 = pointer[1..];

        return Pointer{
            .base_module = base_module,
            .base_module_load_pos = try std.fmt.parseInt(u8, base_module_load_pos, 10),
            .pointer_chain = pointer_without_sum_char,
        };
    }
};

pub fn Event(comptime T: type) type {
    return struct {
        name: []const u8,
        value: T,
    };
}
