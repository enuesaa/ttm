const std = @import("std");

pub var envMap: ?*std.process.Environ.Map = null;
pub var io: ?std.Io = null;

pub fn getEnvMap() !*std.process.Environ.Map {
    if (envMap == null) {
        return error.RuntimeError;
    }
    return envMap.?;
}

pub fn cloneEnvMap(allocator: std.mem.Allocator) !std.process.Environ.Map {
    if (envMap == null) {
        return error.RuntimeError;
    }
    return try envMap.?.clone(allocator);
}

pub fn getIo() !std.Io {
    if (io == null) {
        return error.RuntimeError;
    }
    return io.?;
}

pub fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
    if (envMap == null) {
        return error.RuntimeError;
    }
    if (envMap.?.get("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    return error.RuntimeError;
}

pub fn isCommandExists(allocator: std.mem.Allocator, cmd: []const u8) !bool {
    if (io == null) {
        return error.RuntimeError;
    }
    const result = try std.process.run(allocator, io.?, .{
        .argv = &[_][]const u8{ "which", cmd },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.term.exited == 0;
}
