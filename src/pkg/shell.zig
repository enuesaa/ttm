const std = @import("std");

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const original = std.process.getEnvVarOwned(allocator, "TTM_NESTED") catch "";
    defer allocator.free(original);
    if (original.len == 0) {
        return allocator.dupe(u8, "*");
    }
    return try std.mem.concat(allocator, u8, &.{ original, "*" });
}

pub fn start(allocator: std.mem.Allocator, workdir: std.fs.Dir, command: ?[]const u8) !void {
    const ttmNested = try buildTTMNestedEnvVar(allocator);
    defer allocator.free(ttmNested);

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = std.process.Child.init(argv, allocator);
    child.cwd_dir = workdir;

    var env = try std.process.getEnvMap(allocator);
    try env.put("TTM", "true");
    try env.put("TTM_NESTED", ttmNested);
    defer env.deinit();
    child.env_map = &env;

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
