const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn openDirsAbsolute(allocator: Allocator, dirs: []const []const u8) !ArrayList([]const u8) {
    var dir_list = ArrayList([]const u8).init(allocator);
    for (dirs) |dir| {
        dir_list.append(try allocator.dupe(u8, dir)) catch unreachable;
    }

    return dir_list;
}
