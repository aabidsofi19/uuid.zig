//! A Universally Unique Identifier (UUID) implementation in Zig.
//!
//! Conforms to RFC 9562 (https://www.rfc-editor.org/rfc/rfc9562.html).
//! Currently supports UUID version 7 (time-ordered, with random bits) and version 4 ( Random)
//! provides parsing and formatting utilities for the standard
//! `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` string representation.

const std = @import("std");

/// The 128-bit binary representation of the UUID, stored as a single integer.
/// The most significant 48 bits hold the timestamp in v7 UUIDs.
bits: u128,

const Self = @This();
const UUID = Self;

/// The nil UUID, where all 128 bits are set to zero.
/// See https://www.rfc-editor.org/rfc/rfc9562.html#name-nil-uuid
pub const Nil = Self{ .bits = 0 };

/// Lookup table mapping a 4-bit nibble value (0-15) to its lowercase ASCII hex character.
const hex_chars = "0123456789abcdef";

/// The two-bit variant field value (`10`) defined by RFC 9562,
/// identifying this UUID as an RFC 4122 / RFC 9562 variant.
/// See https://www.rfc-editor.org/rfc/rfc9562.html#name-variant-field
const variant_value: u2 = 0b10;

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

/// Creates a new UUID version 4 (random) as defined in RFC 9562.
///
/// Generates 122 bits of cryptographically secure random data and sets the
/// version field to `4` (`0b0100`) and the variant field to `0b10`.
///
///  ```
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                           random_a                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |          random_a             |  ver  |       random_b        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |var|                       random_c                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                           random_c                            |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
///  ```
///
/// See https://datatracker.ietf.org/doc/html/rfc9562#name-uuid-version-4
pub fn initV4() Self {
    const rand = std.crypto.random;

    const version_mask: u128 = @as(u128, 4) << 76; // 128 - 4 - 48
    const variant_mask: u128 = @as(u128, variant_value) << 62; // 128 - 2 - 64

    var bits = rand.int(u128);

    // Clear version bits
    bits &= ~(@as(u128, 0xF) << 76);
    // Clear variant bits
    bits &= ~(@as(u128, 0x3) << 62);

    bits |= version_mask | variant_mask;

    return Self{
        .bits = bits,
    };
}

/// Returns the 2-bit variant field of this UUID.
///
/// For RFC 9562 UUIDs the value is `0b10`. The variant occupies
/// bits 62-63 (counting from the LSB) of the 128-bit representation.
pub fn variant(self: Self) u2 {
    return @truncate(self.bits >> 62);
}

/// Returns the 4-bit version field of this UUID.
///
/// For v7 UUIDs the value is `7` (`0b0111`). The version occupies
/// bits 76-79 (counting from the LSB) of the 128-bit representation.
pub fn version(self: Self) u4 {
    return @truncate(self.bits >> 76);
}

/// Parses a UUID from its string representation.
///
/// Accepts both the standard hyphenated format (`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`,
/// 36 characters) and the compact hex format (32 characters, no hyphens).
///
/// Returns `error.InvalidUuidString` if the length is neither 32 nor 36.
/// Returns `error.InvalidCharacter` if any non-hyphen character is not valid hexadecimal.
pub fn fromString(str: []const u8) !Self {
    if (!(str.len == 36 or str.len == 32)) {
        return error.InvalidUuidString;
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

/// Returns `true` if both UUIDs have the same 128-bit value.
pub fn eql(self: Self, other: Self) bool {
    return self.bits == other.bits;
}

/// Returns `true` if this UUID's 128-bit value is strictly greater than `other`.
///
/// For v7 UUIDs that share the same timestamp, this compares the random bits.
/// Across different timestamps, a later UUID will be greater because the
/// timestamp occupies the most significant 48 bits.
pub fn greaterThan(self: Self, other: Self) bool {
    return self.bits > other.bits;
}

/// Formats the UUID as the standard hyphenated lowercase hex string
/// `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (36 characters, 8-4-4-4-12).
///
/// The returned array is stack-allocated and can be used directly
/// or copied as needed.
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

// ===================== Reusable test helpers =====================
// These helpers are parameterized by a generator function and an expected
// version number so they can be shared across all UUID versions.

const GeneratorFn = *const fn () Self;

fn expectCorrectVersion(generator: GeneratorFn, expected_version: u4) !void {
    const uuid = generator();
    try std.testing.expectEqual(expected_version, uuid.version());
}

fn expectCorrectVariant(generator: GeneratorFn) !void {
    const uuid = generator();
    try std.testing.expectEqual(@as(u2, 0b10), uuid.variant());
}

fn expectVersionAndVariantAcrossManyGenerations(generator: GeneratorFn, expected_version: u4) !void {
    for (0..100) |_| {
        const uuid = generator();
        try std.testing.expectEqual(expected_version, uuid.version());
        try std.testing.expectEqual(@as(u2, 0b10), uuid.variant());
    }
}

fn expectVersionCharInString(generator: GeneratorFn, expected_char: u8) !void {
    const uuid = generator();
    const str = uuid.toString();
    // The version nibble appears at position 14 in the string (after "xxxxxxxx-xxxx-")
    try std.testing.expectEqual(expected_char, str[14]);
}

fn expectVariantCharInString(generator: GeneratorFn) !void {
    for (0..100) |_| {
        const uuid = generator();
        const str = uuid.toString();
        // The variant nibble appears at position 19 in the string (after "xxxxxxxx-xxxx-xxxx-")
        const variant_char = str[19];
        const valid = (variant_char == '8' or variant_char == '9' or variant_char == 'a' or variant_char == 'b');
        try std.testing.expect(valid);
    }
}

fn expectAllUnique(generator: GeneratorFn, count: usize) !void {
    var uuids: [1000]u128 = undefined;
    std.debug.assert(count <= uuids.len);

    for (0..count) |i| {
        uuids[i] = generator().bits;
    }

    for (0..count) |i| {
        for (i + 1..count) |j| {
            try std.testing.expect(uuids[i] != uuids[j]);
        }
    }
}

fn expectToStringFromStringRoundTrip(generator: GeneratorFn) !void {
    for (0..50) |_| {
        const uuid = generator();
        const str = uuid.toString();
        const parsed = try UUID.fromString(&str);
        try std.testing.expectEqual(uuid.bits, parsed.bits);
    }
}

fn expectToStringFormat(generator: GeneratorFn) !void {
    const uuid = generator();
    const str = uuid.toString();

    // Check total length
    try std.testing.expectEqual(@as(usize, 36), str.len);

    // Check hyphen positions
    try std.testing.expectEqual(@as(u8, '-'), str[8]);
    try std.testing.expectEqual(@as(u8, '-'), str[13]);
    try std.testing.expectEqual(@as(u8, '-'), str[18]);
    try std.testing.expectEqual(@as(u8, '-'), str[23]);

    // Check all non-hyphen characters are valid lowercase hex
    var hyphen_count: usize = 0;
    for (str, 0..) |c, i| {
        if (i == 8 or i == 13 or i == 18 or i == 23) {
            try std.testing.expectEqual(@as(u8, '-'), c);
            hyphen_count += 1;
        } else {
            const is_hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
            try std.testing.expect(is_hex);
            // Ensure no uppercase
            const is_upper = (c >= 'A' and c <= 'F');
            try std.testing.expect(!is_upper);
        }
    }
    try std.testing.expectEqual(@as(usize, 4), hyphen_count);
}

// ===================== V7 tests (shared helpers) =====================

test "v7 has correct version bits" {
    try expectCorrectVersion(initV7, 7);
}

test "v7 has correct variant bits" {
    try expectCorrectVariant(initV7);
}

test "v7 version and variant correct across many generations" {
    try expectVersionAndVariantAcrossManyGenerations(initV7, 7);
}

test "v7 version character is '7' in string representation" {
    try expectVersionCharInString(initV7, '7');
}

test "v7 variant character is 8, 9, a, or b in string representation" {
    try expectVariantCharInString(initV7);
}

test "v7 multiple UUIDs are all unique" {
    try expectAllUnique(initV7, 256);
}

test "v7 toString and fromString round-trip" {
    try expectToStringFromStringRoundTrip(initV7);
}

test "v7 toString produces correct format" {
    try expectToStringFormat(initV7);
}

// ===================== V4 tests (shared helpers) =====================

test "v4 has correct version bits" {
    try expectCorrectVersion(initV4, 4);
}

test "v4 has correct variant bits" {
    try expectCorrectVariant(initV4);
}

test "v4 version and variant correct across many generations" {
    try expectVersionAndVariantAcrossManyGenerations(initV4, 4);
}

test "v4 version character is '4' in string representation" {
    try expectVersionCharInString(initV4, '4');
}

test "v4 variant character is 8, 9, a, or b in string representation" {
    try expectVariantCharInString(initV4);
}

test "v4 multiple UUIDs are all unique" {
    try expectAllUnique(initV4, 256);
}

test "v4 toString and fromString round-trip" {
    try expectToStringFromStringRoundTrip(initV4);
}

test "v4 toString produces correct format" {
    try expectToStringFormat(initV4);
}

// ===================== V7-specific tests =====================

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

test "v7 UUIDs generated sequentially have non-decreasing timestamps" {
    const uuid1 = UUID.initV7();
    const uuid2 = UUID.initV7();

    // The timestamp is in the most significant 48 bits, so a later (or same)
    // timestamp should produce a >= value.
    const ts1 = @as(u48, @truncate(uuid1.bits >> 80));
    const ts2 = @as(u48, @truncate(uuid2.bits >> 80));
    try std.testing.expect(ts2 >= ts1);
}

// ===================== toString known-value tests =====================

test "from integer" {
    const bitArray: u128 = 0b11111000000111010100111110101110011111011110110000010001110100001010011101100101000000001010000011001001000111100110101111110110;

    const uuid = UUID{ .bits = bitArray };
    const string = uuid.toString();

    try std.testing.expectEqual(true, std.mem.eql(u8, &string, "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"));
}

test "toString produces lowercase hex only" {
    // Use a value that would produce a-f characters
    const uuid = UUID{ .bits = 0xABCDEF0123456789ABCDEF0123456789 };
    const str = uuid.toString();

    for (str) |c| {
        if (c != '-') {
            const is_lower_hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
            try std.testing.expect(is_lower_hex);
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
    try std.testing.expectError(error.InvalidUuidString, result);
}

test "fromString rejects too-long strings" {
    const result = UUID.fromString("f81d4fae-7dec-11d0-a765-00a0c91e6bf6aa");
    try std.testing.expectError(error.InvalidUuidString, result);
}

test "fromString rejects empty string" {
    const result = UUID.fromString("");
    try std.testing.expectError(error.InvalidUuidString, result);
}

test "fromString rejects invalid hex characters" {
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

test "fromString and toString preserve known RFC-style UUID" {
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

// ===================== Benchmark tests =====================
fn benchmarkCreation(title: []const u8 , initFunc:GeneratorFn) !void {
    const iterations = 1_000_000;

    var timer = try std.time.Timer.start();

    var sum: u128 = 0; // prevent optimization

    for (0..iterations) |_| {
        const uuid = initFunc() ;
        sum +%= uuid.bits; // use the value
    }

    const elapsed = timer.read();

    const ns_per_op = elapsed / iterations;

    std.debug.print(
        \\{s} Benchmark 
        \\Iterations: {}
        \\Total time: {} ms
        \\ns/op: {}
        \\ignore: {}
        \\
        \\
    ,
        .{
            title,
            iterations,
            elapsed / 1_000_000,
            ns_per_op,
            sum,
        },
    );

}

test "Benchmark v7 creation" {
   try benchmarkCreation("UUIDv7", initV7) ;
}


test "Benchmark v4 creation" {
   try benchmarkCreation("UUIDv7", initV4) ;
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
        \\Benchmark to string
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
