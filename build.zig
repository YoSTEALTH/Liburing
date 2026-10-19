//! Build script for Liburing (Zig 0.17)
//!
//!   zig build          the `liburing` extension (and C liburing, `liburing-ffi.a`) for `-Dtarget`
//!   zig build develop  the extension into src/liburing/, to import it from the source tree
//!
//! Options:
//!   -Dfree-threaded=false   build for the regular (GIL) 3.15 instead of 3.15t
//!   -Dext-suffix=...        Python extension suffix (default: CPython's `EXT_SUFFIX` for the target and ABI)
const std = @import("std");

/// C liburing sources compiled into the library (`liburing_srcs` + `ffi.c` in lib/liburing/src/Makefile).
const liburing_srcs: []const []const u8 = &.{ "setup.c", "queue.c", "register.c", "syscall.c", "version.c", "ffi.c" };

/// `CPPFLAGS` and `CFLAGS` from lib/liburing/src/Makefile. `CONFIG_NOLIBC` is the only `config-host.h`
/// define the library reads, and `./configure --use-libc` leaves it out, so that header is not included.
const liburing_flags: []const []const u8 = &.{
    "-D_GNU_SOURCE",
    "-D_LARGEFILE_SOURCE",
    "-D_FILE_OFFSET_BITS=64",
    "-DLIBURING_INTERNAL",
    "-Wall",
    "-Wextra",
    "-Wno-unused-parameter",
    "-fno-stack-protector",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug symbols from the binary") orelse false;
    const free_threaded = b.option(bool, "free-threaded", "Build for free-threaded 3.15t (default: true)") orelse
        true;
    const ext_suffix = b.option([]const u8, "ext-suffix", "Python extension module suffix") orelse
        defaultSuffix(b, target.result, free_threaded);

    // `./configure` generates `compat.h` and `io_uring_version.h` (feature checks, not CPU specific),
    // so it runs once on the build machine for every target.
    try configure(b);

    // C liburing, compiled by Zig for the target instead of `make library`.
    const liburing_c = b.addLibrary(.{
        .name = "uring-ffi",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libc = true,
            .pic = true, // linked into a Python extension (a shared library)
        }),
    });
    liburing_c.root_module.addCSourceFiles(.{
        .root = b.path("lib/liburing/src"),
        .files = liburing_srcs,
        .flags = liburing_flags,
    });
    liburing_c.root_module.addIncludePath(b.path("lib/liburing/src/include"));
    b.installArtifact(liburing_c);

    // The C headers as a Zig module (`@import("c")`); `@cImport` no longer exists in Zig 0.17.
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/liburing/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(b.path("lib/liburing/src/include"));
    // Bodies translate-c can not translate (liburing's atomics) become `extern`s from `ffi.c`.
    const c_externs = b.addRunArtifact(b.addExecutable(.{
        .name = "c_externs",
        .root_module = b.createModule(.{ .root_source_file = b.path("tools/c_externs.zig"), .target = b.graph.host }),
    }));
    c_externs.addFileArg(translate_c.getOutput());
    const c_mod = b.createModule(.{
        .root_source_file = c_externs.addOutputFileArg("c.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const setu_dep = b.dependency("setu", .{});
    const options = b.addOptions();
    options.addOption(bool, "free_threaded", free_threaded);

    // The `liburing` extension module.
    const ext = b.addLibrary(.{
        .name = "liburing",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/liburing/root.zig"),
            .target = target,
            .optimize = optimize,
            .strip = strip,
            .link_libc = true,
            .imports = &.{
                .{ .name = "setu", .module = setu_dep.module("setu") },
                .{ .name = "c", .module = c_mod },
                .{ .name = "build_options", .module = options.createModule() },
            },
        }),
    });
    ext.root_module.linkLibrary(liburing_c);
    ext.linker_allow_shlib_undefined = true; // the CPython C API comes from the interpreter
    const ext_name = b.fmt("liburing{s}", .{ext_suffix});
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(ext.getEmittedBin(), .lib, ext_name).step);
    const develop = b.step("develop", "Build the extension into src/liburing/");
    develop.dependOn(&b.addInstallFileWithDir(ext.getEmittedBin(), .{ .custom = "../src/liburing" }, ext_name).step);
}

/// Runs `./configure --use-libc` in lib/liburing unless its generated headers already exist.
fn configure(b: *std.Build) !void {
    const io = b.graph.io;
    const dir = try b.root.joinString(b.allocator, "lib/liburing");
    const compat_h = b.pathJoin(&.{ dir, "src/include/liburing/compat.h" });
    std.Io.Dir.cwd().access(io, compat_h, .{}) catch |e| switch (e) {
        error.FileNotFound => try runCmd(b, &.{ "./configure", "--use-libc" }, dir),
        else => return e,
    };
}

fn runCmd(b: *std.Build, argv: []const []const u8, cwd: []const u8) !void {
    const result = try std.process.run(b.allocator, b.graph.io, .{ .argv = argv, .cwd = .{ .path = cwd } });
    defer b.allocator.free(result.stderr);
    defer b.allocator.free(result.stdout);
    if (!result.term.success()) {
        std.log.err("{s} failed in {s}:\n{s}", .{ argv[0], cwd, result.stderr });
        return error.CommandFailed;
    }
}

/// CPython's `EXT_SUFFIX` for `target`, like `.cpython-315t-x86_64-linux-gnu.so`.
fn defaultSuffix(b: *std.Build, target: std.Target, free_threaded: bool) []const u8 {
    const libc = if (target.abi.isMusl()) "musl" else "gnu";
    return b.fmt(".cpython-315{s}-{s}-linux-{s}.so", .{
        if (free_threaded) "t" else "",
        @tagName(target.cpu.arch),
        libc,
    });
}
