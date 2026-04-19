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
