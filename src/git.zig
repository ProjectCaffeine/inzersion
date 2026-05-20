const std = @import("std");

pub fn getRepoDir(allocator: std.mem.Allocator) !std.fs.Dir {
    const args = &[_][]const u8{ "git", "rev-parse", "--show-toplevel" };
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    std.fs.openDirAbsolute(result.stdout, .{ .access_sub_paths = true });
}

pub fn getVersionFiles(allocator: std.mem.Allocator) !void {
    const args = &[_][]const u8{ "git", "diff", "--name-only", "--diff-filter=U" };
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
}

pub fn isRepo(allocator: std.mem.Allocator, io: std.Io) !bool {
    const args = &[_][]const u8{ "git", "rev-parse", "--is-inside-work-tree" };
    const result = try std.process.run(allocator, io, .{
        .argv = args,
    });

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    return result.term.exited == 0;
}

fn parseTerm(term: std.process.Child.Term) void {
    switch (term) {
        .exited => |code| std.debug.print("Process exited with code: {d}\n", .{code}),
        .signal => |sig| std.debug.print("Process terminated by signal: {d}\n", .{sig}),
        .stopped => |sig| std.debug.print("Process stopped by signal: {d}\n", .{sig}),
        .unknown => |code| std.debug.print("Process terminated for unknown reason: {d}\n", .{code}),
    }
}
