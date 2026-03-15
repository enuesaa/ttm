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

pub const ConfigHandle = struct {
    config: Config,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *ConfigHandle) void {
        self.arena.deinit();
    }
};

pub fn get(allocator: std.mem.Allocator) !ConfigHandle {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(raw);

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var yaml = Yaml{ .source = raw };
    try yaml.load(arena.allocator());

    const handle = ConfigHandle{
        .config = try yaml.parse(arena.allocator(), Config),
        .arena = arena,
    };
    return handle;
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
