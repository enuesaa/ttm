const std = @import("std");
const pkgregistry = @import("registry.zig");
const toml = @import("toml");

pub const Path = struct {
    name: []const u8,
    path: []const u8,
    command: ?[]const u8,
};

pub const Config = struct {
    paths: []Path,

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

    var parser = toml.Parser(Config).init(arena.allocator());
    defer parser.deinit();

    const result = try parser.parseString(raw);
    const parsed = Parsed{
        .config = result.value,
        .arena = arena,
    };
    return parsed;
}

pub fn write(allocator: std.mem.Allocator, config: Config) !void {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    var buf = std.Io.Writer.Allocating.init(allocator);
    defer buf.deinit();
    try toml.serialize(allocator, config, &buf.writer);
    const raw = try buf.toOwnedSlice();
    defer allocator.free(raw);

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(raw);
}

fn padRight(allocator: std.mem.Allocator, s: []const u8, width: usize) ![]u8 {
    var buf = std.array_list.Managed(u8).init(allocator);
    try buf.appendSlice(s);
    try buf.appendNTimes(' ', width - s.len);
    return buf.toOwnedSlice();
}

pub fn listup(allocator: std.mem.Allocator, config: Config) !void {
    var maxName: usize = 4;
    var maxPath: usize = 4;
    var maxCmd: usize = 7;
    for (config.paths) |p| {
        if (p.name.len > maxName) maxName = p.name.len;
        if (p.path.len > maxPath) maxPath = p.path.len;
        if (p.command) |cmd| {
            if (cmd.len > maxCmd) maxCmd = cmd.len;
        }
    }

    const hName = try padRight(allocator, "NAME", maxName);
    defer allocator.free(hName);
    const hPath = try padRight(allocator, "PATH", maxPath);
    defer allocator.free(hPath);
    std.debug.print("{s}  {s}  COMMAND\n", .{ hName, hPath });

    for (config.paths) |p| {
        const colName = try padRight(allocator, p.name, maxName);
        defer allocator.free(colName);
        const colPath = try padRight(allocator, p.path, maxPath);
        defer allocator.free(colPath);
        std.debug.print("{s}  {s}  {s}\n", .{ colName, colPath, p.command orelse "-" });
    }
}
