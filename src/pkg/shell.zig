const std = @import("std");
const pkgenv = @import("env.zig");

fn buildTTMNestedEnvVar(allocator: std.mem.Allocator) ![]const u8 {
    const envMap = try pkgenv.getEnvMap();
    const original = envMap.get("TTM_NESTED");
    if (original == null) {
        return allocator.dupe(u8, "*");
    }
    return try std.mem.concat(allocator, u8, &.{ original.?, "*" });
}

pub fn start(allocator: std.mem.Allocator, workdir: std.Io.Dir, command: ?[]const u8, envvars: *std.process.Environ.Map) !void {
    const io = try pkgenv.getIo();
    const ttmNested = try buildTTMNestedEnvVar(allocator);
    defer allocator.free(ttmNested);
    try envvars.put("TTM", "true");
    try envvars.put("TTM_NESTED", ttmNested);

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .environ_map = envvars,
        .cwd = .{ .dir = workdir },
    });
    _ = try child.wait(io);
}

// NOTE: 開発時注意. zig build run -- が ctrl+c をキャッチして終了してしまう
pub fn hookCancel() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = handleCancel },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}
var canceling = false;

fn handleCancel(_: std.posix.SIG) callconv(.c) void {
    if (!canceling) {
        canceling = true;
        std.debug.print("catch ctrl+c\n", .{});
        return;
    }
    std.debug.print("force cancel\n", .{});
}
