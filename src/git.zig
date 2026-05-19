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

pub fn isRepo(allocator: std.mem.Allocator) !bool {
    const args = &[_][]const u8{ "git", "rev-parse", "--is-inside-work-tree", ">", "/dev/null", "2>&1" };
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = args,
    });

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
}
