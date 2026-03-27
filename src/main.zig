const std = @import("std");
const json_data = @embedFile("testconflictversioninfo.json");

pub fn main() !void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    //const allocator = gpa.allocator();

    std.debug.print("File:\n{s}", .{json_data[0..64]});
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
