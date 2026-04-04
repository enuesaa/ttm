const std = @import("std");

pub fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    if (env.get("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    return error.RuntimeError;
}

pub fn marshal(allocator: std.mem.Allocator, path: []const u8, envvars: *std.process.EnvMap) ![]u8 {
    var ret = try allocator.dupe(u8, path);
    var it = envvars.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const value = entry.value_ptr.*;

        const pattern = try std.fmt.allocPrint(allocator, "${{{s}}}", .{key});
        defer allocator.free(pattern);

        if (std.mem.indexOf(u8, ret, pattern) != null) {
            std.log.debug("replace: {s} -> {s}", .{ pattern, value });
            const replaced = try std.mem.replaceOwned(u8, allocator, ret, pattern, value);
            allocator.free(ret);
            ret = replaced;
        }
    }
    return ret;
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

pub fn exists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch {
        return false;
    };
    return true;
}

pub fn mkdir(path: []const u8) !void {
    try std.fs.makeDirAbsolute(path);
}
