const std = @import("std");
const pkgenv = @import("env.zig");

pub fn select(options: []const []const u8) !?usize {
    const fd = std.Io.File.stdin().handle;
    const original = try std.posix.tcgetattr(fd);
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.ISIG = false;
    raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    try std.posix.tcsetattr(fd, .NOW, raw);
    defer std.posix.tcsetattr(fd, .NOW, original) catch {};

    for (0..options.len + 1) |_| std.debug.print("\n", .{});
    std.debug.print("\x1b[{d}A\r\x1b[?25l", .{options.len + 1});
    defer std.debug.print("\r\x1b[J\x1b[0m\x1b[?25h", .{});

    var selected: usize = 0;
    while (true) {
        drawOptions(options, selected);
        switch (try readKey(fd)) {
            .up => selected = if (selected == 0) options.len - 1 else selected - 1,
            .down => selected = (selected + 1) % options.len,
            .confirm => return selected,
            .cancel => return null,
            .ignore => {},
        }
    }
}

fn drawOptions(options: []const []const u8, selected: usize) void {
    std.debug.print("\x1b[?7l\r\x1b[2K? Select directory\r\n", .{});
    for (options, 0..) |option, i| {
        std.debug.print("\x1b[2K{s}", .{if (i == selected) "\x1b[36m> " else "  "});
        for (option) |byte| {
            std.debug.print("{c}", .{if (byte < 0x20 or byte == 0x7f) '?' else byte});
        }
        std.debug.print("\x1b[0m\r\n", .{});
    }
    std.debug.print("\x1b[{d}A\r\x1b[?7h", .{options.len + 1});
}

const Key = enum { up, down, confirm, cancel, ignore };

fn readByte(fd: std.posix.fd_t, timeout_ms: i32) !?u8 {
    var fds = [_]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 }};
    if (try std.posix.poll(&fds, timeout_ms) == 0) return null;
    var byte: [1]u8 = undefined;
    if (try std.posix.read(fd, &byte) == 0) return null;
    return byte[0];
}

fn readKey(fd: std.posix.fd_t) !Key {
    const byte = try readByte(fd, -1) orelse return .cancel;
    switch (byte) {
        '\n' => return .confirm,
        3, 4 => return .cancel,
        0x1b => {
            if (try readByte(fd, 100) == null) return .cancel;
            return switch (try readByte(fd, 100) orelse return .ignore) {
                'A' => .up,
                'B' => .down,
                else => .ignore,
            };
        },
        else => return .ignore,
    }
}

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    const io = try pkgenv.getIo();
    if (defaultValue.len == 0) {
        std.debug.print("\x1b[33m? {s}: \x1b[0m", .{text});
    } else {
        std.debug.print("\x1b[33m? {s} (default {s}): \x1b[0m", .{ text, defaultValue });
    }

    // TODO: 矢印キーのANSIエスケープシーケンスがそのまま入力されてしまう
    var buf: [100]u8 = undefined;
    const stdin = std.Io.File.stdin();
    var reader = stdin.reader(io, &buf);

    const line = reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => "",
        else => return err,
    };
    return allocator.dupe(u8, if (line.len == 0) defaultValue else line);
}
