const std = @import("std");
const UUID = @import("root").UUID; // your implementation

pub fn main() !void {
    const iterations = 1_000_000;

    var timer = try std.time.Timer.start();

    var sum: u128 = 0; // prevent optimization

    for (0..iterations) |_| {
        const uuid = UUID.init();
        sum +%= uuid.bits.mask; // use the value
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

