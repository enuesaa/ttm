const std = @import("std");

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
    return try std.fs.path.join(allocator, &.{ registryPath, "config.json" });
}

const Path = struct {
    path: []u8,
    archive: bool = false,
};

// 一度にparseできないので一旦こうする
const Config = struct {
    paths: std.json.Value,
};

const ConfigReal = struct {
    paths: std.StringHashMap(Path),

    pub fn deinit(self: *ConfigReal) void {
        var it = self.paths.iterator();
        while (it.next()) |entry| {
            self.paths.allocator.free(entry.key_ptr.*); // key
            self.paths.allocator.free(entry.value_ptr.path); // value
        }
        self.paths.deinit();
    }
};

pub fn getConfig(allocator: std.mem.Allocator) !ConfigReal {
    const configPath = try getConfigPath(allocator);
    defer allocator.free(configPath);
    const configRaw = try std.fs.cwd().readFileAlloc(allocator, configPath, 1024 * 1024);
    defer allocator.free(configRaw);

    var parsed = try std.json.parseFromSlice(Config, allocator, configRaw, .{});
    defer parsed.deinit();

    var paths = std.StringHashMap(Path).init(allocator);

    var it = parsed.value.paths.object.iterator();
    while (it.next()) |entry| {
        const name = try allocator.dupe(u8, entry.key_ptr.*);
        const obj = entry.value_ptr.*.object;
        const path = try allocator.dupe(u8, obj.get("path").?.string);
        const p = Path{
            .path = path,
            .archive = if (obj.get("archive")) |v| v.bool else false,
        };
        try paths.put(name, p);
    }
    return ConfigReal{
        .paths = paths,
    };
}
