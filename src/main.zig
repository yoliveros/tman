const std = @import("std");
const ch = @import("ConfHandler.zig");

const log = std.log.scoped(.tman);

const conf_file = "tman.conf";

pub fn main() !void {
    //args
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);

    const conf_path = try std.fs.path.join(allocator, &[_][]const u8{ home, conf_file });
    defer allocator.free(conf_path);

    var file = try ch.openFileAbsolute(conf_path);
    defer file.close();

    const buf = try ch.readFileVars(allocator, file);
    defer allocator.free(buf);

    log.info("conf vars: {s}", .{buf});
}
