//! Liburing - io_uring related classes
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");

const py = setu.py;
const Object = setu.c.Object;
pub const TimespecType = setu.Class(Timespec, @embedFile("class.zig"));
pub const ProbeType = setu.Class(Probe, @embedFile("class.zig"));
pub const ParamType = setu.Class(Param, @embedFile("class.zig"));
pub const SigsetTType = setu.Class(SigsetT, @embedFile("class.zig"));
pub const SiginfoTType = setu.Class(SiginfoT, @embedFile("class.zig"));
pub const OpenHowType = setu.Class(OpenHow, @embedFile("class.zig"));

/// Kernel Timespec
///
/// Example
///     >>> ts = timespec(2)
///     >>> ts.sec
///     2
///     >>> ts.nsec
///     0
///     >>> ts.sec = 1           # second
///     >>> ts.nsec = 500000000  # nanosecond
///
/// Note
///     - Takes no arguments (`TypeError` for any): use `timespec(second)` to make one from seconds.
pub const Timespec = struct {
    _timespec: ?*c.__kernel_timespec = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *const Self) void {
        if (self._timespec) |ts| std.heap.c_allocator.destroy(ts);
    }

    // Get

    /// Whole seconds.
    pub fn get_sec(self: *const Self) py.Error!i64 {
        if (self._timespec) |ts| return ts.tv_sec;
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    /// Nanoseconds, after the whole seconds.
    pub fn get_nsec(self: *const Self) py.Error!i64 {
        if (self._timespec) |ts| return ts.tv_nsec;
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    // Set

    pub fn set_sec(self: *const Self, value: i64) py.Error!void {
        if (self._timespec) |ts| {
            ts.tv_sec = value;
            return;
        }
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    pub fn set_nsec(self: *const Self, value: i64) py.Error!void {
        if (self._timespec) |ts| {
            ts.tv_nsec = value;
            return;
        }
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }
};

/// Result of `io_uring_get_probe` / `io_uring_get_probe_ring`: which `io_uring` operations the kernel supports.
///
/// Example
///     >>> probe = io_uring_get_probe()
///     >>> probe.last_op, probe.ops_len
///     (64, 65)
///     >>> io_uring_opcode_supported(probe, io_uring_op.IORING_OP_NOP)
///     True
///     >>> io_uring_free_probe(probe)
///
/// Note
///     - Can not be created directly (`NotImplementedError`), the `io_uring_get_probe*` functions make it.
///     - Reading `last_op` / `ops_len` after `io_uring_free_probe` raises `MemoryError`.
pub const Probe = struct {
    _io_uring_probe: ?*c.io_uring_probe = null,

    const Self = @This();

    pub fn __new__(_: *Self) py.Error!void {
        return py.raiseNotImplementedError("`Probe()`", .{});
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_probe) |p| c.io_uring_free_probe(p); // clean up in case user forgot to do so!
    }

    /// The last `IORING_OP_*` the kernel knows.
    pub fn get_last_op(self: *const Self) py.Error!u8 {
        if (self._io_uring_probe) |p| return p.last_op;
        return e.raiseMemoryError("`Probe()` is null!");
    }

    /// How many opcodes the probe reports on.
    pub fn get_ops_len(self: *const Self) py.Error!u8 {
        if (self._io_uring_probe) |p| return p.ops_len;
        return e.raiseMemoryError("`Probe()` is null!");
    }
};

/// `io_uring` setup parameters (`struct io_uring_params`): set `flags` and the sizes before
/// `io_uring_queue_init_params` / `io_uring_setup`, read back what the kernel gave after.
///
/// Example
///     >>> ring = Ring()
///     >>> param = Param()
///     >>> param.flags = IORING_SETUP_CQSIZE
///     >>> param.cq_entries = 256
///     >>> io_uring_queue_init_params(8, ring, param)
///     0
///     >>> param.sq_entries, param.cq_entries
///     (8, 256)
///     >>> io_uring_queue_exit(ring)
///
/// Note
///     - Takes no arguments (`TypeError` for any). `features` is read only.
pub const Param = struct {
    _io_uring_params: c.io_uring_params = std.mem.zeroes(c.io_uring_params), // lives inside the Python object

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// Submission queue entries (filled in by the kernel).
    pub fn get_sq_entries(self: *const Self) u32 {
        return self._io_uring_params.sq_entries;
    }

    pub fn set_sq_entries(self: *Self, value: u32) void {
        self._io_uring_params.sq_entries = value;
    }

    /// Completion queue entries (set it with `IORING_SETUP_CQSIZE`, else the kernel fills it in).
    pub fn get_cq_entries(self: *const Self) u32 {
        return self._io_uring_params.cq_entries;
    }

    pub fn set_cq_entries(self: *Self, value: u32) void {
        self._io_uring_params.cq_entries = value;
    }

    /// `IORING_SETUP_*` flags.
    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_params.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_params.flags = value;
    }

    /// CPU the `IORING_SETUP_SQPOLL` thread is bound to (with `IORING_SETUP_SQ_AFF`).
    pub fn get_sq_thread_cpu(self: *const Self) u32 {
        return self._io_uring_params.sq_thread_cpu;
    }

    pub fn set_sq_thread_cpu(self: *Self, value: u32) void {
        self._io_uring_params.sq_thread_cpu = value;
    }

    /// Milliseconds the `IORING_SETUP_SQPOLL` thread idles before it sleeps.
    pub fn get_sq_thread_idle(self: *const Self) u32 {
        return self._io_uring_params.sq_thread_idle;
    }

    pub fn set_sq_thread_idle(self: *Self, value: u32) void {
        self._io_uring_params.sq_thread_idle = value;
    }

    /// `IORING_FEAT_*` flags the kernel reports (read only).
    pub fn get_features(self: *const Self) u32 {
        return self._io_uring_params.features;
    }

    /// Ring file descriptor whose worker pool to share (with `IORING_SETUP_ATTACH_WQ`).
    pub fn get_wq_fd(self: *const Self) u32 {
        return self._io_uring_params.wq_fd;
    }

    pub fn set_wq_fd(self: *Self, value: u32) void {
        self._io_uring_params.wq_fd = value;
    }
};

/// Signal set (`sigset_t`), e.g. for `sigmask` of wait functions.
///
/// Example
///     >>> mask = SigsetT([signal.SIGINT, signal.SIGTERM])
///     >>> mask = SigsetT()  # empty set
///
/// Note
///     - `ValueError` for an invalid signal number.
pub const SigsetT = struct {
    _sigset_t: ?*c.__sigset_t = null,

    const Self = @This();

    pub fn __new__(self: *Self, signals: ?py.Sequence(i32)) py.Error!void {
        const set = std.heap.c_allocator.create(c.__sigset_t) catch return e.raiseMemoryError("Out of Memory!");
        _ = c.sigemptyset(set);
        if (signals) |list| for (list.items) |signum| {
            if (c.sigaddset(set, signum) != 0) {
                std.heap.c_allocator.destroy(set);
                return py.raiseValueError("`SigsetT(signals)` - invalid signal {d}", .{signum});
            }
        };
        self._sigset_t = set;
    }

    pub fn __del__(self: *Self) void {
        if (self._sigset_t) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// Signal information (`siginfo_t`), filled by the kernel, e.g. `infop` of `io_uring_prep_waitid`.
///
/// Example
///     >>> pid = os.posix_spawn('/bin/sh', ['sh', '-c', 'exit 7'], os.environ)
///     >>> info = SiginfoT()
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_waitid(sqe, os.P_PID, pid, info, os.WEXITED)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> info.si_pid == pid, info.si_code == os.CLD_EXITED, info.si_status
///     (True, True, 7)
///
/// Note
///     - The kernel writes it at the completion: the request holds it until then.
pub const SiginfoT = struct {
    _siginfo_t: c.siginfo_t = std.mem.zeroes(c.siginfo_t),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// Signal number.
    pub fn get_si_signo(self: *const Self) i32 {
        return self._siginfo_t.si_signo;
    }

    /// Errno value, if any.
    pub fn get_si_errno(self: *const Self) i32 {
        return self._siginfo_t.si_errno;
    }

    /// Signal code (e.g. `os.CLD_EXITED`).
    pub fn get_si_code(self: *const Self) i32 {
        return self._siginfo_t.si_code;
    }

    /// Process id of the child (`SIGCHLD` / `waitid` info).
    pub fn get_si_pid(self: *const Self) i32 {
        return self._siginfo_t._sifields._sigchld.si_pid;
    }

    /// Real user id of the child (`SIGCHLD` / `waitid` info).
    pub fn get_si_uid(self: *const Self) u32 {
        return self._siginfo_t._sifields._sigchld.si_uid;
    }

    /// Exit status (`si_code == CLD_EXITED`) or signal number (killed, stopped, ...).
    pub fn get_si_status(self: *const Self) i32 {
        return self._siginfo_t._sifields._sigchld.si_status;
    }
};

pub fn writableView(o: *Object, view: *setu.c.Buffer) py.Error!bool {
    if (setu.c.PyObject_GetBuffer(o, view, setu.c.PyBUF_WRITABLE) == 0) return true;
    setu.c.PyErr_Clear();
    if (setu.c.PyObject_GetBuffer(o, view, setu.c.PyBUF_SIMPLE) < 0) return error.PythonError;
    return false;
}

/// How to Open a Path
///
/// Example
///     >>> how = OpenHow(O_CREAT | O_RDWR, 0o777, RESOLVE_CACHED)
///     >>> io_uring_prep_openat2(sqe, 'file.txt', how)
///     True
///
///     # or
///
///     >>> how = OpenHow()
///     >>> how.flags   = O_CREAT | O_RDWR
///     >>> how.mode    = 0
///     >>> how.resolve = RESOLVE_CACHED
///     >>> io_uring_prep_openat2(sqe, 'file.txt', how)
///     True
///
/// Flags
///     O_CREAT
///     O_RDWR
///     O_RDONLY
///     O_WRONLY
///     O_TMPFILE
///     ...
///
/// Resolve
///     RESOLVE_BENEATH
///     RESOLVE_IN_ROOT
///     RESOLVE_NO_MAGICLINKS
///     RESOLVE_NO_SYMLINKS
///     RESOLVE_NO_XDEV
///     RESOLVE_CACHED
///
/// Note
///     - `mode` is only to set when creating new or temp file.
///     - You can use same `OpenHow()` reference if opening multiple files with same settings.
pub const OpenHow = struct {
    _open_how: c.open_how = std.mem.zeroes(c.open_how), // lives inside the Python object

    const Self = @This();

    /// `OpenHow(flags=None, mode=None, resolve=None)`: each defaults to `0`.
    pub fn __new__(self: *Self, flags: ?u64, mode: ?u64, resolve: ?u64) void {
        self._open_how.flags = flags orelse 0;
        self._open_how.mode = mode orelse 0;
        self._open_how.resolve = resolve orelse 0;
    }

    pub fn __repr__(self: *const Self) py.Error!*Object {
        var buf: [96]u8 = undefined;
        const text = std.mem.print(&buf, "OpenHow(flags={d}, mode={d}, resolve={d})", .{
            self._open_how.flags,
            self._open_how.mode,
            self._open_how.resolve,
        }) catch unreachable; // three u64s fit
        return py.new(text);
    }

    // Get
    // ---

    pub fn get_flags(self: *const Self) u64 {
        return self._open_how.flags;
    }

    pub fn get_mode(self: *const Self) u64 {
        return self._open_how.mode;
    }

    pub fn get_resolve(self: *const Self) u64 {
        return self._open_how.resolve;
    }

    // Set
    // ---

    pub fn set_flags(self: *Self, value: u64) void {
        self._open_how.flags = value;
    }

    pub fn set_mode(self: *Self, value: u64) void {
        self._open_how.mode = value;
    }

    pub fn set_resolve(self: *Self, value: u64) void {
        self._open_how.resolve = value;
    }
};

/// Points the owned field `field` at `obj` (a new reference), dropping the old one.
pub fn setOwned(field: *?*Object, obj: *Object) void {
    if (field.* == obj) return;
    const old = field.*;
    field.* = keep(obj);
    py.decref(old);
}

/// The calling thread (libc; the same value in a child after `fork`).
pub extern fn pthread_self() usize;

/// Claims `owner` (a `_thread` field, `0`: no owner yet) for `thread`, atomically: two threads using an object
/// for the first time at once can not both get it. `false` if another thread has it.
pub inline fn claim(owner: *usize, thread: usize) bool {
    const current = @atomicLoad(usize, owner, .monotonic);
    if (current == thread) return true;
    if (current != 0) return false;
    return @cmpxchgStrong(usize, owner, 0, thread, .monotonic, .monotonic) == null;
}

/// `RuntimeError` for a `Cqe`, `CqeBatch` or `Sqe` template used by a thread that does not own it.
pub noinline fn raiseNotOwner(comptime what: []const u8, comptime first: []const u8) py.Error {
    return py.raiseRuntimeError(
        "`" ++ what ++ "` belongs to the thread of its first " ++ first ++ ": use one per thread",
        .{},
    );
}

/// A new reference to `obj`, for an owned (`?*Object`) field.
pub fn keep(obj: *Object) *Object {
    py.incref(obj);
    return obj;
}
