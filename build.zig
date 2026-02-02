const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("dns_checker", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const zigdig_dep = b.dependency("zigdig", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "dns_checker",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,

            .imports = &.{
                .{ .name = "dns_checker", .module = mod },
                .{ .name = "dns", .module = zigdig_dep.module("dns") },
            },
        }),
    });

    b.installArtifact(exe);
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
