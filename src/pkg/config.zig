const std = @import("std");
const pkgregistry = @import("registry.zig");
const yaml = @import("yaml");

pub const Path = struct {
    name: []const u8,
    path: []const u8,
    command: ?[]const u8,
};

pub const Config = struct {
    paths: []Path,

    pub fn stringify(self: *Config, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.Io.Writer.Allocating.init(allocator);
        defer buf.deinit();
        try yaml.stringify(allocator, self.*, &buf.writer);
        return try buf.toOwnedSlice();
    }

    pub fn getPath(self: *Config, name: []const u8) ?Path {
        for (self.paths) |path| {
            if (std.mem.eql(u8, path.name, name)) {
                return path;
            }
        }
        return null;
    }
};

pub const Parsed = struct {
    config: Config,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Parsed) void {
        self.arena.deinit();
    }
};

pub fn get(allocator: std.mem.Allocator) !Parsed {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(raw);

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var parser = yaml.Yaml{ .source = raw };
    try parser.load(arena.allocator());

    const parsed = Parsed{
        .config = try parser.parse(arena.allocator(), Config),
        .arena = arena,
    };
    return parsed;
}

pub fn write(allocator: std.mem.Allocator, config: Config) !void {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try config.stringify(allocator);
    defer allocator.free(raw);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(raw);
}
