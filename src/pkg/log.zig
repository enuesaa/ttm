const std = @import("std");

pub fn infoln(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("\x1b[33m", .{});
    std.debug.print(fmt, args);
    std.debug.print("\x1b[0m\n", .{});
}
