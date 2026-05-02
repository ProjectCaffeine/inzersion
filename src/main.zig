const std = @import("std");
const json_data = @embedFile("testconflictversioninfo.json");

const AllVersionData = struct {
    current_version: []const u8,
    pulled_version: []const u8,

    pub fn deinit(self: AllVersionData, allocator: std.mem.Allocator) void {
        allocator.free(self.current_version);
        allocator.free(self.pulled_version);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    var iter = std.mem.splitSequence(u8, json_data, "\n");
    var version_data = AllVersionData{ .current_version = undefined, .pulled_version = undefined };
    defer _ = gpa.deinit();
    defer version_data.deinit(allocator);

    while (iter.next()) |line| {
        std.debug.print("{s}\n", .{line});

        if (try parseVersionLine(line, &iter, "<<<<<<< HEAD", allocator)) |version| {
            version_data.current_version = version;
        }

        if (try parseVersionLine(line, &iter, "=======", allocator)) |version| {
            version_data.pulled_version = version;
        }
    }

    std.debug.print("Current Version:\n{s}\n", .{version_data.current_version});
    std.debug.print("New Version:\n{s}", .{version_data.pulled_version});
}

fn parseVersionLine(line: []const u8, iter: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence), str_text: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    if (std.mem.eql(u8, line, str_text)) {
        if (iter.*.next()) |val| {
            return try parseOutVersionNumber(val, allocator);
        }
    }

    return null;
}

fn parseOutVersionNumber(line: []const u8, allocator: std.mem.Allocator) error{OutOfMemory}![]const u8 {
    var split = std.mem.splitBackwardsSequence(u8, line, ":");
    const captured_string = split.next();
    var version_string: []u8 = try allocator.alloc(u8, 32);
    var version_length: usize = 0;

    if (captured_string) |str| {
        for (str, 0..) |char, i| {
            _ = i;

            if (std.ascii.isDigit(char) or char == '.') {
                version_string[version_length] = char;
                version_length += 1;
            }
        }
    }

    version_string[version_length] = 0;
    return version_string;
}

fn readFile(allocator: std.mem.Allocator) void {
    const file = std.fs.cwd().openFile("testconflictversioninfo.json", .{}) catch |err| {
        std.log.err("Failed to open file: {s}", .{@errorName(err)});
        return;
    };

    defer file.close();

    std.debug.print("File read!", .{});

    const content = try file.readToEndAlloc(allocator, 128);

    _ = content;
}
