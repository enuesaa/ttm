const std = @import("std");

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    const stdin = std.fs.File.stdin();
    std.debug.print("? {s} (default {s}): ", .{ text, defaultValue });

    var buf: [100]u8 = undefined;
    var idx: usize = 0;

    while (idx < buf.len) {
        var b: [1]u8 = undefined;
        const n = try stdin.read(&b);
        if (n == 0 or b[0] == '\n') {
            break;
        }
        buf[idx] = b[0];
        idx += 1;
    }
    if (idx == 0) {
        return try allocator.dupe(u8, defaultValue);
    }
    return try allocator.dupe(u8, buf[0..idx]);
}
