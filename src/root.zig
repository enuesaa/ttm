const std = @import("std");
const pkgregistry = @import("pkg/registry.zig");
const pkgconfig = @import("pkg/config.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgdir = @import("pkg/dir.zig");

pub fn init(allocator: std.mem.Allocator) !void {
    try pkgregistry.make(allocator);
    try pkgregistry.createHookScript(allocator);
    try pkgregistry.createInitialConfig(allocator);

    const hookScriptPath = try pkgregistry.getHookScriptPath(allocator);
    defer allocator.free(hookScriptPath);
    std.debug.print("Add the following hook script to .zshrc:\n\n", .{});
    std.debug.print("eval \"$({s})\"\n", .{hookScriptPath});
}

pub fn edit(allocator: std.mem.Allocator) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const editor = pkgconfig.getInstalledEditor(allocator, parsed.config) catch |err| {
        std.debug.print("{}: failed to find editor. please specify editor path in config file\n", .{err});
        return;
    };
    const configPath = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(configPath);
    const abspath = try pkgdir.abs(allocator, ".");
    defer allocator.free(abspath);
    const workdir = try pkgdir.open(allocator, abspath);
    const command = try std.fmt.allocPrint(allocator, "{s} {s}", .{ editor, configPath });
    defer allocator.free(command);
    try pkgshell.start(allocator, workdir, command);
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

    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleCancel },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);

    const workdir = try pkgdir.open(allocator, abspath);
    try pkgshell.start(allocator, workdir, dest.?.command);

    if (dest.?.onAfterCommand) |onAfterCommand| {
        try pkgshell.start(allocator, workdir, onAfterCommand);
    }
}

var canceling = false;

// NOTE: 開発時注意。zig build run -- が ctrl+c をキャッチして終了してしまう
fn handleCancel(_: c_int) callconv(.c) void {
    if (!canceling) {
        canceling = true;
        std.debug.print("catch ctrl+c\n", .{});
        return;
    }
    std.debug.print("force cancel\n", .{});
}

pub fn ls(allocator: std.mem.Allocator) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    try pkgconfig.listup(allocator, parsed.config);
}
