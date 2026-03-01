const std = @import("std");

pub const FlagBool = struct {
    name: []const u8,
    description: []const u8,
    is: bool = false,
};

pub const Flag = struct {
    name: []const u8,
    description: []const u8,
    is: bool = false,
    value: ?[]const u8 = null,
    isBoolFlag: bool,
    isValueFlag: bool,
};

// pub const MissingFlagValue = error{};

pub const CLI = struct {
    allocator: std.mem.Allocator,
    argv: [][:0]u8,
    flags: std.array_list.Managed(Flag),

    pub fn init(allocator: std.mem.Allocator, argv: [][:0]u8) CLI {
        return .{
            .allocator = allocator,
            .argv = argv,
            .flags = std.array_list.Managed(Flag).init(allocator),
        };
    }

    pub fn deinit(self: *CLI) void {
        self.flags.deinit();
    }

    pub fn flagBool(self: *CLI, name: []const u8) !*Flag {
        try self.flags.append(.{
            .name = name,
            .description = "",
            .is = false,
            .isBoolFlag = true,
            .isValueFlag = false,
        });
        return &self.flags.items[self.flags.items.len - 1];
    }

    pub fn flagValue(self: *CLI, name: []const u8) !*Flag {
        try self.flags.append(.{
            .name = name,
            .description = "",
            .is = false,
            .value = "",
            .isBoolFlag = false,
            .isValueFlag = true,
        });
        return &self.flags.items[self.flags.items.len - 1];
    }

    pub fn parse(self: *CLI) !void {
        for (self.argv[1..]) |arg| {
            if (!std.mem.startsWith(u8, arg, "--")) {
                continue;
            }
            for (self.flags.items) |*flag| {
                if (std.mem.eql(u8, flag.name, arg)) {
                    flag.is = true;
                }
            }
        }
    }

    pub fn parse2(self: *CLI) !void {
        var i: usize = 1;

        while (i < self.argv.len) : (i += 1) {
            const arg = self.argv[i];

            if (!std.mem.startsWith(u8, arg, "--")) {
                continue;
            }
            const name = arg;

            for (self.flags.items) |*flag| {
                if (!std.mem.eql(u8, flag.name, name)) {
                    continue;
                }
                if (flag.isBoolFlag) {
                    flag.is = true;
                    break;
                }
                if (flag.isValueFlag) {
                    if (i + 1 >= self.argv.len) {
                        return error.MissingFlagValue;
                    }
                    i += 1;
                    flag.is = true;
                    flag.value = self.argv[i];
                    break;
                }
            }
        }
    }

    pub fn generateHelpText(self: *CLI) ![]u8 {
        var text = try std.fmt.allocPrint(self.allocator, "Flags:\n", .{});
        errdefer self.allocator.free(text);

        for (self.flags.items) |flag| {
            const line = try std.fmt.allocPrint(self.allocator, "  {s} {s}\n", .{ flag.name, flag.description });
            defer self.allocator.free(line);

            const joined = try std.mem.concat(self.allocator, u8, &[_][]const u8{ text, line });
            self.allocator.free(text);
            text = joined;
        }
        return text;
    }
};
