const std = @import("std");

pub fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    if (env.get("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    return error.RuntimeError;
}

pub fn abs(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    if (std.mem.startsWith(u8, path, "~")) {
        const homeDir = try getHomeDir(allocator);
        defer allocator.free(homeDir);
        return try std.fs.path.join(allocator, &.{ homeDir, path[1..] });
    }
    return try std.fs.cwd().realpathAlloc(allocator, path);
}

pub fn open(_: std.mem.Allocator, path: []const u8) !std.fs.Dir {
    return try std.fs.openDirAbsolute(path, .{});
}
