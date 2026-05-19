const std = @import("std");
const models = @import("models.zig");
const parse = @import("parse.zig");

pub fn main(init: std.process.Init) !void {
    var gpa = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    const arg_data = try getArgs(init);

    if (arg_data.file_path == null) {
        return;
    }

    defer _ = gpa.deinit();

    const cwd = std.Io.Dir.cwd();
    const io = init.io;
    const file = try cwd.openFile(io, arg_data.file_path.?, .{});
    defer file.close(io);

    const file_size = try file.length(io);
    const buffer = try std.Io.Dir.readFileAlloc(cwd, io, arg_data.file_path.?, allocator, .unlimited);
    //const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    var iter = std.mem.splitSequence(u8, buffer, "\n");
    var version_data = models.AllVersionData{ .current_version = null, .pulled_version = null };

    while (iter.next()) |line| {
        if (try parse.parseVersionLine(line, &iter, "<<<<<<< HEAD", allocator)) |version| {
            version_data.current_version = version;
        }

        if (try parse.parseVersionLine(line, &iter, "=======", allocator)) |version| {
            version_data.pulled_version = version;
        }
    }

    if (version_data.current_version == null) {
        std.debug.print("Critical error: The diff text \"<<<<<<< HEAD\" could not be found.\n", .{});
        return error.DiffTextNotFound;
    }

    if (version_data.pulled_version == null) {
        std.debug.print("Critical error: The diff text \"=======\" could not be found.\n", .{});
        return error.DiffTextNotFound;
    }

    try updateFile(parse.getFinalVersion(version_data, arg_data.resolution_method orelse models.VersionResolutionMethod.generate_next), allocator, io, cwd, buffer, file_size);
}

fn getArgs(init: std.process.Init) !models.ArgData {
    var args = init.minimal.args.iterate();
    var arg_data = models.ArgData{ .file_path = null, .resolution_method = null };

    // The first argument is always the executable path
    _ = args.next();
    const possible_file_path = args.next();

    if (possible_file_path) |file_path| {
        if (std.mem.eql(u8, file_path, "-h")) {
            printHelpText();
        } else {
            arg_data.file_path = file_path;
        }
    } else {
        printHelpText();
    }

    // Loop through the remaining arguments
    while (args.next()) |arg| {
        std.debug.print("Argument: {s}\n", .{arg});

        if (std.mem.eql(u8, arg, "-l")) {
            arg_data.resolution_method = models.VersionResolutionMethod.use_latest;
        } else if (std.mem.eql(u8, arg, "-n")) {
            arg_data.resolution_method = models.VersionResolutionMethod.generate_next;
        }
    }

    return arg_data;
}

fn printHelpText() void {
    std.debug.print("Please provide a file path to the version file.\n\nAvailable Arguments:\n-l:\tUse the greater of the 2 versions in the conflict.\n-n:\tFind the later version, and apply the version upgrade from the smaller version to create the new latest version.", .{});
}

fn updateFile(new_version: models.VersionDetails, allocator: std.mem.Allocator, io: std.Io, cwd: std.Io.Dir, buffer: []const u8, file_size: u64) !void {
    const start_of_diff = std.mem.indexOf(u8, buffer, "<").?;
    const end_of_diff = std.mem.indexOf(u8, buffer, ">").?;
    const true_end_of_diff = std.mem.indexOf(u8, buffer[end_of_diff..file_size], "\n").?;

    const new_version_str = try std.fmt.allocPrint(allocator, "\t\"version\": \"{d}.{d}.{d}\",\n", .{ new_version.major, new_version.minor, new_version.patch });
    defer allocator.free(new_version_str);

    const collapsed_output = try std.mem.concat(allocator, u8, &[_][]const u8{ buffer[0..start_of_diff], new_version_str, buffer[true_end_of_diff + end_of_diff + 1 .. file_size] });
    defer allocator.free(collapsed_output);

    const write_file = try cwd.createFile(io, "sandbox.json", .{ .truncate = true });
    defer write_file.close(io);

    //try write_file.writeAll(collapsed_output);
    try write_file.writeStreamingAll(io, collapsed_output);
}
