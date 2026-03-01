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

    var scli = pkgscli.CLI.init(allocator, args);
    defer scli.deinit();
    const helpFlag = try scli.flagBool("--help");
    const aFlag = try scli.flagValue("--a");
    const result = scli.parse();
    if (!result.ok) {
        std.debug.print("error: {s} {s}\n", .{ result.errName, result.errArg });
        return;
    }
    if (helpFlag.is) {
        const helpText = try scli.generateHelpText();
        defer allocator.free(helpText);
        std.debug.print("{s}\n", .{helpText});
        return;
    }
    if (aFlag.is) {
        std.debug.print("{s}\n", .{aFlag.value.?});
    }
    std.debug.print("positionals {}\n", .{scli.positionals});

    // // first argument is the binary name like `ttm`
    // if (args.len == 2 and std.mem.eql(u8, args[1], "--init")) {
    //     try std.fs.File.stdout().writeAll(initsh);
    //     return;
    // }

    // // cli
    // var runner = try cli.AppRunner.init(allocator);

    // const app = cli.App{
    //     .version = config.version,
    //     .command = cli.Command{
    //         .name = "ttm",
    //         .description = cli.Description{
    //             .one_line = "A CLI tool to manage tmp dirs for throwaway work",
    //         },
    //         .target = cli.CommandTarget{
    //             .action = cli.CommandAction{
    //                 .positional_args = cli.PositionalArgs{
    //                     .optional = try runner.allocPositionalArgs(&.{
    //                         .{
    //                             .name = "to",
    //                             .help = "to dir name",
    //                             .value_ref = runner.mkRef(&ttm.cliargs.cdTo),
    //                         },
    //                     }),
    //                 },
    //                 .exec = ttm.cd,
    //             },
    //         },
    //     },
    //     .help_config = cli.HelpConfig{
    //         .color_usage = .never,
    //     },
    // };
    // defer allocator.free(ttm.cliargs.removeDir);
    // defer allocator.free(ttm.cliargs.pinFrom);
    // defer allocator.free(ttm.cliargs.pinTo);
    // defer allocator.free(ttm.cliargs.cdTo);
    // try runner.run(&app);
}
