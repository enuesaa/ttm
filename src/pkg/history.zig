const std = @import("std");
const pkgenv = @import("env.zig");
const pkgregistry = @import("registry.zig");

const Entries = []const []const u8;
const max_entries = 10;

fn getPath(allocator: std.mem.Allocator) ![]u8 {
    const registry = try pkgregistry.getRegistryPath(allocator);
    defer allocator.free(registry);
    return std.fs.path.join(allocator, &.{ registry, "history.json" });
}

pub fn load(allocator: std.mem.Allocator) !std.json.Parsed(Entries) {
    const io = try pkgenv.getIo();
    const path = try getPath(allocator);
    defer allocator.free(path);
    const raw = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited) catch |err| switch (err) {
        error.FileNotFound => return std.json.parseFromSlice(Entries, allocator, "[]", .{}),
        else => return err,
    };
    defer allocator.free(raw);
    var parsed = try std.json.parseFromSlice(Entries, allocator, raw, .{ .allocate = .alloc_always });
    parsed.value = parsed.value[0..@min(parsed.value.len, max_entries)];
    return parsed;
}

// The returned list borrows its path strings from the arguments.
fn prepend(allocator: std.mem.Allocator, previous: Entries, path: []const u8) ![][]const u8 {
    var entries: std.ArrayList([]const u8) = .empty;
    errdefer entries.deinit(allocator);
    try entries.append(allocator, path);
    for (previous) |entry| {
        if (entries.items.len == max_entries) break;
        var duplicate = false;
        for (entries.items) |existing| {
            if (std.mem.eql(u8, existing, entry)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) try entries.append(allocator, entry);
    }
    return entries.toOwnedSlice(allocator);
}

pub fn record(allocator: std.mem.Allocator, path: []const u8) !void {
    const previous = try load(allocator);
    defer previous.deinit();
    const entries = try prepend(allocator, previous.value, path);
    defer allocator.free(entries);
    const raw = try std.json.Stringify.valueAlloc(allocator, entries, .{});
    defer allocator.free(raw);
    const io = try pkgenv.getIo();
    const history_path = try getPath(allocator);
    defer allocator.free(history_path);
    var file = try std.Io.Dir.cwd().createFileAtomic(io, history_path, .{ .replace = true });
    defer file.deinit(io);
    try file.file.writeStreamingAll(io, raw);
    try file.replace(io);
}
