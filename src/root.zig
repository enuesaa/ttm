const std = @import("std");
const pkgregistry = @import("pkg/registry.zig");
const pkgconfig = @import("pkg/config.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgdir = @import("pkg/dir.zig");

pub fn init(allocator: std.mem.Allocator) !void {
    try pkgregistry.make(allocator);
    try pkgregistry.createHookScript(allocator);

    const hookScriptPath = try pkgregistry.getHookScriptPath(allocator);
    defer allocator.free(hookScriptPath);
    std.debug.print("Add the following hook script to .zshrc:\n\n", .{});
    std.debug.print("eval \"$({s})\"\n", .{hookScriptPath});
}

pub fn cd(allocator: std.mem.Allocator, cliTo: []const u8) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();

    const dest = parsed.config.getPath(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    const abspath = try pkgdir.abs(allocator, dest.?.path);
    defer allocator.free(abspath);
    std.debug.print("{s}\n", .{abspath});

    const workdir = try pkgdir.open(allocator, abspath);
    try pkgshell.start(allocator, workdir, dest.?.command);
}

pub fn ls(allocator: std.mem.Allocator) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();

    try pkgconfig.listup(allocator, parsed.config);
}
