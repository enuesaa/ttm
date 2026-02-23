const std = @import("std");

fn getHomeDir(allocator: std.mem.Allocator) ![]const u8 {
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    if (env.get("HOME")) |home| {
        return try allocator.dupe(u8, home);
    }
    return error.RuntimeError;
}

pub fn getRegistryPath(allocator: std.mem.Allocator) ![]u8 {
    const homedir = try getHomeDir(allocator);
    defer allocator.free(homedir);
    return try std.fs.path.join(allocator, &.{ homedir, ".ttm" });
}

pub fn isRegistryExist(allocator: std.mem.Allocator) !bool {
    const registry = try getRegistryPath(allocator);
    defer allocator.free(registry);
    return if (std.fs.accessAbsolute(registry, .{})) |_| true else |_| false;
}

fn makeRegistry(allocator: std.mem.Allocator) !void {
    const registry = try getRegistryPath(allocator);
    defer allocator.free(registry);
    try std.fs.makeDirAbsolute(registry);
}

pub fn make(allocator: std.mem.Allocator) !void {
    if (try isRegistryExist(allocator)) {
        return;
    }
    try makeRegistry(allocator);
}

pub fn getConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "config.json" });
}

fn startShell(allocator: std.mem.Allocator, workdir: std.fs.Dir) !void {
    const argv = &[_][]const u8{"zsh"};

    var child = std.process.Child.init(argv, allocator);
    child.cwd_dir = workdir;

    var env = try std.process.getEnvMap(allocator);
    try env.put("AAA", "bbb");
    try env.put("TTM", "true");
    defer env.deinit();
    child.env_map = &env;

    _ = try child.spawnAndWait();
}

const Path = struct {
    path: []const u8,
    archive: bool = false,
};

const Config = struct {
    paths: std.json.Value,
};

pub fn runcd(allocator: std.mem.Allocator, to: []const u8) !void {
    const configPath = try getConfigPath(allocator);
    defer allocator.free(configPath);
    const configRaw = try std.fs.cwd().readFileAlloc(allocator, configPath, 1024 * 1024);
    defer allocator.free(configRaw);

    var parsed = try std.json.parseFromSlice(Config, allocator, configRaw, .{});
    defer parsed.deinit();
    const config = parsed.value;

    std.debug.print("aa {}", .{config});

    if (std.mem.eql(u8, to, "default")) {
        // const workdir = try std.fs.openDirAbsolute(config.paths.default.path, .{});
        // try startShell(allocator, workdir);
    }
}
