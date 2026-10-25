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
/// `ValueError` if `count` is larger than `batch`.
///
/// Example
///     >>> batch = CqeBatch(64)
///     >>> n = io_uring_peek_batch_cqe(ring, batch)
///     >>> for cqe in batch:
///     ...     cqe.user_data  # do stuff
///     ...
///     1
///     2
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

/// Wait for at least `wait_nr` completions, or until `ts` (default `None`: no limit) runs out. `cqe` is set to
/// the first one. Returns `0`; `OSError` (`errno.ETIME`) when `ts` ran out first.
///
/// Example
///     >>> io_uring_wait_cqes(ring, cqe, 2)
///     0
///
///     # or
///     >>> ts = timespec(1.5)  # timeout
///     >>> io_uring_wait_cqes(ring, cqe, 2, ts)
///     0
///
/// Note
///     - Other Python threads run while it sleeps in the kernel.
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_wait_cqes(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec, sigmask: ?*SigsetT) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const _ts = if (ts) |t| t._timespec else null;
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_wait_cqes, .{ r, out, wait_nr, _ts, _sigmask }));
}

/// Wait for `wait_nr` completions like `io_uring_wait_cqes`, with two timeouts: `ts` is the overall limit and
/// `min_ts_usec` (microseconds) the time to wait for the whole batch once the first completion has arrived.
/// Returns `0`; `OSError` (`errno.ETIME`) when `ts` ran out first.
///
/// Example
///     >>> ts = timespec(1)  # overall timeout
///     >>> io_uring_wait_cqes_min_timeout(ring, cqe, 2, ts, 1000)
///     0
///
/// Note
///     - Needs Linux 6.12+ (`IORING_FEAT_MIN_TIMEOUT`), else `UnsupportedError`.
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_wait_cqes_min_timeout(
    ring: *Ring,
    cqe: *Cqe,
    wait_nr: u32,
    ts: *Timespec,
    min_ts_usec: u32,
    sigmask: ?*SigsetT,
) py.Error!i32 {
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

/// Wait for one completion, for at most `ts`. `cqe` is set to it. Returns `0`; `OSError` (`errno.ETIME`) when `ts`
/// ran out first.
///
/// Example
///     >>> ts = timespec(1.5)  # timeout
///     >>> io_uring_wait_cqe_timeout(ring, cqe, ts)
///     0
pub fn io_uring_wait_cqe_timeout(ring: *Ring, cqe: *Cqe, ts: *Timespec) py.Error!i32 {
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, 1, c.io_uring_wait_cqe_timeout, .{ r, out, ts._timespec }));
}

/// Submit the queued entries to the kernel. Returns how many were submitted.
///
/// Example
///     >>> io_uring_submit(ring)  # two entries queued
///     2
pub fn io_uring_submit(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_submit(try ring.submitPtr()));
}

/// Submit the queued entries and wait for `wait_nr` completions. Returns how many entries were submitted.
///
/// Example
///     >>> io_uring_submit_and_wait(ring, 2)  # two entries queued
///     2
pub fn io_uring_submit_and_wait(ring: *Ring, wait_nr: u32) py.Error!i32 {
    const r = try ring.submitPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_submit_and_wait, .{ r, wait_nr }));
}

/// Submit the queued entries and wait for `wait_nr` completions, or until `ts` (default `None`: no limit) runs
/// out. `cqe` is set to the first one. Returns how many entries were submitted; `OSError` (`errno.ETIME`) when
/// `ts` ran out first.
///
/// Example
///     >>> io_uring_submit_and_wait_timeout(ring, cqe, 2)  # two entries queued
///     2
///     >>> io_uring_cq_advance(ring, 2)  # done with them
///
///     # or
///     >>> io_uring_prep_nop(io_uring_get_sqe(ring))
///     True
///     >>> ts = timespec(0.5)
///     >>> io_uring_submit_and_wait_timeout(ring, cqe, 1, ts)
///     1
///
/// Note
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_submit_and_wait_timeout(
    ring: *Ring,
    cqe: *Cqe,
    wait_nr: u32,
    ts: ?*Timespec,
    sigmask: ?*SigsetT,
) py.Error!i32 {
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

/// Submit the queued entries and wait for `wait_nr` completions like `io_uring_submit_and_wait_timeout`, with two
/// timeouts: `ts` is the overall limit and `min_wait` (microseconds) the time to wait for the whole batch once
/// the first completion has arrived. Returns how many entries were submitted; `OSError` (`errno.ETIME`) when `ts`
/// ran out first.
///
/// Example
///     >>> ts = timespec(1)  # overall timeout
///     >>> io_uring_submit_and_wait_min_timeout(ring, cqe, 2, ts, 1000)  # two entries queued
///     2
///
/// Note
///     - Needs Linux 6.12+ (`IORING_FEAT_MIN_TIMEOUT`), else `UnsupportedError`.
///     - `sigmask`: signal mask (`SigsetT`) used only while waiting, signals not in it can
///       interrupt the wait with `InterruptedError`. `None` keeps the current mask.
pub fn io_uring_submit_and_wait_min_timeout(
    ring: *Ring,
    cqe: *Cqe,
    wait_nr: u32,
    ts: *Timespec,
    min_wait: u32,
    sigmask: ?*SigsetT,
) py.Error!i32 {
    const _sigmask = if (sigmask) |s| s._sigset_t else null;
    const out = try cqe.outFor(ring); // first: a refused `Cqe` must stop the call before the submit
    const r = try ring.submitPtr();
    const res = wait(r, wait_nr, c.io_uring_submit_and_wait_min_timeout, .{
        r,
        out,
        wait_nr,
        ts._timespec,
        min_wait,
        _sigmask,
    });
    return support.feature("IORING_FEAT_MIN_TIMEOUT", r.features, res);
}

/// Submit the queued entries and wait for `wait_nr` completions, as the registered wait region entry `reg_index`
/// says (timeouts, see `RegWait` and `io_uring_register_wait_reg`; less overhead, nothing is copied). Returns how
/// many entries were submitted; `OSError` (`errno.ETIME`) when the region's timeout ran out first.
///
/// Example
///     >>> io_uring_submit_and_wait_reg(ring, cqe, 1, 0)  # one entry queued; wait argument 0 of the region
///     1
pub fn io_uring_submit_and_wait_reg(ring: *Ring, cqe: *Cqe, wait_nr: u32, reg_index: i32) py.Error!i32 {
    const out = try cqe.outFor(ring); // first: a refused `Cqe` must stop the call before the submit
    const r = try ring.submitPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_submit_and_wait_reg, .{ r, out, wait_nr, reg_index }));
}

/// Flush completions waiting in the kernel (overflowed ones, deferred task work) into the completion queue,
/// without waiting. Returns `0`.
///
/// Example
///     >>> io_uring_get_events(ring)
///     0
pub fn io_uring_get_events(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_get_events(try ring.checkedPtr()));
}

/// `io_uring_submit` that also flushes waiting completions into the completion queue (`io_uring_get_events`).
/// Returns how many entries were submitted.
///
/// Example
///     >>> io_uring_submit_and_get_events(ring)  # two entries queued
///     2
pub fn io_uring_submit_and_get_events(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_submit_and_get_events(try ring.submitPtr()));
}

/// Start an iterator over the completions that are ready now.
///
/// Type
///     return: CqeIter
///
/// Example
///     >>> cqe_iter = io_uring_cqe_iter_init(ring)
///     >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///     ...     cqe[0].user_data
///     ...
///     1
///     2
///     >>> io_uring_cq_advance(ring, 2)
///
/// Note
///     - `io_uring_cqe_iter_init` must be used with `io_uring_cqe_iter_next`
///     - Refer to `help(io_uring_cqe_iter_next)` for better example.
pub fn io_uring_cqe_iter_init(ring: *Ring) py.Error!*Object {
    return CqeIterType.new(.{
        ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(try ring.checkedPtr()),
        ._ring = class.keep(RingType.object(ring)),
        ._gen = ring._gen,
    });
}

/// Set `cqe[0]` to the next ready completion of `iter`. Returns `False` when there is none left.
///
/// Example
///     # two requests submitted and completed before
///     >>> ready = 0
///     >>> cqe_iter = io_uring_cqe_iter_init(ring)
///     >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///     ...     ready += 1
///     ...     entry = cqe[0]  # only index `0` data gets updated!!!
///     ...     entry.user_data, entry.res  # do something with info
///     ...
///     (1, 0)
///     (2, 0)
///     >>> io_uring_cq_advance(ring, ready)  # after the loop (probably faster than `io_uring_cqe_seen` in it)
///
/// Note
///     - Only `cqe[0]` gets updated with new completed entry value.
///     - Getting iter is low level and very touchy must be used as shown in example.
///     - Consider using `CqeIter` instead, in `for` loop.
pub fn io_uring_cqe_iter_next(iter: *CqeIter, cqe: *Cqe) py.Error!bool {
    const ring = iter._ring orelse return py.raiseRuntimeError(
        "`CqeIter` - not created by `io_uring_cqe_iter_init`",
        .{},
    );
    _ = try Ring.checkGen(&RingType.data(ring)._io_uring, iter._gen); // the iterator points into its queue
    try cqe.followRing(ring); // `cqe[i]` follows this ring's completion queue
    return c.io_uring_cqe_iter_next(&iter._io_uring_cqe_iter, &cqe._io_uring_cqe);
}

/// Mark `nr` completions (from the head of the completion queue) as seen, so the kernel can reuse their slots.
///
/// Example
///     >>> io_uring_cq_advance(ring, 2)
///
/// Note
///     - Consumes the completions: their `user_data` (and `cqe[i]` entries) are not valid after it.
pub fn io_uring_cq_advance(ring: *Ring, nr: u32) py.Error!void {
    const r = try ring.checkedPtr();
    ring.releaseCompleted(r, nr);
    c.io_uring_cq_advance(r, nr);
}

/// Mark one completion as seen, so the kernel can reuse its slot.
///
/// Example
///     >>> io_uring_cqe_seen(ring, cqe[0])
///
/// Note
///     - Consumes the completion: its `user_data` is not valid after it.
pub fn io_uring_cqe_seen(ring: *Ring, cqe: *CQE) py.Error!void {
    const r = try ring.checkedPtr();
    const entry = try cqe.cqePtr();
    ring.releaseCqe(entry);
    c.io_uring_cqe_seen(r, entry);
}

/// The `user_data` of `cqe` as an `int` (the pointer value set with `io_uring_sqe_set_data`).
///
/// Example
///     >>> io_uring_cqe_get_data(cqe[0])
///     1
///
/// Note
///     - `ValueError` if it is `0` (a null pointer).
pub fn io_uring_cqe_get_data(cqe: *CQE) py.Error!usize {
    const data = try cqe.get_user_data(); // NOTE: This can return garbage data!
    if (data != 0) return @intCast(data); // cast: `usize` is 64 bits (Linux x86_64 / aarch64)
    return py.raiseValueError("`io_uring_cqe_get_data()` - received `null`", .{});
}

/// The 64-bit `user_data` of `cqe` (set with `io_uring_sqe_set_data64`).
///
/// Example
///     >>> io_uring_cqe_get_data64(cqe[0])
///     1
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

/// How many completions are ready in the completion queue.
///
/// Example
///     >>> io_uring_cq_ready(ring)
///     2
pub fn io_uring_cq_ready(ring: *Ring) py.Error!u32 {
    return c.io_uring_cq_ready(try ring.checkedPtr());
}

/// Whether the kernel holds completions that did not fit the completion queue (`IORING_SQ_CQ_OVERFLOW`).
///
/// Example
///     >>> io_uring_cq_has_overflow(ring)
///     False
pub fn io_uring_cq_has_overflow(ring: *Ring) py.Error!bool {
    return c.io_uring_cq_has_overflow(try ring.checkedPtr());
}

/// Whether the registered eventfd is notified of completions (not disabled by `io_uring_cq_eventfd_toggle`).
///
/// Example
///     >>> io_uring_cq_eventfd_enabled(ring)
///     True
pub fn io_uring_cq_eventfd_enabled(ring: *Ring) py.Error!bool {
    return c.io_uring_cq_eventfd_enabled(try ring.checkedPtr());
}

/// Turn the registered eventfd's notifications on or off. Returns `0`; `OSError` if the kernel has no flag for it.
///
/// Example
///     >>> io_uring_cq_eventfd_toggle(ring, False)
///     0
pub fn io_uring_cq_eventfd_toggle(ring: *Ring, enabled: bool) py.Error!i32 {
    return py.checkErrno(c.io_uring_cq_eventfd_toggle(try ring.checkedPtr(), enabled));
}

/// Wait until `wait_nr` completions are ready. `cqe` is set to the first one. Returns `0`.
///
/// Example
///     >>> io_uring_wait_cqe_nr(ring, cqe, 2)
///     0
pub fn io_uring_wait_cqe_nr(ring: *Ring, cqe: *Cqe, wait_nr: u32) py.Error!i32 {
    const out = try cqe.outFor(ring);
    const r = try ring.checkedPtr();
    return py.checkErrno(wait(r, wait_nr, c.io_uring_wait_cqe_nr, .{ r, out, wait_nr }));
}

/// Set `cqe` to the first ready completion without waiting. Returns `0`; `BlockingIOError` (`EAGAIN`) if none is
/// ready.
///
/// Example
///     >>> io_uring_peek_cqe(ring, cqe)
///     0
pub fn io_uring_peek_cqe(ring: *Ring, cqe_ptr: *Cqe) py.Error!i32 {
    const out = try cqe_ptr.outFor(ring);
    return py.checkErrno(c.io_uring_peek_cqe(try ring.checkedPtr(), out));
}

/// Wait for one completion. `cqe` is set to it. Returns `0`.
///
/// Example
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
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
