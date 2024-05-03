const std = @import("std");

const File = std.fs.File;
const Allocator = std.mem.Allocator;

/// Opens file in user's home directory and creates it if it doesn't exist.
/// `file_name` is expected to be absolute.
/// Caller must call `File.close()` to release the resource.
pub fn openFileAbsolute(file_name: []const u8) !File {
    return std.fs.openFileAbsolute(file_name, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return std.fs.createFileAbsolute(file_name, .{ .read = true }) catch unreachable;
        }

        return err;
    };
}

/// Reads file and returns conf variables
/// `file` is expected to be absolute.
/// Caller must free returned memory
pub fn readFileVars(allocator: Allocator, file: File) ![]const u8 {
    const reader = file.reader();
    const buff = try reader.readUntilDelimiterOrEofAlloc(
        allocator,
        '\n',
        std.math.maxInt(usize),
    );

    var conf_vars: []u8 = undefined;
    if (buff) |val| {
        conf_vars = allocator.alloc(u8, val.len) catch unreachable;
        for (val) |c| {
            if (c == '\n') break;
        }
    }

    return conf_vars;
}
