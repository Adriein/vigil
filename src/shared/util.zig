const std: type = @import("std");

fn isNumber(name: []const u8) bool {
    const result = try std.fmt.parseInt(i64, name, 10);

    return true;
}
