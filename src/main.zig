const std = @import("std");
const json_data = @embedFile("testconflictversioninfo.json");

const AllVersionData = struct {
    current_version: VersionDetails,
    pulled_version: VersionDetails,
};

const VersionNumberType = enum { major, minor, patch };

const VersionResolutionMethod = enum { use_latest, generate_next };

const VersionDetails = struct {
    major: u16,
    minor: u16,
    patch: u16,
    most_recent_update: VersionNumberType,

    pub fn init(major: u16, minor: u16, patch: u16) VersionDetails {
        var most_recent_update: VersionNumberType = undefined;

        if (minor == 0 and patch == 0) {
            most_recent_update = VersionNumberType.major;
        } else if (patch == 0) {
            most_recent_update = VersionNumberType.minor;
        } else {
            most_recent_update = VersionNumberType.patch;
        }

        return VersionDetails{ .major = major, .minor = minor, .patch = patch, .most_recent_update = most_recent_update };
    }

    pub fn equals(self: *VersionDetails, other: VersionDetails) bool {
        return self.major == other.major and self.minor == other.minor and self.patch == other.patch;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const allocator = gpa.allocator();
    var iter = std.mem.splitSequence(u8, json_data, "\n");
    var version_data = AllVersionData{ .current_version = undefined, .pulled_version = undefined };
    defer _ = gpa.deinit();

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
    std.debug.print("Pulled Version:\n{d}.{d}.{d}\n", .{ version_data.pulled_version.major, version_data.pulled_version.minor, version_data.pulled_version.patch });

    const final_version = getFinalVersion(version_data, VersionResolutionMethod.generate_next);
    std.debug.print("Final Version:\n{d}.{d}.{d}\n", .{ final_version.major, final_version.minor, final_version.patch });

    try updateFile(final_version, allocator);
}

fn updateFile(new_version: VersionDetails, allocator: std.mem.Allocator) !void {
    const cwd = std.fs.cwd();
    const file = try cwd.openFile("sandbox2.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try file.readToEndAlloc(allocator, file_size);
    defer allocator.free(buffer);

    const out_buffer = try allocator.alloc(u8, file_size + 1);
    defer allocator.free(out_buffer);

    const start_of_diff = std.mem.indexOf(u8, buffer, "<").?;
    const end_of_diff = std.mem.indexOf(u8, buffer, ">").?;

    const true_end_of_diff = std.mem.indexOf(u8, buffer[end_of_diff..file_size], "\n").?;

    std.debug.print("Start of diff: {d}\nEnd: {d}\nTrue end: {d}\n", .{ start_of_diff, end_of_diff, true_end_of_diff });

    const collapsed_output = try std.mem.concat(allocator, u8, &[_][]const u8{ buffer[0..start_of_diff], buffer[true_end_of_diff + end_of_diff + 1 .. file_size] });

    defer allocator.free(collapsed_output);

    //_ = std.mem.replace(u8, buffer, "<<<<<<< HEAD\n", "", out_buffer);
    //_ = std.mem.replace(u8, out_buffer, ">>>>>>> feat1\n", "", out_buffer);

    const write_file = try cwd.createFile("sandbox.json", .{ .truncate = true });
    defer write_file.close();
    try write_file.writeAll(collapsed_output);

    _ = new_version;
}

fn getFinalVersion(version_data: AllVersionData, resolution_method: VersionResolutionMethod) VersionDetails {
    var latest_version: VersionDetails = undefined;

    if (version_data.current_version.major != version_data.pulled_version.major) {
        latest_version = if (version_data.current_version.major > version_data.pulled_version.major) version_data.current_version else version_data.pulled_version;
    } else if (version_data.current_version.minor != version_data.pulled_version.minor) {
        latest_version = if (version_data.current_version.minor > version_data.pulled_version.minor) version_data.current_version else version_data.pulled_version;
    } else if (version_data.current_version.patch != version_data.pulled_version.patch) {
        latest_version = if (version_data.current_version.patch > version_data.pulled_version.patch) version_data.current_version else version_data.pulled_version;
    }

    std.debug.print("Latest version is current:\n{any}\n", .{latest_version.equals(version_data.current_version)});
    std.debug.print("Latest version is pulled:\n{any}\n", .{latest_version.equals(version_data.pulled_version)});

    if (resolution_method == VersionResolutionMethod.use_latest) {
        return latest_version;
    }

    switch (if (latest_version.equals(version_data.current_version)) version_data.pulled_version.most_recent_update else version_data.current_version.most_recent_update) {
        VersionNumberType.major => {
            return VersionDetails.init(latest_version.major + 1, 0, 0);
        },
        VersionNumberType.minor => {
            return VersionDetails.init(latest_version.major, latest_version.minor + 1, 0);
        },
        VersionNumberType.patch => {
            return VersionDetails.init(latest_version.major, latest_version.minor, latest_version.patch + 1);
        },
    }

    return VersionDetails.init(0, 0, 0);
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
    var version_string: []u8 = try allocator.alloc(u8, 16);
    var version_numbers: []u16 = try allocator.alloc(u16, 3);

    defer allocator.free(version_string);
    defer allocator.free(version_numbers);

    var version_length: usize = 0;
    var versions_parsed: usize = 0;

    if (split.next()) |str| {
        for (str, 0..) |char, i| {
            _ = i;

            if (std.ascii.isDigit(char)) {
                version_string[version_length] = char;
                version_length += 1;
            } else if (char == '.') {
                version_numbers[versions_parsed] = try std.fmt.parseUnsigned(u16, version_string[0..version_length], 10);
                versions_parsed += 1;

                @memset(version_string, 0);
                version_length = 0;
            }
        }

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
