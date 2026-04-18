const std = @import("std");
const pkgdir = @import("dir.zig");
const hooksh = @embedFile("registryhook.sh");
const initialConfig = @embedFile("registryconfig.toml");

pub var io: ?std.Io = null;

pub fn getRegistryPath(allocator: std.mem.Allocator) ![]u8 {
    const homedir = try pkgdir.getHomeDir(allocator);
    defer allocator.free(homedir);
    return try std.fs.path.join(allocator, &.{ homedir, ".ttm" });
}

pub fn isRegistryExist(allocator: std.mem.Allocator) !bool {
    const registry = try getRegistryPath(allocator);
    defer allocator.free(registry);
    return pkgdir.exists(registry);
}

fn makeRegistry(allocator: std.mem.Allocator) !void {
    const registry = try getRegistryPath(allocator);
    defer allocator.free(registry);
    try pkgdir.mkdir(registry);
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
    const file = try std.Io.Dir.cwd().createFile(io.?, hookScriptPath, .{});
    defer file.close(io.?);
    try file.writeStreamingAll(io.?, hooksh);
}

pub fn getConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "config.toml" });
}

pub fn isConfigExist(allocator: std.mem.Allocator) !bool {
    const configPath = try getConfigPath(allocator);
    defer allocator.free(configPath);
    return pkgdir.exists(configPath);
}

pub fn createInitialConfig(allocator: std.mem.Allocator) !void {
    const isExist = try isConfigExist(allocator);
    if (isExist) {
        return;
    }
    const configPath = try getConfigPath(allocator);
    defer allocator.free(configPath);
    const file = try std.Io.Dir.cwd().createFile(io.?, configPath, .{});
    defer file.close(io.?);
    try file.writeStreamingAll(io.?, initialConfig);
}
