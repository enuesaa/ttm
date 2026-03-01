const std = @import("std");
const pkgtmpdir = @import("tmpdir.zig");

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const original = std.process.getEnvVarOwned(allocator, "TTM_NESTED") catch "";
    defer allocator.free(original);
    if (original.len == 0) {
        return "*";
    }
    return try std.mem.concat(allocator, u8, &.{ original, "*" });
}

pub fn startShell(allocator: std.mem.Allocator, workdir: std.fs.Dir) !void {
    const ttmNested = try buildTTMNestedEnvVar(allocator);

    const argv = &[_][]const u8{"zsh"};
    var child = std.process.Child.init(argv, allocator);
    child.cwd_dir = workdir;

    var env = try std.process.getEnvMap(allocator);
    try env.put("TTM", "true");
    try env.put("TTM_NESTED", ttmNested);
    defer env.deinit();
    child.env_map = &env;

    _ = try child.spawnAndWait();
}

pub fn start(tmppath: []u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const workdir = try std.fs.openDirAbsolute(tmppath, .{});
    try startShell(allocator, workdir);
}
