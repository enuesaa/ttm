const std = @import("std");

pub var envMap: *std.process.Environ.Map = undefined;
pub var io: std.Io = undefined;

pub fn cloneEnvMap(allocator: std.mem.Allocator) !std.process.Environ.Map {
    return try envMap.clone(allocator);
}

pub fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
    if (envMap.get("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    return error.RuntimeError;
}

pub fn isCommandExists(allocator: std.mem.Allocator, cmd: []const u8) !bool {
    const result = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ "which", cmd },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.term.exited == 0;
}
