const std = @import("std");
const ch = @import("ConfHandler.zig");
const dh = @import("DirHandler.zig");

const vaxis = @import("vaxis");

const Cell = vaxis.Cell;
const TextInput = vaxis.widgets.TextInput;

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
        _ = try dh.openDirsAbsolute(allocator, buf.items, home);
    }

    var vx = try vaxis.init(allocator, .{});

    var loop: vaxis.Loop(Event) = .{ .vaxis = &vx };

    try loop.run();
    defer loop.stop();

    try vx.queryTerminal();

    var text_input = TextInput.init(allocator, &vx.unicode);
    defer text_input.deinit();

    var selected_dir: ?usize = null;

    var dirs = std.ArrayList([]const u8).init(allocator);

    if (buf.items.len > 0) {
        for (buf.items) |opt| {
            try dirs.append(opt);
        }
    } else {
        try dirs.append(try allocator.dupe(u8, home));
    }

    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                if (key.codepoint == 'c' and key.mods.ctrl) {
                    break;
                } else if (key.matches(vaxis.Key.tab, .{})) {
                    if (selected_dir == null) {
                        selected_dir = 0;
                    } else {
                        selected_dir.? = @min(dirs.items.len - 1, selected_dir.? + 1);
                    }
                } else if (key.matches(vaxis.Key.tab, .{ .shift = true })) {
                    if (selected_dir == null) {
                        selected_dir = 0;
                    } else {
                        selected_dir.? = selected_dir.? -| 1;
                    }
                } else if (key.matches(vaxis.Key.enter, .{})) {
                    if (selected_dir) |i| {
                        // log.err("enter", .{});
                        try text_input.insertSliceAtCursor(dirs.items[i]);
                        selected_dir = null;
                    }
                } else {
                    if (selected_dir == null)
                        try text_input.update(.{ .key_press = key });
                }
            },
            .winsize => |ws| {
                try vx.resize(allocator, ws);
            },
            else => {},
        }

        const win = vx.window();
        win.clear();

        text_input.draw(win);

        if (selected_dir) |i| {
            win.hideCursor();
            for (dirs.items, 0..) |opt, j| {
                // log.err("i = {d}, j = {d}, opt = {s}", .{ i, j, opt });
                var seg = [_]vaxis.Segment{.{
                    .text = opt,
                    .style = if (j == i) .{ .reverse = true } else .{},
                }};
                _ = try win.print(&seg, .{ .row_offset = j + 1 });
            }
        }

        try vx.render();
    }
}

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    foo: u8,
};
