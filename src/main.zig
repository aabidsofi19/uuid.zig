const std = @import("std");
const UUID = @import("uuid_zig");

pub fn main() void {
    const v7 = UUID.initV7();
    const v4 = UUID.initV4();

    std.debug.print("UUIDv7: {s}\n", .{v7.toString()});
    std.debug.print("UUIDv4: {s}\n", .{v4.toString()});
    std.debug.print("Version: {d}  Variant: {b}\n", .{ v7.version(), v7.variant() });
}
