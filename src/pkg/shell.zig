const std = @import("std");
const pkgconfig = @import("config.zig");

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const original = std.process.getEnvVarOwned(allocator, "TTM_NESTED") catch "";
    defer allocator.free(original);
    if (original.len == 0) {
        return allocator.dupe(u8, "*");
    }
    return try std.mem.concat(allocator, u8, &.{ original, "*" });
}

pub fn getCurrentEnvVars(allocator: std.mem.Allocator) !std.process.EnvMap {
    return try std.process.getEnvMap(allocator);
}

pub fn start(allocator: std.mem.Allocator, workdir: std.fs.Dir, command: ?[]const u8, envvars: *std.process.EnvMap) !void {
    const ttmNested = try buildTTMNestedEnvVar(allocator);
    defer allocator.free(ttmNested);

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = std.process.Child.init(argv, allocator);
    child.cwd_dir = workdir;

    try envvars.put("TTM", "true");
    try envvars.put("TTM_NESTED", ttmNested);
    child.env_map = envvars;

    _ = try child.spawnAndWait();
}

pub fn isCommandExists(allocator: std.mem.Allocator, cmd: []const u8) !bool {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "which", cmd },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.term.Exited == 0;
}
