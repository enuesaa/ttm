const std = @import("std");
const pkglog = @import("pkg/log.zig");
const pkgregistry = @import("pkg/registry.zig");
const pkgconfig = @import("pkg/config.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgdir = @import("pkg/dir.zig");
const pkgenv = @import("pkg/env.zig");
const pkgprompt = @import("pkg/prompt.zig");
const pkgexpsessionmark = @import("pkg/expsessionmark.zig");

pub fn initialize(envmap: *std.process.Environ.Map, io: std.Io) void {
    pkgenv.envMap = envmap;
    pkgenv.io = io;
}

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
    var envmap = try pkgenv.cloneEnvMap(allocator);
    defer envmap.deinit();
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const editor = pkgconfig.getInstalledEditor(allocator, parsed.config) catch |err| {
        std.debug.print("{}: failed to find editor. please specify editor path in config file\n", .{err});
        return;
    };
    const configPath = try pkgregistry.getConfigPath(allocator);
    defer allocator.free(configPath);
    const homedir = try pkgenv.getHomeDir(allocator);
    defer allocator.free(homedir);
    const workdir = try pkgdir.open(homedir);
    const command = try std.fmt.allocPrint(allocator, "{s} {s}", .{ editor, configPath });
    defer allocator.free(command);
    try pkgshell.start(allocator, workdir, command, &envmap);
}

pub fn cd(allocator: std.mem.Allocator, cliTo: []const u8) !void {
    var envmap = try pkgenv.cloneEnvMap(allocator);
    defer envmap.deinit();
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const dest = parsed.config.getPath(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    std.debug.print("{s}*** {s} ***{s}\n", .{ "\x1b[33m", dest.?.path, "\x1b[0m" });

    buildEnvVars(allocator, dest, &envmap) catch |err| {
        std.debug.print("error: failed to build env vars because of {}\n", .{err});
        return;
    };
    const destpath = try pkgdir.abs(allocator, dest.?.path);
    defer allocator.free(destpath);
    const workdir = try pkgdir.open(destpath);
    if (dest.?.onBeforeCommand) |onBeforeCommand| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", onBeforeCommand, "\x1b[0m" });
        try pkgshell.start(allocator, workdir, onBeforeCommand, &envmap);
    }
    if (dest.?.command) |cmd| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", cmd, "\x1b[0m" });
        pkgshell.hookCancel();
    }
    pkgexpsessionmark.create(allocator, destpath) catch {};
    try pkgshell.start(allocator, workdir, dest.?.command, &envmap);
    pkgexpsessionmark.delete(allocator) catch {};

    if (dest.?.onAfterCommand) |onAfterCommand| {
        std.debug.print("{s}* {s}{s}\n", .{ "\x1b[33m", onAfterCommand, "\x1b[0m" });
        try pkgshell.start(allocator, workdir, onAfterCommand, &envmap);
    }
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
    var envmap = try pkgenv.cloneEnvMap(allocator);
    defer envmap.deinit();
    const destpath = try pkgexpsessionmark.get(allocator);
    defer allocator.free(destpath);
    const workdir = try pkgdir.open(destpath);
    try pkgshell.start(allocator, workdir, null, &envmap);
}

fn buildEnvVars(allocator: std.mem.Allocator, dest: ?pkgconfig.Path, envmap: *std.process.Environ.Map) !void {
    if (dest.?.envs) |evs| {
        for (evs) |ev| {
            if (ev.ask) |askText| {
                const askRet = try pkgprompt.ask(allocator, askText, ev.value);
                defer allocator.free(askRet);
                if (ev.required != null and ev.required.? == true and std.mem.eql(u8, askRet, "")) {
                    envmap.deinit();
                    std.debug.print("error: {s} is required\n", .{ev.key});
                    return error.failedToBuildEnvVars;
                }
                try envmap.put(ev.key, askRet);
            } else {
                try envmap.put(ev.key, ev.value);
            }
        }
    }
}
