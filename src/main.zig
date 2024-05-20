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

    if (has_session.term.Exited == 1) {
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
    }

    _ = try std.ChildProcess.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "tmux",
            "switch-client",
            "-t",
            @ptrCast(name),
        },
    });
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
    defer vx.deinit(allocator);

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

    var temp_dirs = std.ArrayList([]const u8).init(allocator);

    temp_dirs.appendSlice(dirs.items) catch unreachable;

    var text: []const u8 = allocator.alloc(u8, 512) catch unreachable;

    while (true) {
        const event = loop.nextEvent();

        switch (event) {
            .key_press => |key| {
                if (key.matches(vaxis.Key.enter, .{})) {
                    try tmuxHandle(allocator, dirs.items[selected_dir]);
                    text_input.clearAndFree();
                    break;
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
                } else {
                    try text_input.update(.{ .key_press = key });

                    text = text_input.buf.items;

                    temp_dirs.clearRetainingCapacity();
                    if (text.len == 0) {
                        temp_dirs.appendSlice(dirs.items) catch unreachable;
                    } else {
                        for (dirs.items) |opt| {
                            const base = toLowerAll(
                                allocator,
                                std.fs.path.basename(opt),
                            );
                            const lower_text = toLowerAll(allocator, text);
                            if (std.mem.indexOf(u8, base, lower_text) != null) {
                                temp_dirs.append(opt) catch unreachable;
                            }
                        }
                    }
                }
            },
            .winsize => |ws| {
                try vx.resize(allocator, ws);
            },
            else => unreachable,
        }

        const win = vx.window();
        win.clear();

        const child = win.child(.{
            .x_off = 2,
            .y_off = temp_dirs.items.len + 2,
        });

        text_input.draw(child);

        win.hideCursor();
        for (temp_dirs.items, 0..) |opt, j| {
            var seg = [_]vaxis.Segment{.{
                .text = opt,
                .style = if (j == selected_dir) .{ .reverse = true } else .{},
            }};
            _ = try win.print(&seg, .{ .row_offset = j + 1 });
        }

        _ = try win.print(
            &[_]vaxis.Segment{.{ .text = ">", .style = .{ .reverse = true } }},
            .{ .row_offset = temp_dirs.items.len + 2 },
        );

        try vx.render();
    }
}

fn toLowerAll(allocator: std.mem.Allocator, str: []const u8) []const u8 {
    if (str.len == 0) return str;

    var n_str = allocator.dupe(u8, str) catch unreachable;
    var i: usize = 0;
    while (i < n_str.len) : (i += 1) {
        n_str[i] = std.ascii.toLower(n_str[i]);
    }

    return n_str;
}

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    foo: u8,
};
