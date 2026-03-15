// const std = @import("std");
// const pkgregistryconfig = @import("registryconfig.zig");

// pub fn startPrompt(allocator: std.mem.Allocator) !void {
//     const name = try askName(allocator);
//     if (std.mem.eql(u8, name, "")) {
//         return;
//     }
//     const path = try askPath(allocator);
//     if (std.mem.eql(u8, path, "")) {
//         return;
//     }
//     var config = try pkgregistryconfig.get(allocator);
//     if (config.paths.getPtr(name)) |current| {
//         allocator.free(current.path);
//         current.path = path;
//         defer allocator.free(name);
//     } else {
//         try config.paths.put(name, .{ .path = path, .command = null });
//     }
//     defer config.deinit();
//     try pkgregistryconfig.write(allocator, config);
// }

// fn askName(allocator: std.mem.Allocator) ![]u8 {
//     const stdin = std.fs.File.stdin();
//     std.debug.print("? Name: ", .{});

//     var buf: [100]u8 = undefined;
//     var idx: usize = 0;

//     while (idx < buf.len) {
//         var b: [1]u8 = undefined;
//         const n = try stdin.read(&b);
//         if (n == 0 or b[0] == '\n') {
//             break;
//         }
//         buf[idx] = b[0];
//         idx += 1;
//     }
//     if (idx == 0) {
//         return "";
//     }
//     return try allocator.dupe(u8, buf[0..idx]);
// }

// fn askPath(allocator: std.mem.Allocator) ![]u8 {
//     const stdin = std.fs.File.stdin();
//     std.debug.print("? Path: ", .{});

//     var buf: [100]u8 = undefined;
//     var idx: usize = 0;

//     while (idx < buf.len) {
//         var b: [1]u8 = undefined;
//         const n = try stdin.read(&b);
//         if (n == 0 or b[0] == '\n') {
//             break;
//         }
//         buf[idx] = b[0];
//         idx += 1;
//     }
//     if (idx == 0) {
//         return "";
//     }
//     return try allocator.dupe(u8, buf[0..idx]);
// }
