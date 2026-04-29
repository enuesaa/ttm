const std = @import("std");
const pkgenv = @import("env.zig");

pub fn abs(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const io = try pkgenv.getIo();
    if (std.mem.startsWith(u8, path, "~")) {
        const homeDir = try pkgenv.getHomeDir(allocator);
        defer allocator.free(homeDir);
        return try std.fs.path.join(allocator, &.{ homeDir, path[1..] });
    }
    return try std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
}

pub fn open(path: []const u8) !std.Io.Dir {
    const io = try pkgenv.getIo();
    return try std.Io.Dir.openDirAbsolute(io, path, .{});
}

pub fn exists(path: []const u8) !bool {
    const io = try pkgenv.getIo();
    std.Io.Dir.accessAbsolute(io, path, .{}) catch {
        return false;
    };
    return true;
}

pub fn mkdir(path: []const u8) !void {
    const io = try pkgenv.getIo();
    try std.Io.Dir.createDirAbsolute(io, path, .default_dir);
}
