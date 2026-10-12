const std = @import("std");
const builtin = @import("builtin");
const pkgenv = @import("env.zig");

pub fn select(options: []const []const u8) !?usize {
    const io = try pkgenv.getIo();
    const term = pkgenv.envMap.?.get("TERM") orelse "";
    if (try std.Io.File.stdin().isTty(io) and
        try std.Io.File.stderr().isTty(io) and
        !std.mem.eql(u8, term, "dumb"))
    {
        return selectInteractive(options);
    }
    return selectNumbered(options);
}

fn selectInteractive(options: []const []const u8) !?usize {
    const fd = std.Io.File.stdin().handle;
    const original = try std.posix.tcgetattr(fd);
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.ISIG = false;
    raw.lflag.IEXTEN = false;
    raw.iflag.IXON = false;
    raw.iflag.ICRNL = false;
    raw.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    raw.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    try std.posix.tcsetattr(fd, .NOW, raw);
    defer std.posix.tcsetattr(fd, .NOW, original) catch {};

    const visible = @min(options.len, @max(1, terminalRows() -| 2));
    for (0..visible + 1) |_| std.debug.print("\n", .{});
    std.debug.print("\x1b[{d}A\r\x1b[?25l", .{visible + 1});
    defer std.debug.print("\r\x1b[J\x1b[0m\x1b[?25h", .{});

    var selected: usize = 0;
    var first: usize = 0;
    while (true) {
        if (selected < first) first = selected;
        if (selected >= first + visible) first = selected - visible + 1;
        drawOptions(options[first..][0..visible], selected - first);
        switch (try readKey(fd)) {
            .up => selected = if (selected == 0) options.len - 1 else selected - 1,
            .down => selected = (selected + 1) % options.len,
            .confirm => return selected,
            .cancel => return null,
            .ignore => {},
        }
    }
}

fn terminalRows() usize {
    var size: std.posix.winsize = std.mem.zeroes(std.posix.winsize);
    const fd = std.Io.File.stderr().handle;
    const result = if (builtin.os.tag == .linux)
        std.os.linux.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&size))
    else
        std.c.ioctl(fd, std.posix.T.IOCGWINSZ, &size);
    return if (result == 0 and size.row > 0) size.row else 24;
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
        '\r', '\n' => return .confirm,
        3, 4 => return .cancel,
        0x1b => {
            const prefix = try readByte(fd, 100) orelse return .cancel;
            if (prefix != '[' and prefix != 'O') return .ignore;
            while (try readByte(fd, 100)) |code| {
                if (code >= 0x40 and code <= 0x7e) return switch (code) {
                    'A' => .up,
                    'B' => .down,
                    else => .ignore,
                };
            }
            return .ignore;
        },
        else => return .ignore,
    }
}

fn selectNumbered(options: []const []const u8) !?usize {
    for (options, 1..) |option, i| {
        std.debug.print("  {d}) {s}\n", .{ i, option });
    }
    const fd = std.Io.File.stdin().handle;
    while (true) {
        std.debug.print("\x1b[33m? Select directory (1-{d}, Enter to cancel): \x1b[0m", .{options.len});
        var buf: [64]u8 = undefined;
        var len: usize = 0;
        while (true) {
            const byte = try readByte(fd, -1) orelse return null;
            if (byte == '\n') break;
            if (len < buf.len) buf[len] = byte;
            len += 1;
        }
        const overflow = len > buf.len;
        const line = std.mem.trim(u8, buf[0..@min(len, buf.len)], " \t\r");
        if (!overflow and line.len == 0) return null;
        const number = if (overflow) 0 else std.fmt.parseInt(usize, line, 10) catch 0;
        if (number >= 1 and number <= options.len) return number - 1;
        std.debug.print("Please enter a number from 1 to {d}.\n", .{options.len});
    }
}

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    const io = try pkgenv.getIo();
    if (std.mem.eql(u8, defaultValue, "")) {
        std.debug.print("\x1b[33m? {s}: \x1b[0m", .{text});
    } else {
        std.debug.print("\x1b[33m? {s} (default {s}): \x1b[0m", .{ text, defaultValue });
    }

    // TODO: 矢印キーのANSIエスケープシーケンスがそのまま入力されてしまう
    var buf: [100]u8 = undefined;
    const stdin = std.Io.File.stdin();
    var reader = stdin.reader(io, &buf);

    const line = reader.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
        error.EndOfStream => return try allocator.dupe(u8, defaultValue),
        else => return err,
    };
    if (line.len == 0) {
        return try allocator.dupe(u8, defaultValue);
    }
    return try allocator.dupe(u8, line);
}
