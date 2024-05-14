const std = @import("std");
const ch = @import("ConfHandler.zig");
const dh = @import("DirHandler.zig");

const vaxis = @import("vaxis");

const Cell = vaxis.Cell;
const TextInput = vaxis.widgets.TextInput;

const log = std.log.scoped(.tman);

const conf_file = ".tman.conf";

fn tmuxHandle(allocator: std.mem.Allocator, path: []const u8) !void {
    const name = std.fs.path.basename(path);

    const has_session = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "tmux",
            "has-session",
            "-t",
            @ptrCast(name),
        },
    });

    if (has_session.term.Exited == 0) {
        _ = try std.ChildProcess.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "tmux",
                "switch-client",
                "-t",
                @ptrCast(name),
            },
        });

        return;
    } else {
        _ = try std.ChildProcess.run(.{
            .allocator = allocator,
            .argv = &[_][]const u8{
                "tmux",
                "new-session",
                "-ds",
                @ptrCast(name),
                "-c",
                @ptrCast(path),
            },
        });

        return;
    }
}

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

    var vx = try vaxis.init(allocator, .{});

    var loop: vaxis.Loop(Event) = .{ .vaxis = &vx };

    try loop.run();
    defer loop.stop();

    try vx.queryTerminal();

    var text_input = TextInput.init(allocator, &vx.unicode);
    defer text_input.deinit();

    var selected_dir: usize = 0;

    var dirs = std.ArrayList([]const u8).init(allocator);

    if (buf.items.len > 0) {
        dirs = try dh.openDirsAbsolute(allocator, buf.items, home);
    } else {
        try dirs.append(try allocator.dupe(u8, home));
    }

    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                if (key.matches(vaxis.Key.enter, .{})) {
                    try tmuxHandle(allocator, dirs.items[selected_dir]);
                } else if (key.matches(vaxis.Key.down, .{}) and
                    selected_dir < dirs.items.len - 1)
                {
                    selected_dir += 1;
                } else if (key.matches(vaxis.Key.up, .{}) and
                    selected_dir > 0)
                {
                    selected_dir -= 1;
                } else if (key.codepoint == 'c' and key.mods.ctrl or
                    key.matches(vaxis.Key.escape, .{}))
                {
                    break;
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

        win.hideCursor();
        for (dirs.items, 0..) |opt, j| {
            var seg = [_]vaxis.Segment{.{
                .text = opt,
                .style = if (j == selected_dir) .{ .reverse = true } else .{},
            }};
            _ = try win.print(&seg, .{ .row_offset = j + 1 });
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
