const std = @import("std");
const pkglog = @import("pkg/log.zig");
const pkgregistry = @import("pkg/registry.zig");
const pkgconfig = @import("pkg/config.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgdir = @import("pkg/dir.zig");
const pkgenv = @import("pkg/env.zig");
const pkgprompt = @import("pkg/prompt.zig");
const pkghistory = @import("pkg/history.zig");

pub fn initialize(envmap: *std.process.Environ.Map, io: std.Io) void {
    pkgenv.envMap = envmap;
    pkgenv.io = io;
}

pub fn init(allocator: std.mem.Allocator) !void {
    if (!try pkgregistry.isRegistryExist(allocator)) {
        try pkgregistry.makeRegistry(allocator);
    }
    if (!try pkgregistry.isConfigExist(allocator)) {
        try pkgregistry.createInitialConfig(allocator);
    }
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
    const io = try pkgenv.getIo();
    var envmap = try pkgenv.cloneEnvMap(allocator);
    defer envmap.deinit();
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const dest = parsed.config.getPath(cliTo);
    if (dest == null) {
        std.debug.print("dest not found: {s}\n", .{cliTo});
        return;
    }
    pkglog.infoln("* ttm session started!", .{});

    buildEnvVars(allocator, dest, &envmap) catch |err| {
        std.debug.print("error: failed to build env vars because of {}\n", .{err});
        return;
    };
    const destpath = try pkgdir.abs(allocator, dest.?.path);
    defer allocator.free(destpath);
    const workdir = try pkgdir.open(destpath);
    defer workdir.close(io);
    if (dest.?.onBeforeCommand) |onBeforeCommand| {
        pkglog.infoln("* {s}", .{onBeforeCommand});
        try pkgshell.start(allocator, workdir, onBeforeCommand, &envmap);
    }
    if (dest.?.command) |cmd| {
        pkglog.infoln("* {s}", .{cmd});
        pkgshell.hookCancel();
    }
    recordHistory(allocator, destpath);
    try pkgshell.start(allocator, workdir, dest.?.command, &envmap);

    if (dest.?.onAfterCommand) |onAfterCommand| {
        pkglog.infoln("* {s}", .{onAfterCommand});
        try pkgshell.start(allocator, workdir, onAfterCommand, &envmap);
    }
}

pub fn pick(allocator: std.mem.Allocator) !void {
    var parsed = try pkgconfig.get(allocator);
    defer parsed.deinit();
    const paths = parsed.config.paths;

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var maxName: usize = 0;
    for (paths) |p| maxName = @max(maxName, p.name.len);
    const labels = try a.alloc([]const u8, paths.len);
    for (paths, labels) |p, *label| {
        var buf = std.array_list.Managed(u8).init(a);
        try buf.appendSlice(p.name);
        try buf.appendNTimes(' ', maxName - p.name.len + 2);
        try buf.appendSlice(p.path);
        label.* = buf.items;
    }
    const selected = try pkgprompt.select(labels) orelse return;
    try cd(allocator, paths[selected].name);
}

pub fn history(allocator: std.mem.Allocator) !void {
    const io = try pkgenv.getIo();
    const entries = pkghistory.load(allocator) catch |err| {
        std.debug.print("error: failed to read history: {}\n", .{err});
        return;
    };
    defer entries.deinit();
    if (entries.value.len == 0) {
        std.debug.print("No directory history yet.\n", .{});
        return;
    }
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const labels = try arena.allocator().alloc([]const u8, entries.value.len);
    for (entries.value, labels) |path, *label| {
        label.* = try pkgdir.tilde(arena.allocator(), path);
    }
    const selected = try pkgprompt.select(labels) orelse return;
    const destpath = entries.value[selected];
    const workdir = pkgdir.open(destpath) catch |err| {
        std.debug.print("error: cannot open directory {s}: {}\n", .{ destpath, err });
        return;
    };
    defer workdir.close(io);
    var envmap = try pkgenv.cloneEnvMap(allocator);
    defer envmap.deinit();
    recordHistory(allocator, destpath);
    try pkgshell.start(allocator, workdir, null, &envmap);
}

fn recordHistory(allocator: std.mem.Allocator, path: []const u8) void {
    pkghistory.record(allocator, path) catch |err| {
        std.debug.print("warning: failed to save history: {}\n", .{err});
    };
}

test {
    _ = pkghistory;
}

fn buildEnvVars(allocator: std.mem.Allocator, dest: ?pkgconfig.Path, envmap: *std.process.Environ.Map) !void {
    if (dest.?.envs) |evs| {
        for (evs) |ev| {
            if (ev.ask) |askText| {
                const askRet = try pkgprompt.ask(allocator, askText, ev.value);
                defer allocator.free(askRet);
                if (ev.required != null and ev.required.? == true and std.mem.eql(u8, askRet, "")) {
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
