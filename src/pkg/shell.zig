const std = @import("std");
const pkgenv = @import("env.zig");

pub fn start(_: std.mem.Allocator, workdir: std.Io.Dir, command: ?[]const u8, envvars: *std.process.Environ.Map) !void {
    const io = try pkgenv.getIo();

    // change background color
    std.debug.print("\x1b]11;#2b2b1a\x07", .{});

    const argv = if (command == null) &[_][]const u8{"zsh"} else &[_][]const u8{ "sh", "-c", command.? };
    var child = try std.process.spawn(io, .{
        .argv = argv,
        .environ_map = envvars,
        .cwd = .{ .dir = workdir },
    });
    _ = try child.wait(io);

    // revert background color
    std.debug.print("\x1b]111\x07", .{});
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
