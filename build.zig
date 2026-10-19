//! Build script for Liburing (Zig 0.17)
//!
//!   zig build          the `liburing` extension and its stubs (`liburing.pyi`) into zig-out/lib/
//!   zig build develop  also copy both into src/liburing/ (for `pytest` from a checkout)
//!   zig build stubs    write the type stubs to src/liburing/liburing.pyi
//!   zig build setu-build-check   check that tools/setu_build.py is the pinned Setu's copy
//!
//! Options:
//!   -Dfree-threaded=false   build for the regular (GIL) 3.15 instead of 3.15t
//!   -Drelease               ReleaseSafe (wheels use it, as PyOZ did); `-Doptimize=...` picks any mode
//!   -Dstrip                 drop debug info from the extension (wheels use it)
//!   -Dext-suffix=...        Python extension suffix (default: CPython's `EXT_SUFFIX` for the target and ABI)
//!
//! Wheels are built by `tools/setu_build.py` (the PEP 517 backend), not by a step here.
const std = @import("std");
const zon = @import("build.zig.zon");

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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // `-Drelease` (what `tools/setu_build.py` passes) is ReleaseSafe: a bug hit from Python stops the
    // process instead of corrupting memory.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });
    const strip = b.option(bool, "strip", "Strip debug symbols from the binary") orelse false;
    const free_threaded = b.option(bool, "free-threaded", "Build for free-threaded 3.15t (default: true)") orelse
        true;
    const ext_suffix = b.option([]const u8, "ext-suffix", "Python extension module suffix") orelse
        defaultSuffix(b, target.result, free_threaded);

    // `./configure` generates `compat.h` and `io_uring_version.h` (feature checks, not CPU specific),
    // so it runs on the build machine for every target. It runs on every build (0.4 s): the build
    // script itself is cached, and the headers must follow the `lib/liburing` checkout.
    const configure = b.addSystemCommand(&.{ "./configure", "--use-libc" });
    configure.setCwd(b.path("lib/liburing"));
    configure.has_side_effects = true; // writes the headers into lib/liburing (git-ignored there)
    _ = configure.captureStdOut(.{});

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
    liburing_c.step.dependOn(&configure.step);

    const c_mod = cModule(b, target, optimize, &configure.step);

    const setu_dep = b.dependency("setu", .{});
    const options = b.addOptions();
    options.addOption(bool, "free_threaded", free_threaded);
    options.addOption([:0]const u8, "version", zon.version);

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

    // Type stubs, generated on the build machine (`src/liburing/stubgen.zig`).
    const stubgen = b.addExecutable(.{
        .name = "stubgen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/liburing/stubgen.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "setu", .module = setu_dep.module("setu") },
                .{ .name = "c", .module = cModule(b, b.graph.host, .Debug, &configure.step) },
            },
        }),
    });
    const pyi = b.addRunArtifact(stubgen).captureStdOut(.{ .basename = "liburing.pyi" });
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(pyi, .lib, "liburing.pyi").step);
    const pyi_copy = b.addInstallFileWithDir(pyi, .{ .custom = "../src/liburing" }, "liburing.pyi");
    b.step("stubs", "Write the type stubs to src/liburing/liburing.pyi").dependOn(&pyi_copy.step);

    // `tools/setu_build.py` must be the copy in the pinned Setu (it is kept there).
    const same_script = b.addSystemCommand(&.{"cmp"});
    same_script.addFileArg(setu_dep.path("tools/setu_build.py"));
    same_script.addFileArg(b.path("tools/setu_build.py"));
    b.step("setu-build-check", "Check that tools/setu_build.py is the pinned Setu's copy").dependOn(&same_script.step);

    const develop = b.step("develop", "Copy the extension and its stubs into src/liburing/");
    develop.dependOn(&b.addInstallFileWithDir(ext.getEmittedBin(), .{ .custom = "../src/liburing" }, ext_name).step);
    develop.dependOn(&pyi_copy.step);
}

/// The C headers (`src/liburing/c.h`) as a Zig module for `target` (`@import("c")`); `@cImport`
/// no longer exists in Zig 0.17.
fn cModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    configure: *std.Build.Step,
) *std.Build.Module {
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/liburing/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.step.dependOn(configure);
    translate_c.addIncludePath(b.path("lib/liburing/src/include"));
    // Bodies translate-c can not translate (liburing's atomics) become `extern`s from `ffi.c`.
    const c_externs = b.addRunArtifact(b.addExecutable(.{
        .name = "c_externs",
        .root_module = b.createModule(.{ .root_source_file = b.path("tools/c_externs.zig"), .target = b.graph.host }),
    }));
    c_externs.addFileArg(translate_c.getOutput());
    return b.createModule(.{
        .root_source_file = c_externs.addOutputFileArg("c.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
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
