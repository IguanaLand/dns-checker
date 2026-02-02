const std = @import("std");

pub fn build(b: *std.Build) void {
    const force_release = (b.option(bool, "release", "build in ReleaseSafe mode")) orelse false;
    const force_debug = (b.option(bool, "debug", "build in Debug mode")) orelse false;
    const force_valgrind = (b.option(bool, "valgrind", "use baseline CPU features for Valgrind")) orelse false;
    const strip_binaries = b.option(bool, "strip", "strip debug symbols from binaries");
    var target_query = b.standardTargetOptionsQueryOnly(.{});
    if (force_valgrind) {
        target_query.cpu_model = .baseline;
        target_query.cpu_features_add = .empty;
        target_query.cpu_features_sub = .empty;
    }
    const target = b.resolveTargetQuery(target_query);

    if (force_release and force_debug) {
        std.log.err("build options conflict: -Drelease and -Ddebug are mutually exclusive", .{});
        std.process.exit(1);
    }

    const optimize = if (force_release)
        .ReleaseSafe
    else if (force_debug)
        .Debug
    else
        b.standardOptimizeOption(.{});

    const mod = b.addModule("dns_checker", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip_binaries,
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
            .strip = strip_binaries,

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
