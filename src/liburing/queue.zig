//! Liburing - queue setup, probes and submission queue entries
const c = @import("c");
const setu = @import("setu");
const class = @import("class.zig");
const support = @import("support.zig");
const callReleased = @import("complete.zig").callReleased;
const Ring = @import("ring.zig").Ring;
const RingType = @import("ring.zig").RingType;
const SQEType = @import("sqe.zig").SQEType;

const py = setu.py;
const Object = setu.c.Object;
const SigsetT = class.SigsetT;
const Probe = class.Probe;
const Param = class.Param;

/// Probe which `io_uring` operations `ring`'s kernel supports; use with `io_uring_opcode_supported`.
///
/// Example
///     >>> probe = io_uring_get_probe_ring(ring)
///     ... ...
///     >>> io_uring_free_probe(probe)
///
/// Note
///     - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
///
/// Type
///     return: Probe
pub fn io_uring_get_probe_ring(ring: *Ring) py.Error!*Object {
    if (c.io_uring_get_probe_ring(try ring.checkedPtr())) |p| return class.ProbeType.new(.{ ._io_uring_probe = p });
    return py.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe_ring()`", .{});
}

/// Like `io_uring_get_probe_ring`, without a ring (a temporary one is made for it).
///
/// Example
///     >>> probe = io_uring_get_probe()
///     >>> io_uring_free_probe(probe)
///
/// Note
///     - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
///
/// Type
///     return: Probe
pub fn io_uring_get_probe() py.Error!*Object {
    if (c.io_uring_get_probe()) |p| return class.ProbeType.new(.{ ._io_uring_probe = p });
    return py.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe()`", .{});
}

/// Free `probe` (it is freed on garbage collection too). Calling it again is harmless.
///
/// Example
///     >>> io_uring_free_probe(probe)
pub fn io_uring_free_probe(probe: *Probe) void {
    if (probe._io_uring_probe) |p| {
        c.io_uring_free_probe(p);
        probe._io_uring_probe = null;
    }
}

/// Whether the kernel supports the `IORING_OP_*` opcode `op` (from `probe`).
///
/// Example
///     >>> io_uring_opcode_supported(probe, io_uring_op.IORING_OP_NOP)
///     True
pub fn io_uring_opcode_supported(probe: *Probe, op: i32) bool {
    return (c.io_uring_opcode_supported(probe._io_uring_probe, op) == 1);
}

/// Setup `Ring` in memory you supply (`IORING_SETUP_NO_MMAP`). Returns the bytes of `buf` it used.
/// `RuntimeError` if `ring` is already initialized.
///
/// Example
///     >>> import mmap
///     >>> ring = Ring()
///     >>> buf = mmap.mmap(-1, 2 * 1024 * 1024)  # page aligned and zeroed
///     >>> try:
///     ...     io_uring_queue_init_mem(8, ring, Param(), buf)
///     ...     # do stuff ...
///     >>> finally:
///     ...     io_uring_queue_exit(ring)
///
/// Note
///     - `buf` must be page aligned and zeroed: `mmap.mmap(-1, size)` is both, a `bytearray` is not
///     (`OSError: EINVAL`). `buf=None` lets liburing allocate the memory.
///     - `ring` holds on to `buf` until `io_uring_queue_exit`: it can not be closed or resized
///     (`BufferError`) while the kernel uses it.
pub fn io_uring_queue_init_mem(entries: u32, ring: *Ring, p: *Param, buf: ?py.WritableBuffer) py.Error!i32 {
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError(
        "`io_uring_queue_init_mem(ring)` already initialized!",
        .{},
    );
    ring.ownByCaller();
    // Own view: the argument's is released after the call, this one at `io_uring_queue_exit`.
    const mem: ?py.WritableBuffer = if (buf) |b| try b.take() else null;
    errdefer if (mem) |m| m.deinit();
    const ptr: ?*anyopaque = if (mem) |m| m.data.ptr else null;
    const used = try support.setup(
        c.io_uring_queue_init_mem(entries, &ring._io_uring, &p._io_uring_params, ptr, if (mem) |m| m.data.len else 0),
        p._io_uring_params.flags,
    );
    ring._mem = mem;
    return used;
}

/// Setup `Ring` like `io_uring_queue_init` but with a `Param`, which lets the caller pass
/// setup flags in and read back what the kernel actually gave.
///
/// Note
///     - The kernel fills `param` in on success: `sq_entries`, `cq_entries` (defaults to `2x`
///     `sq_entries`), `features` and `flags` (liburing may add its own, e.g. `IORING_SETUP_NO_SQARRAY`).
///     - `entries` is rounded up to a power of `2` and must be `1-32768`, unless
///     `IORING_SETUP_CLAMP` is set, which caps it instead of raising `OSError`.
///     - `IORING_SETUP_DEFER_TASKRUN` requires `IORING_SETUP_SINGLE_ISSUER`.
///
/// Example
///     >>> ring = Ring()
///     >>> param = Param()
///     >>> param.flags = IORING_SETUP_SINGLE_ISSUER
///     >>> try:
///     ...     io_uring_queue_init_params(1024, ring, param)
///     ...     param.sq_entries
///     1024
///     ...     # do stuff ...
///     >>> finally:
///     ...     io_uring_queue_exit(ring)
pub fn io_uring_queue_init_params(entries: u32, ring: *Ring, param: *Param) py.Error!i32 {
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError(
        "`io_uring_queue_init_params(ring)` already initialized!",
        .{},
    );
    ring.ownByCaller();
    return support.setup(
        c.io_uring_queue_init_params(entries, &ring._io_uring, &param._io_uring_params),
        param._io_uring_params.flags,
    );
}

/// Setup `Ring` Submission & Completion Queues. `flags` are `IORING_SETUP_*` (default `None`: none). Returns `0`;
/// `RuntimeError` if `ring` is already initialized.
///
/// Example
///     >>> ring = Ring()
///     >>> try:
///     ...     io_uring_queue_init(1024, ring)
///     ...     # do stuff ...
///     >>> finally:
///     ...     io_uring_queue_exit(ring)
pub fn io_uring_queue_init(entries: u32, ring: *Ring, flags: ?u32) py.Error!i32 {
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError(
        "`io_uring_queue_init(ring)` already initialized!",
        .{},
    );
    ring.ownByCaller();
    return support.setup(c.io_uring_queue_init(entries, &ring._io_uring, flags orelse 0), flags orelse 0);
}

/// Map the rings of an `io_uring` file descriptor `fd` (from `io_uring_setup`, with the same `param`) into
/// `ring`. Returns `0`.
///
/// Example
///     >>> param = Param()
///     >>> fd = io_uring_setup(8, param)
///     >>> ring = Ring()
///     >>> io_uring_queue_mmap(fd, ring, param)
///     0
pub fn io_uring_queue_mmap(fd: i32, ring: *Ring, param: *Param) py.Error!i32 {
    if (ring._io_uring.ring_fd > 0) try ring.checkThread();
    ring.ownByCaller();
    return py.checkErrno(c.io_uring_queue_mmap(fd, &param._io_uring_params, &ring._io_uring));
}

/// Apply `madvise(MADV_DONTFORK)` to `ring`'s SQE array, SQ ring and CQ ring, so they are
/// not mapped into a child process after `fork()`.
///
/// By default the rings are `MAP_SHARED`, so a forked child shares them with the parent and both
/// could submit/reap on the same queue. After this call the child simply has no such memory:
/// touching `ring` in the child (e.g. `io_uring_get_sqe`) crashes it with `SIGSEGV`.
/// The parent is not affected and keeps using `ring` as normal.
///
/// Note
///     - `ring` must be initialized, else raises `RuntimeError`.
///
/// Example
///     >>> io_uring_ring_dontfork(ring)
///     0
pub fn io_uring_ring_dontfork(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_ring_dontfork(try ring.checkedPtr()));
}

/// Tear down `ring`: unmap its Submission & Completion Queues and close its `fd`.
///
/// Note
///     - Raises `RuntimeError` if `ring` is not initialized or already exited.
///     - Requests still in flight are cancelled and waited for first.
///
/// Example
///     >>> io_uring_queue_exit(ring)
pub fn io_uring_queue_exit(ring: *Ring) py.Error!void {
    if (ring._io_uring.ring_fd > 0) {
        try ring.checkThread(); // not under the owner while it waits in the kernel
        ring.drainRequests(); // requests in flight: cancelled and completed before what they hold is released
        c.io_uring_queue_exit(&ring._io_uring);
        ring._io_uring.ring_fd = 0;
        if (ring._mem) |m| m.deinit(); // the kernel is done with it
        ring._mem = null;
        ring.clearTable(); // nothing in flight any more
        ring.releaseKernelBuffers(); // the kernel let go of them with the exit
    } else return py.raiseRuntimeError("`io_uring_queue_exit(ring)` not initialized or already exited!", .{});
}

/// Resize `ring`'s submission and completion queues to what `p` says (`p.sq_entries`, `p.cq_entries` with
/// `IORING_SETUP_CQSIZE`). Returns `0`; `UnsupportedError` before Linux 6.13.
///
/// Note
///     - `ring` must be set up with `IORING_SETUP_DEFER_TASKRUN | IORING_SETUP_SINGLE_ISSUER`.
///
/// Example
///     >>> p = Param()
///     >>> p.sq_entries = 64
///     >>> p.cq_entries = 128
///     >>> p.flags = IORING_SETUP_CQSIZE
///     >>> io_uring_resize_rings(ring, p)
///     0
pub fn io_uring_resize_rings(ring: *Ring, p: *Param) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_RESIZE_RINGS",
        c.io_uring_resize_rings(try ring.checkedPtr(), &p._io_uring_params),
    );
}

/// The raw `io_uring_enter(2)` system call on `fd`: submit `to_submit` entries and wait for `min_complete`
/// completions, `flags` are `IORING_ENTER_*`, `sig` an optional `SigsetT`. Returns the number of entries consumed.
///
/// Example
///     >>> io_uring_enter(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, None)
///     0
///
/// Note
///     - Other Python threads run while it waits (`min_complete > 0`).
pub fn io_uring_enter(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sig: ?*SigsetT) py.Error!i32 {
    const args = .{ fd, to_submit, min_complete, flags, if (sig) |s| s._sigset_t else null };
    if (min_complete == 0) return py.checkErrno(@call(.auto, c.io_uring_enter, args));
    return py.checkErrno(callReleased(c.io_uring_enter, args));
}

/// `io_uring_enter` with the size `sz` of the argument at address `arg` (`IORING_ENTER_EXT_ARG`: a
/// `struct io_uring_getevents_arg`, or with `IORING_ENTER_EXT_ARG_REG` an offset into a registered region); `arg`
/// default `None`: no argument.
///
/// Example
///     >>> io_uring_enter2(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, 0)
///     0
pub fn io_uring_enter2(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sz: usize, arg: ?usize) py.Error!i32 {
    const args = .{ fd, to_submit, min_complete, flags, if (arg) |a| @as(?*anyopaque, @ptrFromInt(a)) else null, sz };
    if (min_complete == 0) return py.checkErrno(@call(.auto, c.io_uring_enter2, args));
    return py.checkErrno(callReleased(c.io_uring_enter2, args));
}

/// The raw `io_uring_setup(2)` system call: makes a ring of `entries` as `p` says, `p` is filled in with what the
/// kernel gave. Returns the file descriptor (use it with `io_uring_queue_mmap`).
///
/// Example
///     >>> p = Param()
///     >>> fd = io_uring_setup(8, p)
pub fn io_uring_setup(entries: u32, p: *Param) py.Error!i32 {
    return support.setup(c.io_uring_setup(entries, &p._io_uring_params), p._io_uring_params.flags);
}

/// The raw `io_uring_register(2)` system call on `fd`: `opcode` is an `IORING_REGISTER_*`, `nr_args` the number of
/// arguments at address `arg` (default `None`: none). Returns the call's result; `UnsupportedError` if the kernel
/// does not know `opcode`.
///
/// Example
///     >>> io_uring_register(ring.ring_fd, 9, 0, None)  # IORING_REGISTER_PERSONALITY
///     1
pub fn io_uring_register(fd: u32, opcode: u32, nr_args: u32, arg: ?usize) py.Error!i32 {
    return support.registerOp(opcode, c.io_uring_register(fd, opcode, if (arg) |a| @ptrFromInt(a) else null, nr_args));
}

/// Turn the iowait accounting of a task waiting for completions on (`True`, what a new ring does) or off
/// (`False`). Returns `0`; `UnsupportedError` without `IORING_FEAT_NO_IOWAIT` (Linux 6.15+).
///
/// Example
///     >>> io_uring_set_iowait(ring, False)
///     0
pub fn io_uring_set_iowait(ring: *Ring, enable_iowait: bool) py.Error!i32 {
    const r = try ring.checkedPtr();
    return support.feature("IORING_FEAT_NO_IOWAIT", r.features, c.io_uring_set_iowait(r, enable_iowait));
}

/// How many entries are queued in the submission queue that the kernel has not consumed yet.
///
/// Example
///     >>> io_uring_sq_ready(ring)
///     0
pub fn io_uring_sq_ready(ring: *Ring) py.Error!u32 {
    return c.io_uring_sq_ready(try ring.checkedPtr());
}

/// How many free entries the submission queue has left.
///
/// Example
///     >>> io_uring_sq_space_left(ring)
///     1024
pub fn io_uring_sq_space_left(ring: *Ring) py.Error!u32 {
    return c.io_uring_sq_space_left(try ring.checkedPtr());
}

/// Bytes the kernel needs to map a ring of `entries` with `flags`.
///
/// Example
///     >>> io_uring_memory_size(8, 0)
///     8192
pub fn io_uring_memory_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_memory_size(entries, flags));
}

/// Bytes the kernel needs to map a ring of `entries` set up as `p` says.
///
/// Example
///     >>> io_uring_memory_size_params(8, Param())
///     8192
pub fn io_uring_memory_size_params(entries: u32, p: *Param) py.Error!isize {
    return py.checkErrno(c.io_uring_memory_size_params(entries, &p._io_uring_params));
}

/// Bytes of locked memory (`RLIMIT_MEMLOCK`) a ring of `entries` with `flags` needs.
///
/// Example
///     >>> io_uring_mlock_size(8, 0)
///     0
///
/// Note
///     - `0` on kernels that no longer count rings against `RLIMIT_MEMLOCK`.
pub fn io_uring_mlock_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size(entries, flags));
}

/// Bytes of locked memory (`RLIMIT_MEMLOCK`) a ring of `entries` set up as `p` says needs.
///
/// Example
///     >>> io_uring_mlock_size_params(8, Param())
///     0
pub fn io_uring_mlock_size_params(entries: u32, p: *Param) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size_params(entries, &p._io_uring_params));
}

/// Wait for room in the submission queue of an `IORING_SETUP_SQPOLL` ring (until its kernel thread consumed
/// entries); returns at once when there is room. Returns the call's result, an error is not raised.
///
/// Example
///     >>> io_uring_sqring_wait(ring)
///     0
pub fn io_uring_sqring_wait(ring: *Ring) py.Error!i32 {
    return callReleased(c.io_uring_sqring_wait, .{try ring.checkedPtr()}); // `SQPOLL`: until the SQ has room
}

/// Get the next free entry of the submission queue to prep a request on.
///
/// Example
///     >>> if sqe := io_uring_get_sqe(ring):
///     ...   # do stuff...
///
/// Note
///     - `None` when the submission queue is full: `io_uring_submit(ring)` and try again, or let the ring do it
///       (`Ring(auto_submit=True)`). Set a request's link flags before taking the next entry: the
///       ring submits only when the last queued request does not link on.
///
/// Type
///     return: SQE | None
pub fn io_uring_get_sqe(ring: *Ring) py.Error!?*Object {
    const r = try ring.checkedPtr();
    if (c.io_uring_get_sqe(r) orelse if (try ring.autoSubmit()) c.io_uring_get_sqe(r) else null) |sqe| {
        return try SQEType.new(.{ ._sqe = sqe, ._owner = class.keep(RingType.object(ring)), ._gen = ring._gen });
    }
    return null; // None
}

/// An entry that takes two slots (128 bytes) of the submission queue, for `io_uring_prep_nop128` and
/// `io_uring_prep_uring_cmd128`; on a ring set up with `IORING_SETUP_SQE128` it is the same as `io_uring_get_sqe`.
///
/// Example
///     >>> if sqe := io_uring_get_sqe128(ring):
///     ...   io_uring_prep_nop128(sqe)
///
/// Type
///     return: SQE | None
pub fn io_uring_get_sqe128(ring: *Ring) py.Error!?*Object {
    const r = try ring.checkedPtr();
    if (c.io_uring_get_sqe128(r) orelse if (try ring.autoSubmit()) c.io_uring_get_sqe128(r) else null) |sqe| {
        return try SQEType.new(.{ ._sqe = sqe, ._owner = class.keep(RingType.object(ring)), ._gen = ring._gen });
    }
    return null; // None
}

/// Liburing Version Major
///
/// Example
///     >>> liburing_version_major()
///     2
///
/// Note
///     - `io_uring_major_version` has been renamed to `liburing_version_major`
pub fn liburing_version_major() i32 {
    return c.io_uring_major_version();
}

/// Liburing Version Minor
///
/// Example
///     >>> liburing_version_minor()
///     15
///
/// Note
///     - `io_uring_minor_version` has been renamed to `liburing_version_minor`
pub fn liburing_version_minor() i32 {
    return c.io_uring_minor_version();
}

/// Liburing Version Check: `True` if the liburing in use is older than `major.minor`, else `False`.
///
/// Example
///     >>> liburing_version_check(99, 0)
///     True
///     >>> liburing_version_check(2, 0)
///     False
///
/// Note
///     - `io_uring_check_version` has been renamed to `liburing_version_check`
pub fn liburing_version_check(major: u16, minor: u16) bool {
    return c.io_uring_check_version(major, minor);
}
