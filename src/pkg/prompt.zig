const std = @import("std");
const pkgenv = @import("env.zig");

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    const io = try pkgenv.getIo();
    if (std.mem.eql(u8, defaultValue, "")) {
        std.debug.print("\x1b[33m? {s}: \x1b[0m", .{text});
    } else {
        std.debug.print("\x1b[33m? {s} (default {s}): \x1b[0m", .{ text, defaultValue });
    }

    var buf: [100]u8 = undefined;
    const stdin = std.Io.File.stdin();
    var reader = stdin.reader(io, &buf);

    const line = reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return try allocator.dupe(u8, defaultValue),
        else => return err,
    };
    if (line.len == 0) {
        return try allocator.dupe(u8, defaultValue);
    }
    return try allocator.dupe(u8, line);
}
