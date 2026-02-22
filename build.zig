const std = @import("std");

// see https://ziglang.org/learn/build-system/
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // deps
    const zigcli = b.dependency("cli", .{
        .target = target,
        .optimize = optimize,
    });
    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });
    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });
    const toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });

    // mod
    const mod = b.addModule("ttm", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vaxis", .module = vaxis.module("vaxis") },
            .{ .name = "yaml", .module = yaml.module("yaml") },
            .{ .name = "toml", .module = toml.module("toml") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "ttm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ttm", .module = mod },
                .{ .name = "cli", .module = zigcli.module("cli") },
            },
        }),
    });
    const options = b.addOptions();
    options.addOption([]const u8, "version", "0.0.4");
    exe.root_module.addOptions("config", options);
    b.installArtifact(exe);

    // run
    const run_exe = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);
    run_exe.step.dependOn(b.getInstallStep());

    // test
    const test_mod = b.addTest(.{
        .root_module = mod,
    });
    const run_test_mod = b.addRunArtifact(test_mod);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_test_mod.step);
}
