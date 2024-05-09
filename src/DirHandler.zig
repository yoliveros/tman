const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn openDirsAbsolute(allocator: Allocator, dirs: []const []const u8, home: []const u8) !ArrayList([]const u8) {
    var dir_list = ArrayList([]const u8).init(allocator);
    for (dirs) |dir| {
        if (std.mem.eql(u8, dir, "/")) continue;

        const path = try std.fs.path.join(allocator, &[_][]const u8{ home, dir });

        var absolute_dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
        defer absolute_dir.close();

        var walker = absolute_dir.walk(allocator) catch unreachable;

        while (try walker.next()) |entry| {
            dir_list.append(try allocator.dupe(u8, entry.basename)) catch unreachable;
        }
    }

    return dir_list;
}
