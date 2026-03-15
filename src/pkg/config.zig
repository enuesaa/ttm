const std = @import("std");
const pkgregistry = @import("registry.zig");
const Yaml = @import("yaml").Yaml;

pub const Path = struct {
    path: []const u8,
    command: ?[]const u8,
};

pub const Config = struct {
    paths: []Path,
};

pub fn get(allocator: std.mem.Allocator) !Config {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(raw);

    var yaml = Yaml{ .source = raw };
    try yaml.load(allocator);
    defer yaml.deinit(allocator);
    const config = try yaml.parse(allocator, Config);
    return config;
}

// pub fn write(allocator: std.mem.Allocator, config: Config) !void {
//     const path = try pkgregistry.getConfigPath(allocator);
//     defer allocator.free(path);
//     const raw = try config.stringify(allocator);
//     defer allocator.free(raw);

//     const file = try std.fs.cwd().createFile(path, .{});
//     defer file.close();
//     try file.writeAll(raw);
// }
