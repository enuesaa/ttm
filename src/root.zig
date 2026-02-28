const std = @import("std");
const pkgregistry = @import("pkg/registry.zig");
const pkgtmpdir = @import("pkg/tmpdir.zig");
const pkgshell = @import("pkg/shell.zig");
const pkgpinprompt = @import("pkg/pinprompt.zig");
const pkglist = @import("pkg/list.zig");
const pkgprune = @import("pkg/prune.zig");

// NOTE:
// Do not return values from functions in this file to normalize the interface and its memory allocation.

pub var cliargs = struct {
    removeDir: []const u8 = undefined,
    pinFrom: []const u8 = undefined,
    pinTo: []const u8 = undefined,
    cdTo: []const u8 = undefined,
}{};

pub fn workInTmp() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // create registry if not exist
    try pkgregistry.make(allocator);

    // create
    var tmpdir = try pkgtmpdir.make(allocator);
    std.debug.print("* started: {s}\n", .{tmpdir.dirName});
    defer tmpdir.deinit();

    // start shell
    try pkgshell.start(tmpdir.path);
    try pkgpinprompt.startPinPrompt(allocator, tmpdir.dirName);
}

pub fn list() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try pkglist.list(allocator);
}

pub fn remove() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tmpdir = pkgtmpdir.get(allocator, cliargs.removeDir) catch {
        std.debug.print("tmpdir not found\n", .{});
        return;
    };
    try tmpdir.delete();
}

pub fn prune() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try pkgprune.prune(allocator);
}

pub fn pin() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    std.debug.print("* pin {s} as {s}\n", .{ cliargs.pinFrom, cliargs.pinTo });

    var tmpdir = pkgtmpdir.get(allocator, cliargs.pinFrom) catch {
        std.debug.print("tmpdir not found\n", .{});
        return;
    };
    try tmpdir.rename(cliargs.pinTo);
}

pub fn cd() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var config = try pkgregistry.getConfig(allocator);
    defer config.deinit();

    const to = try allocator.dupe(
        u8,
        if (std.mem.eql(u8, cliargs.cdTo, "")) "default" else cliargs.cdTo,
    );
    defer allocator.free(to);
    std.debug.print("to: {s}", .{to});

    if (std.mem.eql(u8, cliargs.cdTo, "default")) {
        std.debug.print("path: {s}", .{config.paths.get("default").?.path});
        const workdir = try std.fs.openDirAbsolute(config.paths.get("default").?.path, .{});
        try pkgshell.startTTMShell(allocator, workdir);
    }
}
