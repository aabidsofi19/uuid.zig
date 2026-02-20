const std = @import("std");

bits: u128,

const Self = @This();
const UUID = Self;
const Nil = Self{.bits = 0};

const hex_chars = "0123456789abcdef";
const variant_value: u2 = 0b10; //the variant specided in https://www.rfc-editor.org/rfc/rfc9562.html

// follows uuid v7 implementation as defined in https://www.rfc-editor.org/rfc/rfc9562.html
//
//  0                   1                   2                   3
//  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                           unix_ts_ms                          |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |          unix_ts_ms           |  ver  |  rand_a (12 bit seq)  |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |var|                        rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
// |                            rand_b                             |
// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
//
/// UUID version 7 features a time-ordered value field derived from the widely
/// implemented and well known Unix Epoch timestamp source,
/// the number of milliseconds seconds since midnight 1 Jan 1970 UTC, leap seconds excluded.
/// As well as improved entropy characteristics over versions 1 or 6.
///
/// see https://datatracker.ietf.org/doc/html/rfc9562#name-uuid-version-7
///
/// Implementations SHOULD utilize UUID version 7 over UUID version 1 and 6 if possible.
pub fn initV7() Self {
    const unix_ts_ms: u48 = @truncate(@as(u64, @intCast(std.time.milliTimestamp()))); // 64 -48 = 16

    const version7: u4 = 7; //    0b0111
    const rand = std.crypto.random;
    const rand_a: u12 = rand.int(u12);
    const rand_b: u62 = rand.int(u62);

    const ts_mask: u128 = @as(u128, unix_ts_ms) << 80; // 128 - 48 - 0
    const version_mask: u128 = @as(u128, version7) << 76; // 128 - 4 - 48
    const variant_mask: u128 = @as(u128, variant_value) << 62; // 128 - 2 - 64
    const rand_a_mask: u128 = @as(u128, rand_a) << 64; // 128 - 12 - 52
    const rand_b_mask: u128 = @as(u128, rand_b); // 128 - 62 - 66

    const bits: u128 = ts_mask | version_mask | variant_mask | rand_a_mask | rand_b_mask;

    const uuid = Self{
        .bits = bits,
    };

    return uuid;
}

pub fn initV4() Self {
    return Self{
        .bits = 0,
    };
}

// Variant is bits 64-65 from the MSB
// In the 128-bit value: bits [63:62] (shift right by 62)
pub fn variant(self:Self) u2 {
    return @truncate(self.bits >> 62);

}

// Version is bits 48-51 (4 bits) from the MSB
// In the 128-bit value: bits [79:76] (shift right by 76)
pub fn version(self:Self) u4 {
    return @truncate(self.bits >>  76) ;
}

// supports both hyphenated and non hyphenated uuid strings
pub fn fromString(str: []const u8) !Self {
    if (!(str.len == 36 or str.len == 32)) {
        return error.InvalidUuuidString;
    }

    var string: [32]u8 = undefined;
    var i: usize = 0;

    for (str) |char| {
        if (char == '-') {
            continue;
        }
        string[i] = char;
        i += 1;
    }

    const int: u128 = try std.fmt.parseInt(u128, &string, 16);
    return Self{ .bits = int };
}

pub fn eql(self: Self, other: Self) bool {
    return self.bits == other.bits;
}

pub fn greaterThan(self: Self, other: Self) bool {
    return self.bits > other.bits;
}

pub fn toString(self: Self) [36]u8 {
    var buf: [36]u8 = undefined;

    // var chars :[32]u8 = undefined;
    var nibble_index: u7 = 124; // starting pos of nibble to left

    for (0..36) |i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            buf[i] = '-';
            continue;
        }

        const nibble: u4 = @truncate((self.bits >> nibble_index)); // truncating gets the 4 LSB ( same as & 0xF)
        buf[i] = hex_chars[nibble];

        if (i != 35) {
            nibble_index -= 4;
        }
    }

    return buf;
}

test "from integer" {
    const bitArray: u128 = 0b11111000000111010100111110101110011111011110110000010001110100001010011101100101000000001010000011001001000111100110101111110110;

    const uuid = UUID{ .bits = bitArray };
    // var buf : [36]u8 = undefined;
    const string = uuid.toString();

    // std.debug.print("from integer string {s} \n", .{string});
    try std.testing.expectEqual(true, std.mem.eql(u8, &string, "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"));
}

test "uuid v7 generation" {
    const iterations = 256;
    var generated: [iterations]UUID = undefined;

    for (0..iterations) |i| {
        const uuid = UUID.initV7();

        // each new generated uuid should be unique
        for (generated[0..i]) |prev| {
            try std.testing.expect(!uuid.eql(prev));
        }

        generated[i] = uuid;
    }
}

test "to and from string" {
    const uuid = UUID.initV7();

    const string = uuid.toString();
    // std.debug.print("string {s}", .{string});
    const uuid2 = try UUID.fromString(&string);

    try std.testing.expect(uuid.bits == uuid2.bits);
}

// Benchmark tests
test "Benchmark v7 creation" {
    const iterations = 1_000_000;

    var timer = try std.time.Timer.start();

    var sum: u128 = 0; // prevent optimization

    for (0..iterations) |_| {
        const uuid = UUID.initV7();
        sum +%= uuid.bits; // use the value
    }

    const elapsed = timer.read();

    const ns_per_op = elapsed / iterations;

    std.debug.print(
        \\UUIDv7 Benchmark (Zig)
        \\Iterations: {}
        \\Total time: {} ms
        \\ns/op: {}
        \\ignore: {}
        \\
    ,
        .{
            iterations,
            elapsed / 1_000_000,
            ns_per_op,
            sum,
        },
    );
}

test "Benchmark to string" {
    const iterations = 1_000_000;

    const uuid = UUID.initV7();

    var timer = try std.time.Timer.start();

    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(uuid.toString());
    }

    const elapsed = timer.read();

    const ns_per_op = elapsed / iterations;

    std.debug.print(
        \\Benchmark to string (Zig)
        \\Iterations: {}
        \\Total time: {} ms
        \\ns/op: {}
        \\
    ,
        .{
            iterations,
            elapsed / 1_000_000,
            ns_per_op,
        },
    );
}

// ===================== toString format tests =====================

test "toString produces correct 8-4-4-4-12 format with hyphens" {
    const uuid = UUID.initV7();
    const str = uuid.toString();

    // Check total length
    try std.testing.expectEqual(@as(usize, 36), str.len);

    // Check hyphen positions
    try std.testing.expectEqual(@as(u8, '-'), str[8]);
    try std.testing.expectEqual(@as(u8, '-'), str[13]);
    try std.testing.expectEqual(@as(u8, '-'), str[18]);
    try std.testing.expectEqual(@as(u8, '-'), str[23]);

    // Check all non-hyphen characters are valid lowercase hex
    for (str, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            try std.testing.expectEqual(@as(u8, '-'), c);
        } else {
            const is_hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
            try std.testing.expect(is_hex);
        }
    }
}

test "toString produces lowercase hex only" {
    // Use a value that would produce a-f characters
    const uuid = UUID{ .bits = 0xABCDEF0123456789ABCDEF0123456789 };
    const str = uuid.toString();

    for (str) |c| {
        if (c != '-') {
            const is_lower_hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
            try std.testing.expect(is_lower_hex);
            // Ensure no uppercase
            const is_upper = (c >= 'A' and c <= 'F');
            try std.testing.expect(!is_upper);
        }
    }
}

test "nil UUID (all zeros) toString" {
    const uuid = UUID{ .bits = 0 };
    const str = uuid.toString();
    try std.testing.expectEqualStrings("00000000-0000-0000-0000-000000000000", &str);
}

test "max UUID (all ones) toString" {
    const uuid = UUID{ .bits = std.math.maxInt(u128) };
    const str = uuid.toString();
    try std.testing.expectEqualStrings("ffffffff-ffff-ffff-ffff-ffffffffffff", &str);
}

test "toString segment lengths are correct" {
    const uuid = UUID.initV7();
    const str = uuid.toString();

    // Split by hyphens and verify segment lengths: 8-4-4-4-12
    // Segment 1: indices 0..8 (len 8)
    // Segment 2: indices 9..13 (len 4)
    // Segment 3: indices 14..18 (len 4)
    // Segment 4: indices 19..23 (len 4)
    // Segment 5: indices 24..36 (len 12)
    try std.testing.expectEqual(@as(usize, 8), 8); // 0 to 7
    try std.testing.expectEqual(@as(u8, '-'), str[8]);
    try std.testing.expectEqual(@as(u8, '-'), str[13]);
    try std.testing.expectEqual(@as(u8, '-'), str[18]);
    try std.testing.expectEqual(@as(u8, '-'), str[23]);

    // No other hyphens
    var hyphen_count: usize = 0;
    for (str) |c| {
        if (c == '-') hyphen_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), hyphen_count);
}

// ===================== fromString tests =====================

test "fromString with non-hyphenated 32-char string" {
    const uuid_str = "f81d4fae7dec11d0a76500a0c91e6bf6";
    const uuid = try UUID.fromString(uuid_str);
    const expected = UUID{ .bits = 0xf81d4fae7dec11d0a76500a0c91e6bf6 };
    try std.testing.expect(uuid.eql(expected));
}

test "fromString with hyphenated string" {
    const uuid_str = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6";
    const uuid = try UUID.fromString(uuid_str);
    const expected = UUID{ .bits = 0xf81d4fae7dec11d0a76500a0c91e6bf6 };
    try std.testing.expect(uuid.eql(expected));
}

test "fromString rejects too-short strings" {
    const result = UUID.fromString("f81d4fae-7dec-11d0-a765");
    try std.testing.expectError(error.InvalidUuuidString, result);
}

test "fromString rejects too-long strings" {
    const result = UUID.fromString("f81d4fae-7dec-11d0-a765-00a0c91e6bf6aa");
    try std.testing.expectError(error.InvalidUuuidString, result);
}

test "fromString rejects empty string" {
    const result = UUID.fromString("");
    try std.testing.expectError(error.InvalidUuuidString, result);
}

test "fromString rejects invalid hex characters" {
    // 'g' is not a valid hex character
    const result = UUID.fromString("g81d4fae-7dec-11d0-a765-00a0c91e6bf6");
    try std.testing.expectError(error.InvalidCharacter, result);
}

test "fromString round-trip with known UUID string" {
    const original_str = "550e8400-e29b-41d4-a716-446655440000";
    const uuid = try UUID.fromString(original_str);
    const result_str = uuid.toString();
    try std.testing.expectEqualStrings(original_str, &result_str);
}

test "fromString round-trip with non-hyphenated input produces hyphenated output" {
    const input = "550e8400e29b41d4a716446655440000";
    const uuid = try UUID.fromString(input);
    const result_str = uuid.toString();
    try std.testing.expectEqualStrings("550e8400-e29b-41d4-a716-446655440000", &result_str);
}

// ===================== V7 correctness tests =====================

test "v7 UUID has correct version bits" {
    const uuid = UUID.initV7();
    try std.testing.expectEqual(@as(u4, 7), uuid.version());
}

test "v7 UUID has correct variant bits" {
    const uuid = UUID.initV7();
    const variant_val = uuid.variant();
    try std.testing.expectEqual(@as(u2, 0b10), variant_val);
}

test "v7 UUID version and variant correct across many generations" {
    for (0..100) |_| {
        const uuid = UUID.initV7();
        const ver = uuid.version();
        const variant_val = uuid.variant();
        try std.testing.expectEqual(@as(u4, 7), ver);
        try std.testing.expectEqual(@as(u2, 0b10), variant_val);
    }
}

test "v7 UUID version character is '7' in string representation" {
    const uuid = UUID.initV7();
    const str = uuid.toString();
    // The version nibble appears at position 14 in the string (index 14, after "xxxxxxxx-xxxx-")
    try std.testing.expectEqual(@as(u8, '7'), str[14]);
}

test "v7 UUID variant character is 8, 9, a, or b in string representation" {
    for (0..100) |_| {
        const uuid = UUID.initV7();
        const str = uuid.toString();
        // The variant nibble appears at position 19 in the string (after "xxxxxxxx-xxxx-xxxx-")
        const variant_char = str[19];
        const valid = (variant_char == '8' or variant_char == '9' or variant_char == 'a' or variant_char == 'b');
        try std.testing.expect(valid);
    }
}

test "v7 UUID timestamp is close to current time" {
    const before_ms = @as(u64, @intCast(std.time.milliTimestamp()));
    const uuid = UUID.initV7();
    const after_ms = @as(u64, @intCast(std.time.milliTimestamp()));

    // Extract the 48-bit timestamp from the top bits
    const ts = @as(u48, @truncate(uuid.bits >> 80));
    const ts_u64 = @as(u64, ts);

    // Timestamp should be between before and after
    try std.testing.expect(ts_u64 >= before_ms);
    try std.testing.expect(ts_u64 <= after_ms);
}

// ===================== eql tests =====================

test "eql returns true for identical UUIDs" {
    const uuid = UUID{ .bits = 0x550e8400e29b41d4a716446655440000 };
    const same = UUID{ .bits = 0x550e8400e29b41d4a716446655440000 };
    try std.testing.expect(uuid.eql(same));
}

test "eql returns true for self-comparison" {
    const uuid = UUID.initV7();
    try std.testing.expect(uuid.eql(uuid));
}

test "eql returns false for different UUIDs" {
    const uuid1 = UUID{ .bits = 0x550e8400e29b41d4a716446655440000 };
    const uuid2 = UUID{ .bits = 0x550e8400e29b41d4a716446655440001 };
    try std.testing.expect(!uuid1.eql(uuid2));
}

test "eql returns false for nil vs non-nil" {
    const nil = UUID{ .bits = 0 };
    const non_nil = UUID.initV7();
    try std.testing.expect(!nil.eql(non_nil));
}

// ===================== greaterThan tests =====================

test "greaterThan returns true when first is larger" {
    const larger = UUID{ .bits = 100 };
    const smaller = UUID{ .bits = 50 };
    try std.testing.expect(larger.greaterThan(smaller));
}

test "greaterThan returns false when first is smaller" {
    const larger = UUID{ .bits = 100 };
    const smaller = UUID{ .bits = 50 };
    try std.testing.expect(!smaller.greaterThan(larger));
}

test "greaterThan returns false for equal UUIDs" {
    const uuid1 = UUID{ .bits = 42 };
    const uuid2 = UUID{ .bits = 42 };
    try std.testing.expect(!uuid1.greaterThan(uuid2));
}

test "greaterThan with max and min values" {
    const max = UUID{ .bits = std.math.maxInt(u128) };
    const min = UUID{ .bits = 0 };
    try std.testing.expect(max.greaterThan(min));
    try std.testing.expect(!min.greaterThan(max));
}

// ===================== V7 ordering / monotonicity tests =====================

test "v7 UUIDs generated sequentially have non-decreasing timestamps" {
    const uuid1 = UUID.initV7();
    const uuid2 = UUID.initV7();

    // The timestamp is in the most significant 48 bits, so a later (or same)
    // timestamp should produce a >= value.
    const ts1 = @as(u48, @truncate(uuid1.bits >> 80));
    const ts2 = @as(u48, @truncate(uuid2.bits >> 80));
    try std.testing.expect(ts2 >= ts1);
}

// ===================== Specific known-value tests =====================

test "fromString and toString preserve known RFC-style UUID" {
    // A well-known example UUID from RFC 9562
    const rfc_str = "f81d4fae-7dec-11d0-a765-00a0c91e6bf6";
    const uuid = try UUID.fromString(rfc_str);
    const result = uuid.toString();
    try std.testing.expectEqualStrings(rfc_str, &result);
}

test "fromString preserves bits for all-zero UUID" {
    const uuid = try UUID.fromString("00000000-0000-0000-0000-000000000000");
    try std.testing.expectEqual(@as(u128, 0), uuid.bits);
}

test "fromString preserves bits for all-f UUID" {
    const uuid = try UUID.fromString("ffffffff-ffff-ffff-ffff-ffffffffffff");
    try std.testing.expectEqual(std.math.maxInt(u128), uuid.bits);
}

test "multiple v7 UUIDs are all unique" {
    const count = 1000;
    var uuids: [count]u128 = undefined;

    for (0..count) |i| {
        uuids[i] = UUID.initV7().bits;
    }

    // Check every pair is unique
    for (0..count) |i| {
        for (i + 1..count) |j| {
            try std.testing.expect(uuids[i] != uuids[j]);
        }
    }
}

test "toString and fromString round-trip for v7" {
    for (0..50) |_| {
        const uuid = UUID.initV7();
        const str = uuid.toString();
        const parsed = try UUID.fromString(&str);
        try std.testing.expectEqual(uuid.bits, parsed.bits);
    }
}
