const std = @import("std");
const pkgregistry = @import("pkg/registry.zig");
const pkgshell = @import("pkg/shell.zig");
const pkglist = @import("pkg/list.zig");
const pkgdir = @import("pkg/dir.zig");
const pkgsetprompt = @import("pkg/setprompt.zig");

pub fn init(allocator: std.mem.Allocator) !void {
    try pkgregistry.make(allocator);
    try pkgregistry.createHookScript(allocator);

    const hookScriptPath = try pkgregistry.getHookScriptPath(allocator);
    defer allocator.free(hookScriptPath);
    std.debug.print("Add the following hook script to .zshrc:\n\n", .{});
    std.debug.print("eval \"$({s})\"\n", .{hookScriptPath});
}

pub fn cd(allocator: std.mem.Allocator, cliTo: []const u8) !void {
    var config = try pkgregistry.getConfig(allocator);
    defer config.deinit();

    const dest = config.paths.get(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    const abspath = try pkgdir.abs(allocator, dest.?.path);
    defer allocator.free(abspath);
    std.debug.print("{s}\n", .{abspath});

    const workdir = try pkgdir.open(allocator, abspath);
    try pkgshell.startShell(allocator, workdir);
}

pub fn ls(allocator: std.mem.Allocator) !void {
    var config = try pkgregistry.getConfig(allocator);
    defer config.deinit();

    var it = config.paths.iterator();
    while (it.next()) |entry| {
        const name = entry.key_ptr.*;
        const path = entry.value_ptr.*;
        std.debug.print("{s}:\n  {s}\n\n", .{ name, path.path });
    }
}

pub fn set(allocator: std.mem.Allocator) !void {
    try pkgsetprompt.startPrompt(allocator);
    return;
}
