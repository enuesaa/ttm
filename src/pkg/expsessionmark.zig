const std = @import("std");
const pkgregistry = @import("registry.zig");
const pkgenv = @import("env.zig");

pub fn getPath(allocator: std.mem.Allocator) ![]u8 {
    const registryPath = try pkgregistry.getRegistryPath(allocator);
    defer allocator.free(registryPath);
    return try std.fs.path.join(allocator, &.{ registryPath, "sessionmark" });
}

pub fn get(allocator: std.mem.Allocator) ![]u8 {
    const io = try pkgenv.getIo();
    const path = try getPath(allocator);
    defer allocator.free(path);
    return try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
}

pub fn create(allocator: std.mem.Allocator, workdir: []const u8) !void {
    const io = try pkgenv.getIo();
    const path = try getPath(allocator);
    defer allocator.free(path);
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, workdir);
}

pub fn delete(allocator: std.mem.Allocator) !void {
    const io = try pkgenv.getIo();
    const path = try getPath(allocator);
    defer allocator.free(path);
    try std.Io.Dir.cwd().deleteFile(io, path);
}
