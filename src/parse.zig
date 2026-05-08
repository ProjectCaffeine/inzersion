const std = @import("std");
const models = @import("models.zig");

pub fn parseVersionLine(line: []const u8, iter: *std.mem.SplitIterator(u8, std.mem.DelimiterType.sequence), str_text: []const u8, allocator: std.mem.Allocator) !?models.VersionDetails {
    if (std.mem.eql(u8, line, str_text)) {
        if (iter.*.next()) |val| {
            return try parseOutVersionNumber(val, allocator);
        }
    }

    return null;
}

pub fn parseOutVersionNumber(line: []const u8, allocator: std.mem.Allocator) error{ InvalidCharacter, Overflow, OutOfMemory }!models.VersionDetails {
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

    return models.VersionDetails.init(version_numbers[0], version_numbers[1], version_numbers[2]);
}

pub fn getFinalVersion(version_data: models.AllVersionData, resolution_method: models.VersionResolutionMethod) models.VersionDetails {
    var latest_version: models.VersionDetails = undefined;

    if (version_data.current_version.major != version_data.pulled_version.major) {
        latest_version = if (version_data.current_version.major > version_data.pulled_version.major) version_data.current_version else version_data.pulled_version;
    } else if (version_data.current_version.minor != version_data.pulled_version.minor) {
        latest_version = if (version_data.current_version.minor > version_data.pulled_version.minor) version_data.current_version else version_data.pulled_version;
    } else if (version_data.current_version.patch != version_data.pulled_version.patch) {
        latest_version = if (version_data.current_version.patch > version_data.pulled_version.patch) version_data.current_version else version_data.pulled_version;
    }

    //std.debug.print("Latest version is current:\n{any}\n", .{latest_version.equals(version_data.current_version)});
    //std.debug.print("Latest version is pulled:\n{any}\n", .{latest_version.equals(version_data.pulled_version)});

    if (resolution_method == models.VersionResolutionMethod.use_latest) {
        return latest_version;
    }

    switch (if (latest_version.equals(version_data.current_version)) version_data.pulled_version.most_recent_update else version_data.current_version.most_recent_update) {
        models.VersionNumberType.major => {
            return models.VersionDetails.init(latest_version.major + 1, 0, 0);
        },
        models.VersionNumberType.minor => {
            return models.VersionDetails.init(latest_version.major, latest_version.minor + 1, 0);
        },
        models.VersionNumberType.patch => {
            return models.VersionDetails.init(latest_version.major, latest_version.minor, latest_version.patch + 1);
        },
    }

    return models.VersionDetails.init(0, 0, 0);
}
