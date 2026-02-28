const std = @import("std");
const ttm = @import("ttm");
const cli = @import("cli");
const config = @import("config");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // first argument is the binary name like `ttm`
    if (args.len == 2 and std.mem.eql(u8, args[1], "--init")) {
        std.debug.print("init\n", .{});
        return;
    }
    try launchCLI();
}

pub fn launchCLI() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // cli
    var runner = try cli.AppRunner.init(allocator);

    const app = cli.App{
        .version = config.version,
        .command = cli.Command{
            .name = "ttm",
            .description = cli.Description{
                .one_line = "A CLI tool to manage tmp dirs for throwaway work",
            },
            .target = cli.CommandTarget{
                .action = cli.CommandAction{
                    .positional_args = cli.PositionalArgs{
                        .optional = try runner.allocPositionalArgs(&.{
                            .{
                                .name = "to",
                                .help = "to dir name",
                                .value_ref = runner.mkRef(&ttm.cliargs.cdTo),
                            },
                        }),
                    },
                    .exec = ttm.cd,
                },
                // .subcommands = try runner.allocCommands(&.{
                //     cli.Command{
                //         .name = "ls",
                //         .description = cli.Description{
                //             .one_line = "list tmp dirs",
                //         },
                //         .target = cli.CommandTarget{
                //             .action = cli.CommandAction{
                //                 .exec = ttm.list,
                //             },
                //         },
                //     },
                //     cli.Command{
                //         .name = "pin",
                //         .description = cli.Description{
                //             .one_line = "rename and keep tmp dir",
                //         },
                //         .target = cli.CommandTarget{
                //             .action = cli.CommandAction{
                //                 .positional_args = cli.PositionalArgs{
                //                     .required = try runner.allocPositionalArgs(&.{
                //                         .{
                //                             .name = "FROM",
                //                             .help = "tmpdir name",
                //                             .value_ref = runner.mkRef(&ttm.cliargs.pinFrom),
                //                         },
                //                         .{
                //                             .name = "TO",
                //                             .help = "tmpdir name",
                //                             .value_ref = runner.mkRef(&ttm.cliargs.pinTo),
                //                         },
                //                     }),
                //                 },
                //                 .exec = ttm.pin,
                //             },
                //         },
                //     },
                //     cli.Command{
                //         .name = "rm",
                //         .description = cli.Description{
                //             .one_line = "remove tmp dir",
                //         },
                //         .target = cli.CommandTarget{
                //             .action = cli.CommandAction{
                //                 .positional_args = cli.PositionalArgs{
                //                     .required = try runner.allocPositionalArgs(&.{
                //                         .{
                //                             .name = "REMOVE",
                //                             .help = "tmpdir name",
                //                             .value_ref = runner.mkRef(&ttm.cliargs.removeDir),
                //                         },
                //                     }),
                //                 },
                //                 .exec = ttm.remove,
                //             },
                //         },
                //     },
                //     cli.Command{
                //         .name = "prune",
                //         .description = cli.Description{
                //             .one_line = "remove archived tmp dirs",
                //         },
                //         .target = cli.CommandTarget{
                //             .action = cli.CommandAction{
                //                 .exec = ttm.prune,
                //             },
                //         },
                //     },
                //     cli.Command{
                //         .name = "cd",
                //         .description = cli.Description{
                //             .one_line = "cd",
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
                // }),
            },
        },
        .help_config = cli.HelpConfig{
            .color_usage = .never,
        },
    };
    defer allocator.free(ttm.cliargs.removeDir);
    defer allocator.free(ttm.cliargs.pinFrom);
    defer allocator.free(ttm.cliargs.pinTo);
    defer allocator.free(ttm.cliargs.cdTo);
    try runner.run(&app);
}
