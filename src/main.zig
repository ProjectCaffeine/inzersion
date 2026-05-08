const std = @import("std");
const json_data = @embedFile("testconflictversioninfo.json");
const models = @import("models.zig");
const parse = @import("parse.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const cwd = std.fs.cwd();
    const file = try cwd.openFile("sandbox2.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var iter = std.mem.splitSequence(u8, buffer, "\n");
    var version_data = models.AllVersionData{ .current_version = undefined, .pulled_version = undefined };

    printArgs();

    while (iter.next()) |line| {
        //std.debug.print("{s}\n", .{line});

        if (try parse.parseVersionLine(line, &iter, "<<<<<<< HEAD", allocator)) |version| {
            version_data.current_version = version;
        }

        if (try parse.parseVersionLine(line, &iter, "=======", allocator)) |version| {
            version_data.pulled_version = version;
        }
    }

    try updateFile(parse.getFinalVersion(version_data, models.VersionResolutionMethod.generate_next), allocator, cwd, buffer, file_size);
}

fn printArgs() void {
    var args = std.process.args();

    // The first argument is always the executable path
    const exe_name = args.next() orelse "unknown";
    std.debug.print("Executable name: {s}\n", .{exe_name});

    // Loop through the remaining arguments
    while (args.next()) |arg| {
        std.debug.print("Argument: {s}\n", .{arg});
    }
}

fn updateFile(new_version: models.VersionDetails, allocator: std.mem.Allocator, cwd: std.fs.Dir, buffer: []const u8, file_size: u64) !void {
    const start_of_diff = std.mem.indexOf(u8, buffer, "<").?;
    const end_of_diff = std.mem.indexOf(u8, buffer, ">").?;
    const true_end_of_diff = std.mem.indexOf(u8, buffer[end_of_diff..file_size], "\n").?;

    const new_version_str = try std.fmt.allocPrint(allocator, "\t\"version\": \"{d}.{d}.{d}\",\n", .{ new_version.major, new_version.minor, new_version.patch });
    defer allocator.free(new_version_str);

    const collapsed_output = try std.mem.concat(allocator, u8, &[_][]const u8{ buffer[0..start_of_diff], new_version_str, buffer[true_end_of_diff + end_of_diff + 1 .. file_size] });
    defer allocator.free(collapsed_output);

    const write_file = try cwd.createFile("sandbox.json", .{ .truncate = true });
    defer write_file.close();

    try write_file.writeAll(collapsed_output);
}
