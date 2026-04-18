const std = @import("std");

pub var io: ?std.Io = null;

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    if (std.mem.eql(u8, defaultValue, "")) {
        std.debug.print("{s}? {s}: {s}", .{ "\x1b[33m", text, "\x1b[0m" });
    } else {
        std.debug.print("{s}? {s} (default {s}): {s}", .{ "\x1b[33m", text, defaultValue, "\x1b[0m" });
    }

    var buf: [100]u8 = undefined;
    const stdin = std.Io.File.stdin();
    var reader = stdin.reader(io.?, &buf);

    const line = reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return try allocator.dupe(u8, defaultValue),
        else => return err,
    };
    if (line.len == 0) {
        return try allocator.dupe(u8, defaultValue);
    }
    return try allocator.dupe(u8, line);
}
