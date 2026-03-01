const std = @import("std");
const ttm = @import("ttm");
const cli = @import("cli");
const config = @import("config");
const initsh = @embedFile("init.sh");
const pkgscli = @import("pkg/scli.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var scli = pkgscli.CLI.init(allocator);
    defer scli.deinit();
    scli.description = "A CLI tool to move another directory temporarily.";
    scli.usage = "ttm <to>";

    const helpFlag = try scli.flagBool("--help");
    helpFlag.description = "show help";
    const versionFlag = try scli.flagBool("--version");
    versionFlag.description = "show version";
    const initFlag = try scli.flagBool("--init");
    initFlag.description = "print hook script for zsh";

    const err = scli.parse(args);
    if (err != null) {
        std.debug.print("error: {s}: {s}\n", .{ err.?.name, err.?.arg });
        return;
    }
    if (helpFlag.is) {
        const helpText = try scli.generateHelpText();
        std.debug.print("{s}\n", .{helpText});
        return;
    }
    if (versionFlag.is) {
        std.debug.print("v0.0.6\n", .{});
        return;
    }
    if (initFlag.is) {
        try std.fs.File.stdout().writeAll(initsh);
        return;
    }

    if (scli.positionals.items.len > 1) {
        std.debug.print("error: too many positional arguments.\n", .{});
        return;
    }
    if (scli.positionals.items.len == 1) {
        try ttm.cd(allocator, scli.positionals.items[0]);
        return;
    }
    try ttm.cd(allocator, "default");
}
