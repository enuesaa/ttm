const std = @import("std");

pub const Flag = struct {
    name: []const u8,
    alias: ?[]const u8 = null,
    description: []const u8,
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
    name: []const u8,
    description: []const u8,
    usage: []const u8 = "",
    flags: std.ArrayList(*Flag),
    positionals: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, description: []const u8) CLI {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .name = name,
            .description = description,
            .flags = .{},
            .positionals = .{},
        };
    }

    pub fn deinit(self: *CLI) void {
        const allocator = self.arena.allocator();
        self.flags.deinit(allocator);
        self.positionals.deinit(allocator);
        self.arena.deinit();
    }

    pub fn flagBool(self: *CLI, name: []const u8, description: []const u8) !*Flag {
        const allocator = self.arena.allocator();
        const flag = try allocator.create(Flag);
        flag.* = .{
            .name = name,
            .description = description,
            .isBoolFlag = true,
        };
        try self.flags.append(allocator, flag);
        return flag;
    }

    pub fn flagValue(self: *CLI, name: []const u8, description: []const u8) !*Flag {
        const allocator = self.arena.allocator();
        const flag = try allocator.create(Flag);
        flag.* = .{
            .name = name,
            .description = description,
            .isValueFlag = true,
        };
        try self.flags.append(allocator, flag);
        return flag;
    }

    pub fn parse(self: *CLI, argv: [][:0]u8) ?ParseErr {
        const allocator = self.arena.allocator();
        var i: usize = 1;

        while (i < argv.len) : (i += 1) {
            const arg = argv[i];

            if (!std.mem.startsWith(u8, arg, "-")) {
                self.positionals.append(allocator, arg) catch {
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
            if (flag.alias != null and std.mem.eql(u8, flag.alias.?, name)) {
                return flag;
            }
        }
        return error.FlagNotFound;
    }

    pub fn generateHelpText(self: *CLI) ![]u8 {
        const allocator = self.arena.allocator();
        var buf: std.ArrayList(u8) = .{};
        const writer = buf.writer(allocator);

        try writer.print("{s}\n", .{self.name});
        try writer.print("{s}\n", .{self.description});
        try writer.print("\n", .{});
        try writer.print("Usage:\n", .{});
        try writer.print("  {s}\n", .{self.usage});

        if (self.flags.items.len > 0) {
            try writer.print("\n", .{});
            try writer.print("Flags:\n", .{});
            for (self.flags.items) |flag| {
                if (flag.alias != null) {
                    try writer.print("  {s}, {s}\t{s}\n", .{ flag.alias.?, flag.name, flag.description });
                } else {
                    try writer.print("  {s}\t{s}\n", .{ flag.name, flag.description });
                }
            }
        }
        return buf.toOwnedSlice(allocator);
    }
};
