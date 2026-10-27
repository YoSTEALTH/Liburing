//! Liburing: the `liburing` extension module (Setu's `py.exportModule`).
const setu = @import("setu");
const build_options = @import("build_options");
const support = @import("support.zig");

const Object = setu.c.Object;

/// Setu finds the functions (lowercase `pub fn`, needs `.source`), `setu.Class`es, `UnsupportedError`, UPPER_CASE
/// constants and `enum.zig`'s `IntEnum`s in `from`, creates them (bases first) in its `exec`, adds `__version__`,
/// then runs `init`. `zig build stubs` writes `__init__.pyi` from this declaration too.
pub const module: setu.Module = .{
    .name = "liburing",
    .doc = "Python + Zig wrapper around C liburing.",
    .version = build_options.version,
    .from = &.{
        .{ .ns = @import("const.zig") }, // constants only (`LIBURING_HAVE_DATA64 = ""` included)
        .{ .ns = @import("enum.zig"), .enums = .int_enum }, // `io_uring_op`, `io_uring_socket_op`
        .{ .ns = @import("class.zig"), .functions = false }, // 6 classes; `keep` / `claim` are Zig helpers
        .{ .ns = @import("ring.zig") }, // class-only files: no `.source` needed
        .{ .ns = @import("cqe.zig") },
        .{ .ns = @import("sqe.zig") },
        .{ .ns = @import("msghdr.zig") },
        .{ .ns = @import("statx.zig") }, // `Statx` + `STATX_*`
        .{ .ns = @import("futex.zig") }, // `FUTEX` / `Futex` + `FUTEX_*`
        .{ .ns = support, .functions = false }, // `UnsupportedError`; its `pub fn`s are Zig helpers
        .{ .ns = @import("error.zig"), .source = @embedFile("error.zig") },
        .{ .ns = @import("helper.zig"), .source = @embedFile("helper.zig") }, // + `FileIndex`, `FileIndexIter`
        .{ .ns = @import("queue.zig"), .source = @embedFile("queue.zig") },
        .{ .ns = @import("complete.zig"), .source = @embedFile("complete.zig") },
        .{ .ns = @import("register.zig"), .source = @embedFile("register.zig") }, // + 12 classes
        .{ .ns = @import("prep_file.zig"), .source = @embedFile("prep_file.zig") },
        .{ .ns = @import("prep_net.zig"), .source = @embedFile("prep_net.zig") },
        .{ .ns = @import("prep_ctl.zig"), .source = @embedFile("prep_ctl.zig") },
        .{ .ns = @import("socket.zig"), .source = @embedFile("socket.zig") }, // + `Sockaddr`, `AF_*`, ...
    },
    .init = init,
};

/// After Setu's part: asks the kernel once what it supports (`IORING_REGISTER_QUERY`, `uname`).
fn init(_: *Object) setu.py.Error!void {
    support.init();
}

// `PyModExport_liburing` (3.15+) and `PyInit_liburing` (3.14), one stable-ABI binary. Setu's default `gil`
// (`Py_MOD_GIL_NOT_USED`): the free-threaded CPython keeps the GIL off.
comptime {
    setu.py.exportModule(module);
}
