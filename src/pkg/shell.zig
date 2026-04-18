const std = @import("std");
const pkgconfig = @import("config.zig");

pub var envmap: ?*std.process.Environ.Map = null;
pub var io: ?std.Io = null;

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    if (envmap == null) {
        return allocator.dupe(u8, "*");
    }
    const original = envmap.?.get("TTM_NESTED");
    if (original == null) {
        return allocator.dupe(u8, "*");
    }
    return try std.mem.concat(allocator, u8, &.{ original.?, "*" });
}

pub fn start(allocator: std.mem.Allocator, workdir: std.Io.Dir, command: ?[]const u8, envvars: *std.process.Environ.Map) !void {
    const ttmNested = try buildTTMNestedEnvVar(allocator);
    defer allocator.free(ttmNested);
    try envvars.put("TTM", "true");
    try envvars.put("TTM_NESTED", ttmNested);

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = try std.process.spawn(io.?, .{
        .argv = argv,
        .environ_map = envmap,
        .cwd = .{ .dir = workdir },
    });
    _ = try child.wait(io.?);
}

pub fn isCommandExists(allocator: std.mem.Allocator, cmd: []const u8) !bool {
    const result = try std.process.run(allocator, io.?, .{
        .argv = &[_][]const u8{ "which", cmd },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.term.exited == 0;
}
