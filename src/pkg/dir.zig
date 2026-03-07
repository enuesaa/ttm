const std = @import("std");

pub fn abs(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return try std.fs.cwd().realpathAlloc(allocator, path);
}

pub fn open(_: std.mem.Allocator, path: []const u8) !std.fs.Dir {
    return try std.fs.openDirAbsolute(path, .{});
}
