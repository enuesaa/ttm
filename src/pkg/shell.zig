const std = @import("std");
const pkgtmpdir = @import("tmpdir.zig");

fn buildTTMEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const originalTTMEnvVar = std.process.getEnvVarOwned(allocator, "TTM") catch "";
    defer allocator.free(originalTTMEnvVar);

    if (originalTTMEnvVar.len == 0) {
        return "ttm";
    }
    return try std.mem.concat(allocator, u8, &.{ originalTTMEnvVar, "ttm" });
}

pub fn startShell(allocator: std.mem.Allocator, workdir: std.fs.Dir) !void {
    const ttmEnvVar = try buildTTMEnvVar(allocator);
    defer allocator.free(ttmEnvVar);

    const argv = &[_][]const u8{"zsh"};

    var child = std.process.Child.init(argv, allocator);
    child.cwd_dir = workdir;

    var env = try std.process.getEnvMap(allocator);
    try env.put("TTM", ttmEnvVar);
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
