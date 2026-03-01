const std = @import("std");

pub const Flag = struct {
    name: []const u8,
    description: []const u8 = "",
    isBoolFlag: bool = false,
    isValueFlag: bool = false,
    is: bool = false,
    value: ?[]const u8 = null,
};

pub const ParseErr = struct {
    name: []const u8 = "",
    arg: []const u8 = "",
};

pub const CLI = struct {
    arena: std.heap.ArenaAllocator,
    description: []const u8 = "",
    usage: []const u8 = "",
    flags: std.array_list.Managed(*Flag),
    positionals: std.array_list.Managed([]const u8),

    pub fn init(allocator: std.mem.Allocator) CLI {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .flags = std.array_list.Managed(*Flag).init(allocator),
            .positionals = std.array_list.Managed([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *CLI) void {
        self.flags.deinit();
        self.positionals.deinit();
        self.arena.deinit();
    }

    pub fn flagBool(self: *CLI, name: []const u8) !*Flag {
        const flag = try self.arena.allocator().create(Flag);
        flag.* = .{
            .name = name,
            .isBoolFlag = true,
        };
        try self.flags.append(flag);
        return flag;
    }

    pub fn flagValue(self: *CLI, name: []const u8) !*Flag {
        const flag = try self.arena.allocator().create(Flag);
        flag.* = .{
            .name = name,
            .isValueFlag = true,
        };
        try self.flags.append(flag);
        return flag;
    }

    pub fn parse(self: *CLI, argv: [][:0]u8) ?ParseErr {
        var i: usize = 1;

        while (i < argv.len) : (i += 1) {
            const arg = argv[i];

            if (!std.mem.startsWith(u8, arg, "-")) {
                self.positionals.append(arg) catch {
                    return ParseErr{ .arg = arg, .name = "internal error" };
                };
                continue;
            }
            const flag = self.lookupFlag(arg) catch {
                return ParseErr{ .arg = arg, .name = "flag not found" };
            };
            if (flag.isBoolFlag) {
                flag.is = true;
                continue;
            }
            if (flag.isValueFlag) {
                if (i + 1 >= argv.len) {
                    return ParseErr{ .arg = arg, .name = "missing flag value" };
                }
                i += 1;
                flag.value = argv[i];
                flag.is = true;
            }
        }
        return null;
    }

    fn lookupFlag(self: *CLI, name: []const u8) !*Flag {
        for (self.flags.items) |flag| {
            if (std.mem.eql(u8, flag.name, name)) {
                return flag;
            }
        }
        return error.FlagNotFound;
    }

    pub fn generateHelpText(self: *CLI) ![]u8 {
        const allocator = self.arena.allocator();
        var text = try std.fmt.allocPrint(allocator, "{s}\n\nUsage:\n  {s}\n", .{ self.description, self.usage });

        if (self.flags.items.len > 0) {
            const flagsHeader = try std.fmt.allocPrint(allocator, "\nFlags:\n", .{});
            text = try std.mem.concat(allocator, u8, &[_][]const u8{ text, flagsHeader });

            for (self.flags.items) |flag| {
                const flagLine = try std.fmt.allocPrint(allocator, "  {s}\t{s}\n", .{ flag.name, flag.description });
                text = try std.mem.concat(allocator, u8, &[_][]const u8{ text, flagLine });
            }
        }
        return text;
    }
};
