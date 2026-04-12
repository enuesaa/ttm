const std = @import("std");
const ttm = @import("ttm");
const config = @import("config");
const pkgscli = @import("pkg/scli.zig");

pub const std_options: std.Options = .{
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .tokenizer, .level = .warn },
        .{ .scope = .parser, .level = .warn },
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var scli = pkgscli.CLI.init(allocator, "ttm", "A CLI tool to move another directory temporarily.");
    defer scli.deinit();
    scli.usage = "ttm <to>";

    const helpFlag = try scli.flagBool("-help", "show help");
    const versionFlag = try scli.flagBool("-version", "show version");
    const initFlag = try scli.flagBool("-init", "print hook script for zsh");
    const editFlag = try scli.flagBool("-edit", "edit ttm config file");
    const lsFlag = try scli.flagBool("-ls", "list directories to move");
    lsFlag.alias = "-l";
    const lastFlag = try scli.flagBool("-last", "open last-used dir. this is experimental");

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
        std.debug.print("v{s}\n", .{config.version});
        return;
    }
    if (initFlag.is) {
        try ttm.init(allocator);
        return;
    }
    if (editFlag.is) {
        try ttm.edit(allocator);
        return;
    }
    if (lsFlag.is) {
        try ttm.ls(allocator);
        return;
    }
    if (lastFlag.is) {
        try ttm.last(allocator);
        return;
    }

    if (scli.positionals.items.len > 1) {
        try ttm.cdexec(allocator, scli.positionals.items[0], scli.positionals.items[1..]);
        return;
    }
    if (scli.positionals.items.len == 1) {
        try ttm.cd(allocator, scli.positionals.items[0]);
        return;
    }
    try ttm.cd(allocator, "default");
}
