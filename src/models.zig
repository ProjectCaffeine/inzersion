pub const VersionNumberType = enum { major, minor, patch };

pub const VersionResolutionMethod = enum { use_latest, generate_next };

pub const AllVersionData = struct {
    current_version: VersionDetails,
    pulled_version: VersionDetails,
};

pub const VersionDetails = struct {
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
