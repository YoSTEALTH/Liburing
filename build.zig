//! Build script for Liburing
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Strip option (can be set via -Dstrip=true or from pyoz CLI)
    const strip = b.option(bool, "strip", "Strip debug symbols from the binary") orelse false;

    // Get PyOZ dependency
    const pyoz_dep = b.dependency("PyOZ", .{
        .target = target,
        .optimize = optimize,
    });

    // Create the user's lib module (shared between library and stub generator)
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("liburing/root.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .imports = &.{.{ .name = "PyOZ", .module = pyoz_dep.module("PyOZ") }},
    });

    const static_path = "lib/liburing/src/liburing-ffi.a";

    std.fs.cwd().access(static_path, .{}) catch |e| switch (e) {
        error.FileNotFound => {
            const config = try runCmd(b.allocator, &.{"./configure"}, "lib/liburing");
            defer b.allocator.free(config);

            const make = try runCmd(b.allocator, &.{ "make", "library" }, "lib/liburing");
            defer b.allocator.free(make);
        },
        else => return e, // other error
    };

    lib_mod.addObjectFile(b.path(static_path));

    // Build the Python extension as a dynamic library
    // Note: underscore prefix separates the .so from the Python package directory
    const lib = b.addLibrary(.{
        .name = "_liburing",
        .linkage = .dynamic,
        .root_module = lib_mod,
    });

    // Link libc (required for Python C API)
    lib.root_module.link_libc = true;
    lib.root_module.addIncludePath(b.path("lib/liburing/src/include"));

    // Install the shared library
    const install = b.addInstallArtifact(lib, .{ .dest_sub_path = "_liburing.so" });
    b.getInstallStep().dependOn(&install.step);
}

fn runCmd(allocator: std.mem.Allocator, argv: []const []const u8, cwd: []const u8) ![]const u8 {
    const output = try std.process.Child.run(.{ .allocator = allocator, .argv = argv, .cwd = cwd });
    defer allocator.free(output.stderr);

    if (output.term.Exited == 0) return output.stdout;
    defer allocator.free(output.stdout);
    return error.CommandFailed;
}
