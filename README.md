# uuid.zig

A fast,no allocation, zero-dependency UUID implementation in Zig conforming to [RFC 9562](https://www.rfc-editor.org/rfc/rfc9562.html).

## Supported versions

| Version | Description |
|---------|-------------|
| v7 | Time-ordered (48-bit Unix millisecond timestamp + cryptographic randomness). Recommended for new applications. |
| v4 | Random (122 bits of cryptographic randomness). |

Both versions set the RFC 9562 variant (`0b10`) and the correct version nibble automatically.

## Usage

### As a Zig package dependency

Add `uuid.zig` to your project's `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/aabidsofi19/uuid.zig
```

Then expose it to your code in `build.zig`:

```zig
const uuid_dep = b.dependency("uuid_zig", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("uuid", uuid_dep.module("uuid_zig"));
```

### Generating UUIDs

```zig
const uuid = @import("uuid");

// Version 7 (time-ordered, recommended)
const id = uuid.initV7();

// Version 4 (random)
const id4 = uuid.initV4();
```

### Formatting and parsing

```zig
// To the standard 8-4-4-4-12 hyphenated string
const str = id.toString(); // e.g. "01906e5b-1a76-7330-a008-4f6f3a2d4c7f"

// Parse from a hyphenated or compact hex string
const parsed = try uuid.fromString("550e8400-e29b-41d4-a716-446655440000");
const parsed2 = try uuid.fromString("550e8400e29b41d4a716446655440000");
```

### Comparison

```zig
if (a.eql(b)) { ... }
if (a.greaterThan(b)) { ... }
```

### Inspecting version and variant

```zig
const ver = id.version(); // 7
const var_ = id.variant(); // 0b10
```

### Nil UUID

```zig
const nil = uuid.Nil; // 00000000-0000-0000-0000-000000000000
```

## Building

Requires **Zig 0.15.2** or later.

```sh
# Build the library and example binary
zig build

# Run the example binary
zig build run

# Run all tests (includes correctness tests + benchmarks)
zig build test
```

## Project structure

```
uuid.zig/
  src/
    root.zig   # UUID implementation and tests
    main.zig   # Example CLI binary
  build.zig
  build.zig.zon
```

## License

[MIT](LICENSE)
