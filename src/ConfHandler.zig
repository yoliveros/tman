const std = @import("std");

const File = std.fs.File;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

/// Opens file in user's home directory and creates it if it doesn't exist.
/// `file_name` is expected to be absolute.
/// Caller must call `File.close()` to release the resource.
pub fn openFileAbsolute(file_name: []const u8) !File {
    return std.fs.openFileAbsolute(file_name, .{}) catch |err| {
        if (err == error.FileNotFound) {
            const file = std.fs.createFileAbsolute(file_name, .{ .read = true }) catch unreachable;

            try file.writeAll(
                \\# Tmux Manager config file
                \\#
                \\# routes: route1 route2
                \\#
                \\# routes must be folders in user's home directory
                \\#
                \\# if empty, all folders in user's home directory will be scanned
                \\
                \\routes:
            );

            return file;
        }

        return err;
    };
}

/// Reads file and returns conf variables
/// `allocator` is expected to be arena allocator
/// `file` is expected to be absolute.
/// Caller must free returned memory
pub fn readFileVars(allocator: Allocator, file: File) !ArrayList([]const u8) {
    const file_size = try file.getEndPos();

    if (file_size == 0) return std.ArrayList([]const u8).init(allocator);

    const reader = file.reader();
    const buff: []const u8 = try reader.readAllAlloc(allocator, file_size);
    var buff_lines = std.mem.splitSequence(u8, buff, "\n");

    var conf_vars = std.ArrayList([]const u8).init(allocator);

    while (buff_lines.next()) |val| {
        if (std.mem.startsWith(u8, val, "#")) continue;

        if (val.len == 0) continue;

        if (std.mem.startsWith(u8, val, "routes:")) {
            var routes = std.mem.splitSequence(u8, val, " ");
            _ = routes.next();

            while (routes.next()) |route| {
                if (route.len == 0) continue;

                conf_vars.append(route) catch unreachable;
            }
        }
    }

    return conf_vars;
}
