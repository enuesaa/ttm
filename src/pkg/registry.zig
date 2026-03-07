const std = @import("std");
const hooksh = @embedFile("registryhook.sh");

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

pub fn writeConfig(allocator: std.mem.Allocator, configreal: ConfigReal) !void {
    var obj = std.json.ObjectMap.init(allocator);
    defer {
        var obj_it = obj.iterator();
        while (obj_it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .object => |*nested| nested.deinit(),
                else => {},
            }
        }
        obj.deinit();
    }

    var it = configreal.paths.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        const val = entry.value_ptr.*;

        var path_obj = std.json.ObjectMap.init(allocator);
        try path_obj.put("path", .{ .string = val.path });
        try obj.put(key, .{ .object = path_obj });
    }
    const config = Config{
        .paths = .{ .object = obj },
    };

    var out = std.Io.Writer.Allocating.init(allocator);
    defer out.deinit();

    try std.json.Stringify.value(config, .{ .whitespace = .indent_2 }, &out.writer);
    const str = try out.toOwnedSlice();
    defer allocator.free(str);
    std.debug.print("{s}\n", .{str});

    // const configPath = try getConfigPath(allocator);

    // defer allocator.free(configPath);
    // const file = try std.fs.cwd().createFile(configPath, .{});
    // defer file.close();
    // try file.writeAll(hooksh);
}
