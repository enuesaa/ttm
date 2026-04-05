const std = @import("std");
const pkgregistry = @import("registry.zig");

pub fn getPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try pkgregistry.getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "sessionmark" });
}

pub fn get(allocator: std.mem.Allocator) ![]u8 {
    const path = try getPath(allocator);
    defer allocator.free(path);
    return try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
}

pub fn create(allocator: std.mem.Allocator, workdir: []const u8) !void {
    const path = try getPath(allocator);
    defer allocator.free(path);
    const file = try std.fs.cwd().createFile(path, .{
        .mode = 0o755,
    });
    defer file.close();
    try file.writeAll(workdir);
}

pub fn delete(allocator: std.mem.Allocator) !void {
    const path = try getPath(allocator);
    defer allocator.free(path);
    try std.fs.cwd().deleteFile(path);
}
