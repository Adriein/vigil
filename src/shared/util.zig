const std: type = @import("std");

pub fn isNumber(name: []const u8) bool {
    _ = std.fmt.parseInt(i64, name, 10) catch {
        return false;
    };

    return true;
}
