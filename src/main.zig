const std = @import("std");

const log = std.log.scoped(.tman);

const conf_file = "~/.tman.conf";

pub fn main() !void {
    //args
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var file = try std.fs.createFileAbsolute("/home/yoliveros/.tman.conf", .{ .read = true });
    defer file.close();

    const buf = try file.reader().readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(buf);

    log.info("Using config file at {s}\n", .{buf});
}
