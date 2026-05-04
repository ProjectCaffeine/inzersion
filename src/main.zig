const std = @import("std");
const json_data = @embedFile("testconflictversioninfo.json");

const AllVersionData = struct {
    current_version: VersionDetails,
    pulled_version: VersionDetails,
};

const VersionDetails = struct {
    major: u16,
    minor: u16,
    patch: u16,

    pub fn init(major: u16, minor: u16, patch: u16) VersionDetails {
        return VersionDetails{ .major = major, .minor = minor, .patch = patch };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    var iter = std.mem.splitSequence(u8, json_data, "\n");
    var version_data = AllVersionData{ .current_version = undefined, .pulled_version = undefined };
    defer _ = gpa.deinit();
    //defer version_data.deinit(allocator);

    while (iter.next()) |line| {
        std.debug.print("{s}\n", .{line});

        if (try parseVersionLine(line, &iter, "<<<<<<< HEAD", allocator)) |version| {
            version_data.current_version = version;
        }

        if (try parseVersionLine(line, &iter, "=======", allocator)) |version| {
            version_data.pulled_version = version;
        }
    }

    std.debug.print("Current Version:\n{d}.{d}.{d}\n", .{ version_data.current_version.major, version_data.current_version.minor, version_data.current_version.patch });
    std.debug.print("New Version:\n{d}.{d}.{d}\n", .{ version_data.pulled_version.major, version_data.pulled_version.minor, version_data.pulled_version.patch });
}

fn parseVersionLine(line: []const u8, iter: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence), str_text: []const u8, allocator: std.mem.Allocator) !?VersionDetails {
    if (std.mem.eql(u8, line, str_text)) {
        if (iter.*.next()) |val| {
            return try parseOutVersionNumber(val, allocator);
        }
    }

    return null;
}

fn parseOutVersionNumber(line: []const u8, allocator: std.mem.Allocator) error{ InvalidCharacter, Overflow, OutOfMemory }!VersionDetails {
    var split = std.mem.splitBackwardsSequence(u8, line, ":");
    const captured_string = split.next();
    var version_string: []u8 = try allocator.alloc(u8, 16);
    var version_numbers: []u16 = try allocator.alloc(u16, 3);

    defer allocator.free(version_string);
    defer allocator.free(version_numbers);

    var version_length: usize = 0;
    var versions_parsed: usize = 0;

    if (captured_string) |str| {
        for (str, 0..) |char, i| {
            _ = i;

            if (std.ascii.isDigit(char)) {
                version_string[version_length] = char;
                version_length += 1;
            } else if (char == '.') {
                std.debug.print("Parsing number:\n{s}\n", .{version_string[0..version_length]});
                version_numbers[versions_parsed] = try std.fmt.parseUnsigned(u16, version_string[0..version_length], 10);
                versions_parsed += 1;

                @memset(version_string, 0);
                version_length = 0;
            }
        }

        std.debug.print("Parsing number:\n{s}\n", .{version_string[0..version_length]});
        version_numbers[versions_parsed] = try std.fmt.parseUnsigned(u16, version_string[0..version_length], 10);
    }

    return VersionDetails.init(version_numbers[0], version_numbers[1], version_numbers[2]);
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
