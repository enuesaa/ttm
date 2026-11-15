const std = @import("std");

fn rawMode(fd: std.posix.fd_t) !std.posix.termios {
    const original = try std.posix.tcgetattr(fd);
    var raw = original;
    raw.lflag.ICANON = false;
    raw.lflag.ECHO = false;
    raw.lflag.ISIG = false;
    raw.cc[@backingInt(std.posix.V.MIN)] = 1;
    raw.cc[@backingInt(std.posix.V.TIME)] = 0;
    try std.posix.tcsetattr(fd, .NOW, raw);
    return original;
}

pub fn select(options: []const []const u8) !?usize {
    const fd = std.Io.File.stdin().handle;
    const original = try rawMode(fd);
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
    std.debug.print("\x1b[?7l\r\x1b[2K\x1b[90m? Select directory\x1b[0m\r\n", .{});
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

fn moveBack(n: usize) void {
    if (n > 0) std.debug.print("\x1b[{d}D", .{n});
}

pub fn ask(allocator: std.mem.Allocator, text: []const u8, defaultValue: []const u8) ![]u8 {
    if (defaultValue.len == 0) {
        std.debug.print("\x1b[33m? {s}: \x1b[0m", .{text});
    } else {
        std.debug.print("\x1b[33m? {s} (default {s}): \x1b[0m", .{ text, defaultValue });
    }

    const fd = std.Io.File.stdin().handle;
    const original = try rawMode(fd);
    defer std.posix.tcsetattr(fd, .NOW, original) catch {};

    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(allocator);
    var cur: usize = 0;

    while (try readByte(fd, -1)) |byte| {
        switch (byte) {
            '\n', '\r' => break,
            3, 4 => return error.Canceled,
            0x7f, 8 => if (cur > 0) {
                cur -= 1;
                _ = line.orderedRemove(cur);
                std.debug.print("\x08{s} ", .{line.items[cur..]});
                moveBack(line.items.len - cur + 1);
            },
            0x1b => {
                const b1 = try readByte(fd, 50) orelse continue;
                if (b1 != '[' and b1 != 'O') continue;
                var final: u8 = 0;
                while (try readByte(fd, 50)) |c| {
                    if (c >= 0x40 and c <= 0x7e) {
                        final = c;
                        break;
                    }
                }
                if (final == 'D' and cur > 0) {
                    cur -= 1;
                    std.debug.print("\x1b[D", .{});
                } else if (final == 'C' and cur < line.items.len) {
                    cur += 1;
                    std.debug.print("\x1b[C", .{});
                }
            },
            else => if (byte >= 0x20) {
                try line.insert(allocator, cur, byte);
                cur += 1;
                std.debug.print("{s}", .{line.items[cur - 1 ..]});
                moveBack(line.items.len - cur);
            },
        }
    }
    std.debug.print("\r\n", .{});

    return allocator.dupe(u8, if (line.items.len == 0) defaultValue else line.items);
}
