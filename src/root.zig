const std = @import("std");
const pkgregistry = @import("pkg/registry.zig");
const pkgconfig = @import("pkg/config.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgdir = @import("pkg/dir.zig");
const pkgprompt = @import("pkg/prompt.zig");
const pkgexpsessionmark = @import("pkg/expsessionmark.zig");

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
    const workdir = try pkgdir.openr(allocator, ".");
    const command = try std.fmt.allocPrint(allocator, "{s} {s}", .{ editor, configPath });
    defer allocator.free(command);
    var envvars = try pkgshell.getCurrentEnvVars(allocator);
    defer envvars.deinit();
    try pkgshell.start(allocator, workdir, command, &envvars);
}

pub fn cd(allocator: std.mem.Allocator, cliTo: []const u8) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const dest = parsed.config.getPath(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    std.debug.print("{s}*** {s} ***{s}\n", .{ "\x1b[33m", dest.?.path, "\x1b[0m" });

    var envvars = buildEnvVars(allocator, dest) catch |err| {
        std.debug.print("error: failed to build env vars because of {}\n", .{err});
        return;
    };
    defer envvars.deinit();
    const destpath = try pkgdir.marshalabs(allocator, dest.?.path, &envvars);
    defer allocator.free(destpath);
    if (!pkgdir.exists(destpath)) {
        pkgdir.mkdir(destpath) catch |err| {
            std.debug.print("error: failed to create dir {s} because of {}\n", .{ destpath, err });
            return;
        };
    }
    const workdir = try pkgdir.open(destpath);
    if (dest.?.onBeforeCommand) |onBeforeCommand| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", onBeforeCommand, "\x1b[0m" });
        try pkgshell.start(allocator, workdir, onBeforeCommand, &envvars);
    }
    if (dest.?.command) |cmd| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", cmd, "\x1b[0m" });
        hookCancel();
    }
    pkgexpsessionmark.create(allocator, destpath) catch {};
    try pkgshell.start(allocator, workdir, dest.?.command, &envvars);
    pkgexpsessionmark.delete(allocator) catch {};

    if (dest.?.onAfterCommand) |onAfterCommand| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", onAfterCommand, "\x1b[0m" });
        try pkgshell.start(allocator, workdir, onAfterCommand, &envvars);
    }
}

// NOTE: 開発時注意。zig build run -- が ctrl+c をキャッチして終了してしまう
fn hookCancel() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleCancel },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}
var canceling = false;

fn handleCancel(_: c_int) callconv(.c) void {
    if (!canceling) {
        canceling = true;
        std.debug.print("catch ctrl+c\n", .{});
        return;
    }
    std.debug.print("force cancel\n", .{});
}

pub fn ls(allocator: std.mem.Allocator) !void {
    var parsed = pkgconfig.get(allocator) catch |err| {
        std.debug.print("failed to get config file because the error: {}\n", .{err});
        return;
    };
    defer parsed.deinit();
    try pkgconfig.listup(allocator, parsed.config);
}

// experimental
pub fn last(allocator: std.mem.Allocator) !void {
    const destpath = try pkgexpsessionmark.get(allocator);
    defer allocator.free(destpath);
    const workdir = try pkgdir.open(destpath);
    var envvars = try pkgshell.getCurrentEnvVars(allocator);
    defer envvars.deinit();
    try pkgshell.start(allocator, workdir, null, &envvars);
}

// experimental
pub fn cdexec(allocator: std.mem.Allocator, cliTo: []const u8, commands: [][]const u8) !void {
    const command = try std.mem.join(allocator, " ", commands);
    defer allocator.free(command);
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const dest = parsed.config.getPath(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    std.debug.print("{s}*** InstantCommandExecution is an experimental feature ***{s}\n", .{ "\x1b[33m", "\x1b[0m" });
    std.debug.print("{s}*** {s} ***{s}\n", .{ "\x1b[33m", dest.?.path, "\x1b[0m" });
    std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", command, "\x1b[0m" });

    var envvars = buildEnvVars(allocator, dest) catch |err| {
        std.debug.print("error: failed to build env vars because of {}\n", .{err});
        return;
    };
    defer envvars.deinit();
    const destpath = try pkgdir.marshalabs(allocator, dest.?.path, &envvars);
    defer allocator.free(destpath);
    if (!pkgdir.exists(destpath)) {
        pkgdir.mkdir(destpath) catch |err| {
            std.debug.print("error: failed to create dir {s} because of {}\n", .{ destpath, err });
            return;
        };
    }
    const workdir = try pkgdir.open(destpath);
    try pkgshell.start(allocator, workdir, command, &envvars);
}

fn buildEnvVars(allocator: std.mem.Allocator, dest: ?pkgconfig.Path) !std.process.EnvMap {
    var envvars = try pkgshell.getCurrentEnvVars(allocator);
    if (dest.?.envs) |evs| {
        for (evs) |ev| {
            if (ev.ask) |askText| {
                const askRet = try pkgprompt.ask(allocator, askText, ev.value);
                defer allocator.free(askRet);
                if (ev.required != null and ev.required.? == true and std.mem.eql(u8, askRet, "")) {
                    envvars.deinit();
                    std.debug.print("error: {s} is required\n", .{ev.key});
                    return error.failedToBuildEnvVars;
                }
                try envvars.put(ev.key, askRet);
            } else {
                try envvars.put(ev.key, ev.value);
            }
        }
    }
    return envvars;
}
