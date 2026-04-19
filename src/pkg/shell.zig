const std = @import("std");
const pkgconfig = @import("config.zig");
const pkgenv = @import("env.zig");

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const envMap = try pkgenv.getEnvMap();
    const original = envMap.get("TTM_NESTED");
    if (original == null) {
        return allocator.dupe(u8, "*");
    }
    return try std.mem.concat(allocator, u8, &.{ original.?, "*" });
}

pub fn start(allocator: std.mem.Allocator, workdir: std.Io.Dir, command: ?[]const u8, envvars: *std.process.Environ.Map) !void {
    const io = try pkgenv.getIo();
    const ttmNested = try buildTTMNestedEnvVar(allocator);
    defer allocator.free(ttmNested);
    try envvars.put("TTM", "true");
    try envvars.put("TTM_NESTED", ttmNested);

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .environ_map = envvars,
        .cwd = .{ .dir = workdir },
    });
    _ = try child.wait(io);
}

pub fn isCommandExists(allocator: std.mem.Allocator, cmd: []const u8) !bool {
    const io = try pkgenv.getIo();
    const result = try std.process.run(allocator, io, .{
        .argv = &[_][]const u8{ "which", cmd },
    });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }
    return result.term.exited == 0;
}
