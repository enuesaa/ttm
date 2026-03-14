const std = @import("std");
const pkgregistry = @import("registry.zig");

pub const Path = struct {
    path: []const u8,
    archive: bool = false,
};

pub const Config = struct {
    paths: std.StringHashMap(Path),

    pub fn deinit(self: *Config) void {
        var it = self.paths.iterator();
        while (it.next()) |entry| {
            self.paths.allocator.free(entry.key_ptr.*);
            self.paths.allocator.free(entry.value_ptr.path);
        }
        self.paths.deinit();
    }

    // see https://github.com/ziglang/zig/blob/master/lib/std/json/Stringify.zig
    pub fn jsonStringify(self: Config, jw: anytype) !void {
        try jw.beginObject();
        try jw.objectField("paths");
        try jw.beginObject();
        var it = self.paths.iterator();
        while (it.next()) |entry| {
            try jw.objectField(entry.key_ptr.*);
            try jw.write(entry.value_ptr.*);
        }
        try jw.endObject();
        try jw.endObject();
    }

    // see https://github.com/ziglang/zig/blob/master/lib/std/json/Scanner.zig
    pub fn jsonParse(allocator: std.mem.Allocator, scanner: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(scanner.*))!Config {
        const parsed = try std.json.parseFromTokenSource(std.json.Value, allocator, scanner, options);
        defer parsed.deinit();
        const parsedpaths = parsed.value.object.get("paths") orelse return error.UnexpectedToken;

        var paths = std.StringHashMap(Path).init(allocator);
        var it = parsedpaths.object.iterator();
        while (it.next()) |entry| {
            const name = try allocator.dupe(u8, entry.key_ptr.*);
            const path = parsePathEntry(allocator, entry.value_ptr.*.object) catch return error.UnexpectedToken;
            try paths.put(name, path);
        }
        return Config{ .paths = paths };
    }
};

fn parsePathEntry(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !Path {
    const path = obj.get("path") orelse return error.MissingPathField;
    return .{
        .path = try allocator.dupe(u8, path.string),
        .archive = if (obj.get("archive")) |v| v.bool else false,
    };
}

pub fn get(allocator: std.mem.Allocator) !Config {
    const configPath = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(configPath);
    const configRaw = try std.fs.cwd().readFileAlloc(allocator, configPath, 1024 * 1024);
    defer allocator.free(configRaw);

    var scanner = std.json.Scanner.initCompleteInput(allocator, configRaw);
    defer scanner.deinit();

    return try std.json.parseFromTokenSourceLeaky(Config, allocator, &scanner, .{});
}

pub fn write(allocator: std.mem.Allocator, config: Config) !void {
    const configPath = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(configPath);
    var out = std.Io.Writer.Allocating.init(allocator);
    defer out.deinit();

    try out.writer.print("{f}", .{std.json.fmt(config, .{ .whitespace = .indent_2 })});
    const configRaw = try out.toOwnedSlice();
    defer allocator.free(configRaw);

    const file = try std.fs.cwd().createFile(configPath, .{});
    defer file.close();
    try file.writeAll(configRaw);
}
