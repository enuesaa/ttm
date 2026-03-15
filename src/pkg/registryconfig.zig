const std = @import("std");
const pkgregistry = @import("registry.zig");

pub const Path = struct {
    path: []const u8,
    command: ?[]const u8,
};

pub const Config = struct {
    paths: std.StringHashMap(Path),

    pub fn deinit(self: *Config) void {
        var it = self.paths.iterator();
        while (it.next()) |entry| {
            self.paths.allocator.free(entry.key_ptr.*);
            self.paths.allocator.free(entry.value_ptr.path);
            if (entry.value_ptr.command) |cmd| self.paths.allocator.free(cmd);
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

    pub fn stringify(self: Config, allocator: std.mem.Allocator) ![]u8 {
        var out = std.Io.Writer.Allocating.init(allocator);
        defer out.deinit();
        try out.writer.print("{f}", .{std.json.fmt(self, .{ .whitespace = .indent_2 })});
        return try out.toOwnedSlice();
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
            const pathValue = entry.value_ptr.*.object.get("path") orelse return error.UnexpectedToken;
            const commandValue = entry.value_ptr.*.object.get("command");
            const path = Path{
                .path = try allocator.dupe(u8, pathValue.string),
                .command = if (commandValue) |cv| try allocator.dupe(u8, cv.string) else null,
            };
            try paths.put(name, path);
        }
        return Config{ .paths = paths };
    }
};

pub fn get(allocator: std.mem.Allocator) !Config {
    const path = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(path);
    const raw = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(raw);
    var scanner = std.json.Scanner.initCompleteInput(allocator, raw);
    defer scanner.deinit();

    return try std.json.parseFromTokenSourceLeaky(Config, allocator, &scanner, .{});
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
