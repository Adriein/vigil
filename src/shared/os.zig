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

        const file: File = try std.fs.openFileAbsolute(
            pid_vm_maps_path,
            .{ .mode = File.OpenMode.read_only },
        );

        defer file.close();

        var bufferedReader = std.io.bufferedReader(file.reader());

        const buffer: []u8 = try self.allocator.alloc(u8, 200);

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

        return iterator.first();
    }

    fn readContentFromMemoryAddress(self: *const TibiaClientProcess, address: u64) !void {
        const pid_mem_path: []u8 = try std.fmt.allocPrint(
            self.allocator,
            "/proc/{d}/mem",
            .{self.pid},
        );

        std.debug.print("Memory at address 0x{x}\n", .{address});

        const file: File = try std.fs.openFileAbsolute(
            pid_mem_path,
            .{ .mode = File.OpenMode.read_only },
        );

        defer file.close();

        try file.seekTo(address);

        var bufferedReader = std.io.bufferedReader(file.reader());

        const buffer: []u8 = try self.allocator.alloc(u8, 8);

        _ = try bufferedReader.reader().readAtLeast(buffer, 8);

        std.debug.print("Contents at 0x{x}: {any}\n", .{ address, buffer });

        // Read the bytes from memory
        //const bytes_read = try file.readAll(buffer[0..]);

        // Print the result as a hex dump
        //try std.debug.print("Memory at address {x} (read {d} bytes):\n", .{address, bytes_read});
        //for (buffer[0..bytes_read]) |byte, index| {
        //    try std.debug.print("{02x} ", .{byte});
        //    if ((index + 1) % 16 == 0) {
        //        try std.debug.print("\n", .{});
        //    }
        //}
        //try std.debug.print("\n", .{});

    }

    pub fn resolvePointer(self: *const TibiaClientProcess, pointer: Pointer) !void {
        const base_address: []const u8 = try self.getModuleVirtualMemoryAddress(
            pointer.base_module,
            pointer.base_module_load_pos,
        );

        const decimal_base_address: u64 = try std.fmt.parseInt(u64, base_address, 16);

        var pointer_chain_iterator: std.mem.SplitIterator(u8, .sequence) = std.mem.split(
            u8,
            pointer.pointer_chain,
            "->",
        );

        var address: u64 = 0;

        while (pointer_chain_iterator.next()) |offset| {
            const decimal_offset: u64 = try std.fmt.parseInt(u64, offset, 16);

            if (pointer_chain_iterator.index == 0) {
                address = decimal_base_address + decimal_offset;

                address = try self.readContentFromMemoryAddress(address);

                continue;
            }
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
