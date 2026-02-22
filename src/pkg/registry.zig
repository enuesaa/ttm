const std = @import("std");
const Yaml = @import("yaml").Yaml;

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
    return try std.fs.path.join(allocator, &.{ registryPath, "config.yml" });
}

pub fn getConfig(allocator: std.mem.Allocator) !void {
    // const configPath = try getConfigPath(allocator);
    // const source = try std.fs.cwd().readFileAlloc(allocator, configPath, 1024 * 1024);
    const Simple = struct {
        nested: struct {
            a: []const u8,
        },
    };
    const source =
        \\nested:
        \\  a: one
    ;
    defer allocator.free(source);
    var yaml: Yaml = .{ .source = source };
    try yaml.load(allocator);
    defer yaml.deinit(allocator);
    const config = try yaml.parse(allocator, Simple);
    std.debug.print("hello {s}", .{config.nested.a});
}
