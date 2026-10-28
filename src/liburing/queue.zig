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
/// Type
///     return: Probe
///
/// Example
///     >>> probe = io_uring_get_probe_ring(ring)
///     >>> io_uring_opcode_supported(probe, io_uring_op.IORING_OP_NOP)
///     True
///     >>> io_uring_free_probe(probe)
///
/// Note
///     - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
///     - Linux 5.6+ (`IORING_REGISTER_PROBE`), else `RuntimeError`.
pub fn io_uring_get_probe_ring(ring: *Ring) py.Error!*Object {
    if (c.io_uring_get_probe_ring(try ring.checkedPtr())) |p| return class.ProbeType.new(.{ ._io_uring_probe = p });
    // coverage-off: Linux 5.6+ always has the probe
    return py.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe_ring()`", .{});
    // coverage-on
}

/// Like `io_uring_get_probe_ring`, without a ring (a temporary one is made for it).
///
/// Type
///     return: Probe
///
/// Example
///     >>> probe = io_uring_get_probe()
///     >>> io_uring_free_probe(probe)
///
/// Note
///     - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
///     - Linux 5.6+ (`IORING_REGISTER_PROBE`), else `RuntimeError`.
pub fn io_uring_get_probe() py.Error!*Object {
    if (c.io_uring_get_probe()) |p| return class.ProbeType.new(.{ ._io_uring_probe = p });
    // coverage-off: Linux 5.6+ always has the probe
    return py.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe()`", .{});
    // coverage-on
}

/// Free `probe` (it is freed on garbage collection too). Calling it again is harmless.
///
/// Example
///     >>> probe = io_uring_get_probe()
///     >>> io_uring_free_probe(probe)
///     >>> io_uring_free_probe(probe)  # again: nothing happens
pub fn io_uring_free_probe(probe: *Probe) void {
    if (probe._io_uring_probe) |p| {
        c.io_uring_free_probe(p);
        probe._io_uring_probe = null;
    }
}

/// Whether the kernel supports the `IORING_OP_*` opcode `op` (from `probe`).
///
/// Example
///     >>> probe = io_uring_get_probe()
///     >>> io_uring_opcode_supported(probe, io_uring_op.IORING_OP_NOP)
///     True
///     >>> io_uring_free_probe(probe)
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
///     ... finally:
///     ...     io_uring_queue_exit(ring)
///     ...
///     8192
///
/// Note
///     - `buf` must be page aligned and zeroed: `mmap.mmap(-1, size)` is both, a `bytearray` is not
///     (`OSError: EINVAL`). `buf=None` lets liburing allocate the memory.
///     - `ring` holds on to `buf` until `io_uring_queue_exit`: it can not be closed or resized
///     (`BufferError`) while the kernel uses it.
///     - Linux 6.5+ (`IORING_SETUP_NO_MMAP`). The size to allot: `io_uring_memory_size_params(entries, p)`.
///     - Such a ring can not be resized with `io_uring_resize_rings` (a liburing limitation).
pub fn io_uring_queue_init_mem(entries: u32, ring: *Ring, p: *Param, buf: ?py.WritableBuffer) py.Error!i32 {
    if (ring._ready) return py.raiseRuntimeError(
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
    ring._ready = true;
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
///     - `param.flags`: see `io_uring_queue_init` for the `IORING_SETUP_*` flags and the kernel each needs.
///     - `IORING_SETUP_CQSIZE` sizes the completion queue by `param.cq_entries` (more than `2x` for networked
///       workloads): a full one overflows, which is slow (`io_uring_cq_has_overflow`).
///     - `IORING_SETUP_SQPOLL`: the kernel thread sleeps after `param.sq_thread_idle` ms without work (`0`: never,
///       `io_uring_submit` wakes it); `IORING_SETUP_SQ_AFF` pins it to CPU `param.sq_thread_cpu`. No privileges
///       needed since Linux 5.13 (`OSError: EPERM` before).
///
/// Example
///     >>> ring = Ring()
///     >>> param = Param()
///     >>> param.flags = IORING_SETUP_SINGLE_ISSUER
///     >>> try:
///     ...     io_uring_queue_init_params(1024, ring, param)
///     ...     param.sq_entries
///     ...     # do stuff ...
///     ... finally:
///     ...     io_uring_queue_exit(ring)
///     ...
///     0
///     1024
pub fn io_uring_queue_init_params(entries: u32, ring: *Ring, param: *Param) py.Error!i32 {
    if (ring._ready) return py.raiseRuntimeError(
        "`io_uring_queue_init_params(ring)` already initialized!",
        .{},
    );
    ring.ownByCaller();
    const res = try support.setup(
        c.io_uring_queue_init_params(entries, &ring._io_uring, &param._io_uring_params),
        param._io_uring_params.flags,
    );
    ring._ready = true;
    return res;
}

/// Setup `Ring` Submission & Completion Queues. `flags` are `IORING_SETUP_*` (default `None`: none). Returns `0`;
/// `RuntimeError` if `ring` is already initialized.
///
/// `entries` is the submission queue size (rounded up to a power of `2`, max `32768`): it caps one submit batch, not
/// the requests in flight. The completion queue gets `2x` as many (`io_uring_queue_init_params` to pick).
///
/// Flags
///     IORING_SETUP_IOPOLL                 # busy-poll completions; O_DIRECT files on a polling capable device
///     IORING_SETUP_HYBRID_IOPOLL          # with IOPOLL: sleep a little before polling
///     IORING_SETUP_SQPOLL                 # a kernel thread submits; no syscall per submit
///     IORING_SETUP_SQ_AFF                 # pin the SQPOLL thread to sq_thread_cpu
///     IORING_SETUP_CQSIZE                 # completion queue of cq_entries
///     IORING_SETUP_CLAMP                  # cap too large sizes instead of OSError: EINVAL
///     IORING_SETUP_ATTACH_WQ              # share the worker (and SQPOLL) threads of ring wq_fd
///     IORING_SETUP_R_DISABLED             # Linux 5.10+: start disabled, io_uring_enable_rings later
///     IORING_SETUP_SUBMIT_ALL             # Linux 5.18+: go on submitting a batch after a failed entry
///     IORING_SETUP_COOP_TASKRUN           # Linux 5.19+: no interrupting the task for completion work
///     IORING_SETUP_TASKRUN_FLAG           # Linux 5.19+: IORING_SQ_TASKRUN flags pending completion work
///     IORING_SETUP_SQE128                 # Linux 5.19+: 128 byte entries (IORING_OP_URING_CMD)
///     IORING_SETUP_CQE32                  # Linux 5.19+: 32 byte completions
///     IORING_SETUP_SINGLE_ISSUER          # Linux 6.0+: one thread submits (OSError: EEXIST for another)
///     IORING_SETUP_DEFER_TASKRUN          # Linux 6.1+: completion work only on entering; needs SINGLE_ISSUER
///     IORING_SETUP_NO_MMAP                # Linux 6.5+: caller's memory (io_uring_queue_init_mem)
///     IORING_SETUP_REGISTERED_FD_ONLY     # Linux 6.5+: a registered ring fd only; needs NO_MMAP
///     IORING_SETUP_NO_SQARRAY             # Linux 6.6+: no indirection array (liburing sets it when it can)
///     IORING_SETUP_CQE_MIXED              # Linux 6.18+: 16 and 32 byte completions (io_uring_cqe_nr)
///     IORING_SETUP_SQE_MIXED              # 64 and 128 byte entries (io_uring_get_sqe128)
///     IORING_SETUP_SQ_REWIND              # Linux 7.0+: entries always from index 0; needs NO_SQARRAY
///
/// Example
///     >>> ring = Ring()
///     >>> try:
///     ...     io_uring_queue_init(1024, ring)
///     ...     # do stuff ...
///     ... finally:
///     ...     io_uring_queue_exit(ring)
///     ...
///     0
///
/// Note
///     - A flag the kernel lacks raises `UnsupportedError` (on kernels with `IORING_REGISTER_QUERY`, else
///       `OSError: EINVAL`). `OSError: EPERM`: `io_uring` is disabled (`/proc/sys/kernel/io_uring_disabled`), or
///       `IORING_SETUP_SQPOLL` without privileges before Linux 5.13; `OSError: ENOMEM`: out of locked memory
///       (`RLIMIT_MEMLOCK`, kernels before 5.12).
///     - `IORING_SETUP_IOPOLL` allows few opcodes (`NOP`, `READ*`/`WRITE*`, `URING_CMD`, ...) and needs the device
///       set up for polling (NVMe: `poll_queues`).
///     - `IORING_SETUP_DEFER_TASKRUN` rings must enter the kernel regularly (a submit or wait, or
///       `io_uring_get_events`) or completions stall; `io_uring_resize_rings` needs it.
pub fn io_uring_queue_init(entries: u32, ring: *Ring, flags: ?u32) py.Error!i32 {
    if (ring._ready) return py.raiseRuntimeError(
        "`io_uring_queue_init(ring)` already initialized!",
        .{},
    );
    ring.ownByCaller();
    const res = try support.setup(c.io_uring_queue_init(entries, &ring._io_uring, flags orelse 0), flags orelse 0);
    ring._ready = true;
    return res;
}

/// Map the rings of an `io_uring` file descriptor `fd` (from `io_uring_setup`, with the same `param`) into
/// `ring`. Returns `0`; `OSError` on failure. `io_uring_queue_init*` does both steps: this is for a ring set up by
/// hand.
///
/// Example
///     >>> param = Param()
///     >>> fd = io_uring_setup(8, param)
///     >>> ring = Ring()
///     >>> io_uring_queue_mmap(fd, ring, param)
///     0
pub fn io_uring_queue_mmap(fd: i32, ring: *Ring, param: *Param) py.Error!i32 {
    // liburing clears `ring` first: a set-up one would be lost, with its mappings
    if (ring._ready) return py.raiseRuntimeError("`io_uring_queue_mmap(ring)` already initialized!", .{});
    ring.ownByCaller();
    const res = try py.checkErrno(c.io_uring_queue_mmap(fd, &param._io_uring_params, &ring._io_uring));
    ring._ready = true;
    return res;
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
///     - Call it before the fork (`os.fork`, `subprocess`, `multiprocessing` with the `fork` start method); it
///       does nothing for children already forked. Returns `0`; `OSError` on failure.
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
///     - The kernel frees the ring later, from a workqueue: what it locked stays locked a few ms after this
///       returns. Registered buffers count against `RLIMIT_MEMLOCK` (a buffer inside a huge page pins all of it,
///       2 MiB), as the rings did before Linux 5.12, so setting up rings with them in a tight loop can hit
///       `OSError: ENOMEM`.
///
/// Example
///     >>> io_uring_queue_exit(ring)
pub fn io_uring_queue_exit(ring: *Ring) py.Error!void {
    if (ring._ready) {
        try ring.checkThread(); // not under the owner while it waits in the kernel
        ring.drainRequests(); // requests in flight: cancelled and completed before what they hold is released
        c.io_uring_queue_exit(&ring._io_uring);
        ring._ready = false;
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
///     - Only `IORING_SETUP_CQSIZE` and `IORING_SETUP_CLAMP` go in `p.flags` (the rest is inherited from the
///       setup), other fields of `p` stay `0`. Pending entries are copied over.
///     - `OSError: EINVAL` when the completion queue is in overflow (`io_uring_cq_has_overflow`: drain it first);
///       `OSError: EEXIST` from a thread other than the issuer; `OSError: EOVERFLOW` for sizes too large without
///       `CLAMP`. A ring
///       from `io_uring_queue_init_mem` can not be resized (liburing limitation).
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
/// completions, `flags` are `IORING_ENTER_*`, `sig` an optional `SigsetT`. Returns the number of entries consumed
/// (`0` when `to_submit` is `0` or the queue is empty; on an `IORING_SETUP_SQPOLL` ring just `to_submit`, the
/// kernel thread does the submitting).
///
/// Flags
///     IORING_ENTER_GETEVENTS          # wait for min_complete completions
///     IORING_ENTER_SQ_WAKEUP          # SQPOLL: wake the idle kernel thread
///     IORING_ENTER_SQ_WAIT            # SQPOLL: wait for a free submission queue slot (io_uring_sqring_wait)
///     IORING_ENTER_EXT_ARG            # Linux 5.11+: io_uring_enter2's arg is a struct io_uring_getevents_arg
///     IORING_ENTER_REGISTERED_RING    # fd is a registered ring index (io_uring_register_ring_fd)
///     IORING_ENTER_ABS_TIMER          # Linux 6.12+: the timeout is absolute (io_uring_register_clock)
///     IORING_ENTER_EXT_ARG_REG        # Linux 6.13+: arg is an offset into the registered wait region
///     IORING_ENTER_NO_IOWAIT          # Linux 6.15+: no iowait accounting while waiting (io_uring_set_iowait)
///
/// Example
///     >>> io_uring_enter(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, None)
///     0
///
/// Note
///     - Other Python threads run while it waits (`min_complete > 0`).
///     - Only the call's own errors raise here; a failed request raises when its `cqe.res` is read.
///       `InterruptedError` (`EINTR`): a signal while waiting; `OSError: EBUSY`: overflowed completions could not
///       all be flushed, reap and retry; `BlockingIOError` (`EAGAIN`): the kernel is out of resources, reap and
///       retry; `OSError: EEXIST`: `IORING_ENTER_GETEVENTS` on an `IORING_SETUP_DEFER_TASKRUN` ring from another
///       thread; `OSError: EBADFD`: the ring is still disabled (`IORING_SETUP_R_DISABLED`).
///     - `IORING_SETUP_SQPOLL`: when the kernel thread went idle (`IORING_SQ_NEED_WAKEUP` in the submission queue
///       flags) new entries sit until a call with `IORING_ENTER_SQ_WAKEUP`; `io_uring_submit` does that itself.
///     - `IORING_SETUP_IOPOLL`: `min_complete > 0` polls until a completion is in or the scheduler time slice ends.
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
///
/// Note
///     - `arg` is a raw address: the caller keeps what it points to alive until the call returns.
///     - `IORING_ENTER_EXT_ARG` needs Linux 5.11+ (`IORING_FEAT_EXT_ARG`), `IORING_ENTER_EXT_ARG_REG` 6.13+;
///       `OSError: EINVAL` before. Without either, `arg` is read as a `sigset_t` like `io_uring_enter`'s `sig`.
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
///
/// Note
///     - `p.flags` are the `IORING_SETUP_*` of `io_uring_queue_init` (same errors), `p.features` on return the
///       `IORING_FEAT_*` the kernel supports. `p.resv` must be `0`.
///     - `IORING_SETUP_SQ_AFF` without `IORING_SETUP_SQPOLL`, `IORING_SETUP_REGISTERED_FD_ONLY` without
///       `IORING_SETUP_NO_MMAP` and `IORING_SETUP_CQSIZE` with a bad `p.cq_entries` are `OSError: EINVAL`;
///       `OSError: ENXIO`: `p.wq_fd` of `IORING_SETUP_ATTACH_WQ` is not a live ring.
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
///
/// Note
///     - `arg` is a raw address: the caller keeps what it points to alive until the call returns (and for as
///       long as `opcode` says the kernel reads it later).
pub fn io_uring_register(fd: u32, opcode: u32, nr_args: u32, arg: ?usize) py.Error!i32 {
    return support.registerOp(opcode, c.io_uring_register(fd, opcode, if (arg) |a| @ptrFromInt(a) else null, nr_args));
}

/// Turn the iowait accounting of a task waiting for completions on (`True`, what a new ring does) or off
/// (`False`). Returns `0`; `UnsupportedError` without `IORING_FEAT_NO_IOWAIT` (Linux 6.15+).
///
/// Example
///     >>> io_uring_set_iowait(ring, False)
///     0
///
/// Note
///     - With it on, a wait with requests pending counts as I/O wait (`iowait` in load and CPU statistics) and
///       keeps the CPU out of deeper sleep states; off is for non-storage work and power. Off, the wait calls
///       pass `IORING_ENTER_NO_IOWAIT` to `io_uring_enter`.
pub fn io_uring_set_iowait(ring: *Ring, enable_iowait: bool) py.Error!i32 {
    const r = try ring.checkedPtr();
    return support.feature("IORING_FEAT_NO_IOWAIT", r.features, c.io_uring_set_iowait(r, enable_iowait));
}

/// How many entries are queued in the submission queue that the kernel has not consumed yet: not submitted yet,
/// or on an `IORING_SETUP_SQPOLL` ring not picked up by the kernel thread yet.
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

/// Bytes the kernel needs to map a ring of `entries` with `flags`. `OSError` (`EINVAL`) for `entries` `0` or over
/// the limit without `IORING_SETUP_CLAMP`.
///
/// Example
///     >>> io_uring_memory_size(8, 0)
///     8192
pub fn io_uring_memory_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_memory_size(entries, flags));
}

/// Bytes the kernel needs to map a ring of `entries` set up as `p` says (`p.cq_entries` counts with
/// `IORING_SETUP_CQSIZE`): what to give `io_uring_queue_init_mem`. Errors like `io_uring_memory_size`.
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
///     - `0` on kernels that no longer count rings against `RLIMIT_MEMLOCK` (Linux 5.12+).
pub fn io_uring_mlock_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size(entries, flags));
}

/// Bytes of locked memory (`RLIMIT_MEMLOCK`) a ring of `entries` set up as `p` says needs (`p.cq_entries` counts
/// with `IORING_SETUP_CQSIZE`).
///
/// Example
///     >>> io_uring_mlock_size_params(8, Param())
///     0
///
/// Note
///     - `0` on kernels that no longer count rings against `RLIMIT_MEMLOCK` (Linux 5.12+).
pub fn io_uring_mlock_size_params(entries: u32, p: *Param) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size_params(entries, &p._io_uring_params));
}

/// Wait for room in the submission queue of an `IORING_SETUP_SQPOLL` ring (until its kernel thread consumed
/// entries); returns at once when there is room. Returns the call's result, an error is not raised.
///
/// Example
///     >>> io_uring_sqring_wait(ring)
///     0
///
/// Note
///     - `0` at once on a ring without `IORING_SETUP_SQPOLL` (then `io_uring_submit` frees the slots); `-EINVAL`
///       on a kernel without `IORING_ENTER_SQ_WAIT`.
///     - Other Python threads run while it waits.
pub fn io_uring_sqring_wait(ring: *Ring) py.Error!i32 {
    return callReleased(c.io_uring_sqring_wait, .{try ring.checkedPtr()}); // `SQPOLL`: until the SQ has room
}

/// Get the next free entry of the submission queue to prep a request on.
///
/// Type
///     return: SQE | None
///
/// Example
///     >>> if sqe := io_uring_get_sqe(ring):
///     ...     io_uring_prep_nop(sqe)
///     ...
///     True
///
/// Note
///     - `None` when the submission queue is full: `io_uring_submit(ring)` and try again, or let the ring do it
///       (`Ring(auto_submit=True)`). Set a request's link flags before taking the next entry: the
///       ring submits only when the last queued request does not link on.
///     - Neither this nor the preps set or clear the entry's `user_data`: set it (`io_uring_sqe_set_data64`)
///       on every request whose completion you tell apart, or it may carry the value of the slot's previous use.
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
/// Type
///     return: SQE | None
///
/// Example
///     >>> if sqe := io_uring_get_sqe128(ring):  # `ring` set up with `IORING_SETUP_SQE_MIXED`
///     ...     io_uring_prep_nop128(sqe)
///     ...
///     True
///
/// Note
///     - `None` when the queue is full (`io_uring_submit(ring)` first, like `io_uring_get_sqe`), and always on a
///       ring with neither `IORING_SETUP_SQE128` (Linux 5.19+) nor `IORING_SETUP_SQE_MIXED`.
///     - On a `SQE_MIXED` ring an entry can not wrap around the queue's end: when the next slot is the last one a
///       filler `NOP` (no completion) goes there first, so the call can take three slots and `io_uring_submit`
///       counts one entry more.
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
