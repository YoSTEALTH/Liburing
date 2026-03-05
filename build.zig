//! Build script for Liburing
const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const static_path = "lib/liburing/src/liburing-ffi.a";

    // Strip option (can be set via -Dstrip=true or from pyoz CLI)
    const strip = b.option(bool, "strip", "Strip debug symbols from the binary") orelse false;

    // Get PyOZ dependency
    const pyoz_dep = b.dependency("PyOZ", .{ .target = target, .optimize = optimize });

    // Create the user's lib module (shared between library and stub generator)
    const user_lib_mod = b.createModule(.{
        .root_source_file = b.path("src/liburing/root.zig"),
        .optimize = optimize,
        .target = target,
        .strip = strip,
        .imports = &.{.{ .name = "PyOZ", .module = pyoz_dep.module("PyOZ") }},
    });

    // If not already compiled compile C liburing.
    std.fs.cwd().access(static_path, .{}) catch |e| switch (e) {
        error.FileNotFound => {
            try runCmd(b.allocator, &.{"./configure"}, "lib/liburing");
            try runCmd(b.allocator, &.{ "make", "library" }, "lib/liburing");
        },
        else => return e, // other error
    };

    user_lib_mod.addObjectFile(b.path(static_path));
    user_lib_mod.addIncludePath(b.path("lib/liburing/src/include"));
    user_lib_mod.link_libc = true;

    // Generate a bridge module that forces analysis of all pub decls in the
    // user's code. This triggers @export inside pyoz.module() so the PyInit_
    // function is automatically created — no manual boilerplate needed.
    const bridge_wf = b.addWriteFiles();
    const bridge_source = bridge_wf.add("_pyoz_bridge.zig",
        \\const _mod = @import("_pyoz_mod");
        \\comptime {
        \\    for (@typeInfo(_mod).@"struct".decls) |decl| {
        \\        _ = @field(_mod, decl.name);
        \\    }
        \\}
    );
    const bridge_mod = b.createModule(.{
        .root_source_file = bridge_source,
        .optimize = optimize,
        .target = target,
        .strip = strip,
        .imports = &.{.{ .name = "_pyoz_mod", .module = user_lib_mod }},
    });

    // Build the Python extension as a dynamic library
    // Note: underscore prefix separates the .so from the Python package directory
    const lib = b.addLibrary(.{
        .name = "liburing",
        .linkage = .dynamic,
        .root_module = bridge_mod,
    });

    // Install the shared library
    const install = b.addInstallArtifact(lib, .{ .dest_sub_path = "liburing.so" });
    b.getInstallStep().dependOn(&install.step);
}

fn runCmd(allocator: std.mem.Allocator, argv: []const []const u8, cwd: []const u8) !void {
    const output = try std.process.Child.run(.{ .allocator = allocator, .argv = argv, .cwd = cwd });
    defer allocator.free(output.stderr);
    defer allocator.free(output.stdout);
    if (output.term.Exited != 0) return error.CommandFailed;
}
