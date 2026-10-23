//! Liburing - submit and complete
const c = @import("c");
const setu = @import("setu");
const class = @import("class.zig");
const support = @import("support.zig");
const CqeIter = @import("cqe.zig").CqeIter;
const CQE = @import("cqe.zig").CQE;
const Cqe = @import("cqe.zig").Cqe;
const CqeBatch = @import("cqe.zig").CqeBatch;
const CqeIterType = @import("cqe.zig").CqeIterType;
const Ring = @import("ring.zig").Ring;
const RingType = @import("ring.zig").RingType;

const py = setu.py;
const Object = setu.c.Object;
const Timespec = class.Timespec;
const SigsetT = class.SigsetT;

/// Peek up to `count` (default: all of `batch`) ready completions without waiting.
/// Returns how many were placed in `batch`, `0` if none are ready.
///
/// Example
///     >>> batch = CqeBatch(64)
///     >>> n = io_uring_peek_batch_cqe(ring, batch)
///     >>> for cqe in batch:
///     ...     cqe.user_data  # do stuff
///     >>> io_uring_cq_advance(ring, n)
///
/// Note
///     - Does not consume them, call `io_uring_cq_advance(ring, n)` after reading.
pub fn io_uring_peek_batch_cqe(ring: *Ring, batch: *CqeBatch, count: ?u32) py.Error!u32 {
    const n = count orelse batch._len;
    if (n > batch._len) return py.raiseValueError("`io_uring_peek_batch_cqe` - `count` larger than `CqeBatch`", .{});
    try batch.claimThread(); // two threads filling one batch would swap `_ring` under each other
    batch._count = c.io_uring_peek_batch_cqe(try ring.checkedPtr(), batch._array.?, n);
    class.setOwned(&batch._ring, RingType.object(ring));
    batch._gen = ring._gen;
    return batch._count;
}

/// Example
///     >>> io_uring_wait_cqes(ring, cqe, 123)
///     # or
///     >>> ts = timespec(1.5)  # timeout
///     >>>io_uring_wait_cqes(ring, cqe, 123, ts)
///
/// Note
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_wait_cqes(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec, sigmask: ?*SigsetT) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const _ts = if (ts) |t| t._timespec else null;
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_wait_cqes, .{ r, out, wait_nr, _ts, _sigmask }));
}

/// >>> io_uring_wait_cqes_min_timeout(ring)
///
/// Note
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_wait_cqes_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_ts_usec: u32, sigmask: ?*SigsetT) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return support.feature("IORING_FEAT_MIN_TIMEOUT", r.features, wait(r, wait_nr, c.io_uring_wait_cqes_min_timeout, .{
        r,
        out,
        wait_nr,
        ts._timespec,
        min_ts_usec,
        _sigmask,
    }));
}

/// >>> ts = timespec(1.5)  # timeout
/// >>> io_uring_wait_cqe_timeout(ring, cqe, ts)
pub fn io_uring_wait_cqe_timeout(ring: *Ring, cqe: *Cqe, ts: *Timespec) py.Error!i32 {
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, 1, c.io_uring_wait_cqe_timeout, .{ r, out, ts._timespec }));
}

/// >>> io_uring_submit(ring)
/// 123
pub fn io_uring_submit(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_submit(try ring.submitPtr()));
}

/// >>> io_uring_submit_and_wait(ring, 123)
pub fn io_uring_submit_and_wait(ring: *Ring, wait_nr: u32) py.Error!i32 {
    const r = try ring.submitPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_submit_and_wait, .{ r, wait_nr }));
}

/// >>> io_uring_submit_and_wait_timeout(ring, cqe, 1)
/// # or
/// >>> ts = timespec(0.5)
/// >>> io_uring_submit_and_wait_timeout(ring, cqe, 1, ts)
///
/// Note
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_submit_and_wait_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec, sigmask: ?*SigsetT) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const _ts = if (ts) |t| t._timespec else null;
    const out = try cqe.outFor(ring); // first: a refused `Cqe` must stop the call before the submit
    const r = try ring.submitPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_submit_and_wait_timeout, .{
        r,
        out,
        wait_nr,
        _ts,
        _sigmask,
    }));
}

/// Note
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_submit_and_wait_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_wait: u32, sigmask: ?*SigsetT) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const out = try cqe.outFor(ring); // first: a refused `Cqe` must stop the call before the submit
    const r = try ring.submitPtr();
    return support.feature("IORING_FEAT_MIN_TIMEOUT", r.features, wait(r, wait_nr, c.io_uring_submit_and_wait_min_timeout, .{
        r,
        out,
        wait_nr,
        ts._timespec,
        min_wait,
        _sigmask,
    }));
}

pub fn io_uring_submit_and_wait_reg(ring: *Ring, cqe: *Cqe, wait_nr: u32, reg_index: i32) py.Error!i32 {
    const out = try cqe.outFor(ring); // first: a refused `Cqe` must stop the call before the submit
    const r = try ring.submitPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_submit_and_wait_reg, .{ r, out, wait_nr, reg_index }));
}

pub fn io_uring_get_events(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_get_events(try ring.checkedPtr()));
}

pub fn io_uring_submit_and_get_events(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_submit_and_get_events(try ring.submitPtr()));
}

/// Example
///     >>> cqe_iter = io_uring_cqe_iter_init(ring)
///     >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///
/// Note
///     - `io_uring_cqe_iter_init` must be used with `io_uring_cqe_iter_next`
///     - Refer to `help(io_uring_cqe_iter_next)` for better example.
///
/// Type
///     return: CqeIter
pub fn io_uring_cqe_iter_init(ring: *Ring) py.Error!*Object {
    return CqeIterType.new(.{
        ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(try ring.checkedPtr()),
        ._ring = class.keep(RingType.object(ring)),
        ._gen = ring._gen,
    });
}

/// Example
///     # Must submit `sqe` before:
///     ... ...
///     >>> ready = 0
///     >>> cqe_iter = io_uring_cqe_iter_init(ring)
///     >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///     >>>     ready += 1
///     >>>     entry = cqe[0]  # only index `0` data gets updated!!!
///     >>>     entry.user_data, entry.res  # do something with info
///     ...     ...
///     # either:
///     >>>     io_uring_cqe_seen(ring, entry)  # within `while` loop
///     # or
///     >>> io_uring_cq_advance(ring, ready)  # after `while` loop is finished (probably faster).
///
/// Note
///     - Only `cqe[0]` gets updated with new completed entry value.
///     - Getting iter is low level and very touchy must be used as shown in example.
///     - Consider using `CqeIter` instead, in `for` loop.
pub fn io_uring_cqe_iter_next(iter: *CqeIter, cqe: *Cqe) py.Error!bool {
    const ring = iter._ring orelse return py.raiseRuntimeError("`CqeIter` - not created by `io_uring_cqe_iter_init`", .{});
    _ = try Ring.checkGen(&RingType.data(ring)._io_uring, iter._gen); // the iterator points into its queue
    try cqe.follow(ring); // `cqe[i]` follows this ring's completion queue
    return c.io_uring_cqe_iter_next(&iter._io_uring_cqe_iter, &cqe._io_uring_cqe);
}

/// Note
///     - Consumes the completions: their `user_data` (and `cqe[i]` entries) are not valid after it.
pub fn io_uring_cq_advance(ring: *Ring, nr: u32) py.Error!void {
    const r = try ring.checkedPtr();
    ring.releaseCompleted(r, nr);
    c.io_uring_cq_advance(r, nr);
}

/// Note
///     - Consumes the completion: its `user_data` is not valid after it.
pub fn io_uring_cqe_seen(ring: *Ring, cqe: *CQE) py.Error!void {
    const r = try ring.checkedPtr();
    const entry = try cqe.cqePtr();
    ring.releaseCqe(entry);
    c.io_uring_cqe_seen(r, entry);
}

/// >>> python_object = io_uring_cqe_get_data(cqe[0])
///
/// Warning
///     - Not tested!!!
pub fn io_uring_cqe_get_data(cqe: *CQE) py.Error!usize {
    const data = try cqe.get_user_data(); // NOTE: This can return garbage data!
    if (data != 0) return @intCast(data); // cast: `usize` is 64 bits (Linux x86_64 / aarch64)
    return py.raiseValueError("`io_uring_cqe_get_data()` - received `null`", .{});
}

/// >>> io_uring_cqe_get_data64(cqe)
/// 123
pub fn io_uring_cqe_get_data64(cqe: *CQE) py.Error!u64 {
    return cqe.get_user_data();
}

/// How many completion queue slots `cqe` takes: `1`, or `2` for a big (`IORING_CQE_F_32`) entry.
///
/// Example
///     >>> io_uring_cq_advance(ring, io_uring_cqe_nr(cqe[0]))
pub fn io_uring_cqe_nr(cqe: *CQE) py.Error!u32 {
    return c.io_uring_cqe_nr(try cqe.cqePtr());
}

pub fn io_uring_cq_ready(ring: *Ring) py.Error!u32 {
    return c.io_uring_cq_ready(try ring.checkedPtr());
}

pub fn io_uring_cq_has_overflow(ring: *Ring) py.Error!bool {
    return c.io_uring_cq_has_overflow(try ring.checkedPtr());
}

pub fn io_uring_cq_eventfd_enabled(ring: *Ring) py.Error!bool {
    return c.io_uring_cq_eventfd_enabled(try ring.checkedPtr());
}

pub fn io_uring_cq_eventfd_toggle(ring: *Ring, enabled: bool) py.Error!i32 {
    return py.checkErrno(c.io_uring_cq_eventfd_toggle(try ring.checkedPtr(), enabled));
}

pub fn io_uring_wait_cqe_nr(ring: *Ring, cqe: *Cqe, wait_nr: u32) py.Error!i32 {
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_wait_cqe_nr, .{ r, out, wait_nr }));
}

/// >>> io_uring_peek_cqe(ring, cqe)
pub fn io_uring_peek_cqe(ring: *Ring, cqe_ptr: *Cqe) py.Error!i32 {
    const out = try cqe_ptr.outFor(ring);
    return py.checkErrno(c.io_uring_peek_cqe(try ring.checkedPtr(), out));
}

pub fn io_uring_wait_cqe(ring: *Ring, cqe: *Cqe) py.Error!i32 {
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, 1, c.io_uring_wait_cqe, .{ r, out }));
}

/// Calls the liburing function `f(args)` for `wait_nr` completions: straight away when they are ready
/// (the kernel does not sleep), else with the thread state released (`callReleased`).
inline fn wait(ring: *c.io_uring, wait_nr: u32, comptime f: anytype, args: anytype) Return(f) {
    if (c.io_uring_cq_ready(ring) >= wait_nr) return @call(.auto, f, args);
    return callReleased(f, args);
}

/// Calls `f(args)`, which may sleep in the kernel, with the thread state released (`PyEval_SaveThread`,
/// as `os.read` does): other threads run, and on the free-threaded build the GC does not wait for it.
/// `args` are no Python objects; the ring is the caller's thread's alone (`Ring.checkRing`).
pub fn callReleased(comptime f: anytype, args: anytype) Return(f) {
    const state = setu.c.PyEval_SaveThread();
    defer setu.c.PyEval_RestoreThread(state);
    return @call(.auto, f, args);
}

fn Return(comptime f: anytype) type {
    return @typeInfo(@TypeOf(f)).@"fn".return_type.?;
}
