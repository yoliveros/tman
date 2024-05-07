const std = @import("std");
const ch = @import("ConfHandler.zig");
const dh = @import("DirHandler.zig");

const log = std.log.scoped(.tman);

const conf_file = ".tman.conf";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const home = try std.process.getEnvVarOwned(allocator, "HOME");

    const conf_path = try std.fs.path.join(allocator, &[_][]const u8{ home, conf_file });

    var file = try ch.openFileAbsolute(conf_path);
    defer file.close();

    const buf = try ch.readFileVars(allocator, file);

    if (buf.items.len > 0) {
        _ = try dh.openDirsAbsolute(allocator, buf.items);
    }

    _ = try dh.openDirsAbsolute(allocator, &[_][]const u8{home});
}
