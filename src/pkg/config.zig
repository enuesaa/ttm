const std = @import("std");
const pkgregistry = @import("registry.zig");
const pkgenv = @import("env.zig");
const toml = @import("toml");

pub const Env = struct {
    key: []const u8,
    value: []const u8,
    ask: ?[]const u8 = null,
    required: ?bool = null,
};

pub const Path = struct {
    name: []const u8,
    path: []const u8,
    command: ?[]const u8,
    onBeforeCommand: ?[]const u8,
    onAfterCommand: ?[]const u8,
    envs: ?[]Env = null,
};

pub const Config = struct {
    editor: ?[]const u8,
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
    const io = pkgenv.io;
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
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

pub fn getInstalledEditor(allocator: std.mem.Allocator, config: Config) ![]const u8 {
    if (config.editor) |editor| {
        return editor;
    }
    const isCodeExists = try pkgenv.isCommandExists(allocator, "code");
    if (isCodeExists) {
        return "code";
    }
    const isVimExists = try pkgenv.isCommandExists(allocator, "vim");
    if (isVimExists) {
        return "vim";
    }
    return error.EditorNotFound;
}
