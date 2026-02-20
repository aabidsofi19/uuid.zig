const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ── Library module (the public API consumed by dependents) ───────────
    // target and optimize are intentionally omitted so that downstream
    // projects inherit their own settings via the Zig package manager.
    const mod = b.addModule("uuid_zig", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // ── Example executable (zig build run) ──────────────────────────────
    const exe = b.addExecutable(.{
        .name = "uuid_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "uuid_zig", .module = mod },
            },
        }),
    });

    // The example binary is only installed when explicitly requested
    // (zig build run), not on a bare `zig build`.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Build and run the example binary");
    run_step.dependOn(&run_cmd.step);

    // ── Tests (zig build test) ──────────────────────────────────────────
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(lib_tests).step);
}
