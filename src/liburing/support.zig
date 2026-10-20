//! `UnsupportedError`: tells "this kernel has no `IORING_REGISTER_X`" apart from a bad argument. The kernel
//! says `EINVAL` for both, so only after a call failed (never on success) the kernel is asked, once, what
//! it supports: `IORING_REGISTER_QUERY` when it has it, else the table of the kernel each opcode came in.
const std = @import("std");
const setu = @import("setu");
const c = @import("c.zig").c;
const consts = @import("const.zig");

const py = setu.py;
const sc = setu.c;
const Object = sc.Object;

/// `liburing.UnsupportedError`, set by `init`.
var unsupported_error: ?*Object = null;

const doc =
    \\The running kernel does not support this `io_uring` feature (an `OSError` subclass).
    \\
    \\Example
    \\    >>> try:
    \\    ...     io_uring_register_query(Query())
    \\    ... except UnsupportedError as e:
    \\    ...     e.errno, str(e)
    \\    (22, 'Kernel `6.12` does not support `IORING_REGISTER_QUERY`')
    \\
    \\Note
    \\    - `errno` is the kernel's (`EINVAL`, or `EBADF` for a call without a ring on kernels before 6.13).
    \\    - Raised by the `io_uring_register_*` functions and by `io_uring_queue_init*` (setup flags, on kernels
    \\    that have `IORING_REGISTER_QUERY`). An unsupported `IORING_OP_*` fails in its CQE: `probe()` tells.
;

/// Creates `UnsupportedError` (`OSError` subclass) and adds it to `module`.
pub fn init(module: *Object) py.Error!void {
    const exc = sc.PyErr_NewExceptionWithDoc("liburing.UnsupportedError", doc, sc.PyExc_OSError, null) orelse
        return error.PythonError;
    if (sc.PyModule_AddObjectRef(module, "UnsupportedError", exc) < 0) {
        py.decref(exc);
        return error.PythonError;
    }
    unsupported_error = exc; // keeps the reference: the module is never unloaded
}

/// `res` when it is `>= 0`, else `UnsupportedError` when the kernel has no `name` (an `IORING_REGISTER_*`),
/// else `OSError` (`py.checkErrno`).
///
/// Example
///     >>> return support.register("IORING_REGISTER_NAPI", c.io_uring_register_napi(ring, napi));
pub inline fn register(comptime name: [:0]const u8, res: c_int) py.Error!c_int {
    if (res >= 0) return res;
    return registerFailed(name, @field(c, name), res);
}

/// `register` for a raw `io_uring_register(fd, opcode, ...)`: the name is `register opcode N`.
pub inline fn registerOp(opcode: u32, res: c_int) py.Error!c_int {
    if (res >= 0) return res;
    const op = opcode & ~@as(u32, c.IORING_REGISTER_USE_REGISTERED_RING);
    var buf: [32]u8 = undefined;
    return registerFailed(std.fmt.bufPrint(&buf, "register opcode {d}", .{op}) catch &buf, op, res);
}

fn registerFailed(name: []const u8, op: u32, res: c_int) py.Error {
    @branchHint(.cold);
    // An opcode the kernel doesn't know is rejected before its arguments are read: any of these.
    if ((res == -EINVAL or res == -EBADF or res == -EOPNOTSUPP) and !registerSupported(op)) return unsupported(name, res);
    _ = try py.checkErrno(res);
    unreachable; // `res < 0` always raises
}

/// `res` when it is `>= 0`, else `UnsupportedError` when `flags` has an `IORING_SETUP_*` the kernel lacks
/// (known only on kernels with `IORING_REGISTER_QUERY`), else `OSError`.
pub inline fn setup(res: c_int, flags: u32) py.Error!c_int {
    if (res >= 0) return res;
    return setupFailed(res, flags);
}

fn setupFailed(res: c_int, flags: u32) py.Error {
    @branchHint(.cold);
    if (res == -EINVAL) if (queried()) |q| {
        const missing = flags & ~@as(u32, @truncate(q.ring_setup_flags));
        if (missing != 0) {
            var buf: [32]u8 = undefined;
            const name = setupName(missing) orelse std.fmt.bufPrint(&buf, "setup flag 0x{x}", .{missing}) catch &buf;
            return unsupported(name, res);
        }
    };
    _ = try py.checkErrno(res);
    unreachable;
}

const EINVAL: c_int = @backingInt(std.os.linux.E.INVAL);
const EBADF: c_int = @backingInt(std.os.linux.E.BADF);
const EOPNOTSUPP: c_int = @backingInt(std.os.linux.E.OPNOTSUPP);

fn unsupported(name: []const u8, res: c_int) py.Error {
    const k = kernel();
    var buf: [128]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "Kernel `{d}.{d}` does not support `{s}`", .{ k >> 8, k & 0xff, name }) catch &buf;
    return py.raiseWith(unsupported_error.?, .{ -res, msg });
}

/// Does the running kernel know register opcode `op`?
pub fn registerSupported(op: u32) bool {
    if (queried()) |q| return op < q.nr_register_opcodes; // opcodes are numbered in order
    return op < register_since.len and kernel() >= register_since[op];
}

/// The kernel each `IORING_REGISTER_*` opcode came in (`major << 8 | minor`, from `man io_uring_register`).
/// Only read on kernels without `IORING_REGISTER_QUERY` (35): what came after it, `QUERY` reports.
const register_since = [_]u16{
    v(5, 1), v(5, 1), v(5, 1), v(5, 1), // 0-3   BUFFERS, UNREGISTER_BUFFERS, FILES, UNREGISTER_FILES
    v(5, 2), v(5, 2), v(5, 5), v(5, 6), // 4-7   EVENTFD, UNREGISTER_EVENTFD, FILES_UPDATE, EVENTFD_ASYNC
    v(5, 6), v(5, 6), v(5, 6), v(5, 10), // 8-11  PROBE, PERSONALITY, UNREGISTER_PERSONALITY, RESTRICTIONS
    v(5, 10), v(5, 13), v(5, 13), v(5, 13), // 12-15 ENABLE_RINGS, FILES2, FILES_UPDATE2, BUFFERS2
    v(5, 13), v(5, 14), v(5, 14), v(5, 15), // 16-19 BUFFERS_UPDATE, IOWQ_AFF, UNREGISTER_IOWQ_AFF, IOWQ_MAX_WORKERS
    v(5, 18), v(5, 18), v(5, 19), v(5, 19), // 20-23 RING_FDS, UNREGISTER_RING_FDS, PBUF_RING, UNREGISTER_PBUF_RING
    v(6, 0), v(6, 0), v(6, 8), v(6, 9), // 24-27 SYNC_CANCEL, FILE_ALLOC_RANGE, PBUF_STATUS, NAPI
    v(6, 9), v(6, 12), v(6, 12), v(6, 13), // 28-31 UNREGISTER_NAPI, CLOCK, CLONE_BUFFERS, SEND_MSG_RING
    v(6, 15), v(6, 13), v(6, 13), // 32-34 ZCRX_IFQ, RESIZE_RINGS, MEM_REGION
};

fn v(major: u16, minor: u16) u16 {
    return major << 8 | minor;
}

comptime {
    if (register_since.len != c.IORING_REGISTER_QUERY) @compileError("`register_since` must end before `IORING_REGISTER_QUERY`");
}

/// The `IORING_SETUP_*` name of the lowest bit in `flags` (`null` when it has none).
fn setupName(flags: u32) ?[]const u8 {
    const bit = flags & (~flags +% 1);
    @setEvalBranchQuota(100_000);
    inline for (comptime @typeInfo(consts).@"struct".decl_names) |name| {
        if (comptime std.mem.startsWith(u8, name, "IORING_SETUP_")) {
            if (@field(consts, name) == bit) return name;
        }
    }
    return null;
}

var query_state: enum(u8) { unknown, yes, no } = .unknown;
var query_data: c.io_uring_query_opcode = undefined;

/// `IO_URING_QUERY_OPCODES` of the running kernel, or `null` when it has no `IORING_REGISTER_QUERY`.
fn queried() ?*const c.io_uring_query_opcode {
    if (query_state == .unknown) {
        var data = std.mem.zeroes(c.io_uring_query_opcode);
        var hdr = std.mem.zeroes(c.io_uring_query_hdr);
        hdr.query_op = c.IO_URING_QUERY_OPCODES;
        hdr.query_data = @intFromPtr(&data);
        hdr.size = @sizeOf(c.io_uring_query_opcode);
        const ok = c.io_uring_register_query(&hdr) >= 0 and hdr.result == 0;
        if (ok) query_data = data;
        query_state = if (ok) .yes else .no;
    }
    return if (query_state == .yes) &query_data else null;
}

var kernel_version: u16 = 0;

/// The running kernel, `major << 8 | minor` (`uname`).
fn kernel() u16 {
    if (kernel_version == 0) {
        var uts: std.os.linux.utsname = undefined;
        _ = std.os.linux.uname(&uts);
        var it = std.mem.tokenizeAny(u8, std.mem.sliceTo(&uts.release, 0), ".-");
        const major = std.fmt.parseInt(u8, it.next() orelse "0", 10) catch 0;
        const minor = std.fmt.parseInt(u8, it.next() orelse "0", 10) catch 0;
        kernel_version = v(major, minor);
    }
    return kernel_version;
}
