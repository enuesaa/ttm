const std = @import("std");
const pkgdir = @import("dir.zig");
const hooksh = @embedFile("registryhook.sh");

pub fn getRegistryPath(allocator: std.mem.Allocator) ![]u8 {
    const homedir = try pkgdir.getHomeDir(allocator);
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

pub fn getHookScriptPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "hook.sh" });
}

pub fn createHookScript(allocator: std.mem.Allocator) !void {
    const hookScriptPath = try getHookScriptPath(allocator);
    defer allocator.free(hookScriptPath);
    const file = try std.fs.cwd().createFile(hookScriptPath, .{
        .mode = 0o755,
    });
    defer file.close();
    try file.writeAll(hooksh);
}

pub fn getConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "config.toml" });
}
