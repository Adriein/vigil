const std: type = @import("std");

const LINUX_PROCESS_FILE: *const [5:0]u8 = "/proc";

pub fn program_pid() !u16 {
    const file: std.fs.File = try std.fs.openFileAbsolute(LINUX_PROCESS_FILE, .{ .mode = std.fs.File.OpenMode.read_only });

    defer file.close();

    const file_stat: std.fs.File.Stat = try file.stat();

    const buffer: [file_stat.size]u8 = undefined;

    const bytes_read: usize = try file.readAll(buffer);

    std.debug.print("File contents: {s}\n", .{buffer[0..bytes_read]});
}
