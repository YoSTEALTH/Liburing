//! Liburing - io_uring related functions
const c = @import("c.zig").c;
const h = @import("helper.zig");
const setu = @import("setu");
const std = @import("std");
const class = @import("class.zig");
const Statx = @import("statx.zig").Statx;
const Futex = @import("futex.zig").Futex;
const AT_FDCWD = @import("const.zig").AT_FDCWD;
const Sockaddr = @import("socket.zig").Sockaddr;
const FileIndex = @import("helper.zig").FileIndex;
const support = @import("support.zig");

const py = setu.py;
const Object = setu.c.Object;
const SyncCancelReg = class.SyncCancelReg;
const ClockRegister = class.ClockRegister;
const MemRegionReg = class.MemRegionReg;
const Restriction = class.Restriction;
const EpollEvent = class.EpollEvent;
const RecvmsgOut = class.RecvmsgOut;
const ZcrxIfqReg = class.ZcrxIfqReg;
const Timespec = class.Timespec;
const RegWait = class.RegWait;
const SigsetT = class.SigsetT;
const BufRing = class.BufRing;
const CqeIter = class.CqeIter;
const Cmsghdr = class.Cmsghdr;
const OpenHow = class.OpenHow;
const Msghdr = class.Msghdr;
const BufReg = class.BufReg;
const Iovec = class.Iovec;
const Probe = class.Probe;
const Param = class.Param;
const Napi = class.Napi;
const Query = class.Query;
const ZcrxCtrl = class.ZcrxCtrl;
const Ring = class.Ring;
const CQE = class.CQE;
const Cqe = class.Cqe;
const SQE = class.SQE;
const Sqe = class.Sqe;
const Bpf = class.Bpf;

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

/// >>> io_uring_get_probe()
///
/// Type
///     return: Probe
pub fn io_uring_get_probe() py.Error!*Object {
    if (c.io_uring_get_probe()) |p| return class.ProbeType.new(.{ ._io_uring_probe = p });
    return py.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe()`", .{});
}

/// >>> io_uring_free_probe(probe)
pub fn io_uring_free_probe(probe: *Probe) void {
    if (probe._io_uring_probe) |p| {
        c.io_uring_free_probe(p);
        probe._io_uring_probe = null;
    }
}

/// >>> io_uring_opcode_supported(probe, op)
/// True # or False
pub fn io_uring_opcode_supported(probe: *Probe, op: i32) bool {
    return (c.io_uring_opcode_supported(probe._io_uring_probe, op) == 1);
}

/// Setup `Ring` in memory you supply (`IORING_SETUP_NO_MMAP`). Returns the bytes of `buf` it used.
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
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError("`io_uring_queue_init_mem(ring)` already initialized!", .{});
    // Own view: the argument's is released after the call, this one at `io_uring_queue_exit`.
    const mem: ?py.WritableBuffer = if (buf) |b| try py.WritableBuffer.from(b.view.obj.?) else null;
    errdefer if (mem) |m| m.deinit();
    const ptr: ?*anyopaque = if (mem) |m| m.data.ptr else null;
    const used = try support.setup(c.io_uring_queue_init_mem(entries, &ring._io_uring, &p._io_uring_params, ptr, if (mem) |m| m.data.len else 0), p._io_uring_params.flags);
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
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError("`io_uring_queue_init_params(ring)` already initialized!", .{});
    return support.setup(c.io_uring_queue_init_params(entries, &ring._io_uring, &param._io_uring_params), param._io_uring_params.flags);
}

/// Setup `Ring` Submission & Completion Queues
///
/// Example
///     >>> ring = Ring()
///     >>> try:
///     ...     io_uring_queue_init(1024, ring)
///     ...     # do stuff ...
///     >>> finally:
///     ...     io_uring_queue_exit(ring)
pub fn io_uring_queue_init(entries: u32, ring: *Ring, flags: ?u32) py.Error!i32 {
    if (ring._io_uring.ring_fd > 0) return py.raiseRuntimeError("`io_uring_queue_init(ring)` already initialized!", .{});
    return support.setup(c.io_uring_queue_init(entries, &ring._io_uring, flags orelse 0), flags orelse 0);
}

/// >>> io_uring_queue_mmap(fd, param, ring)
pub fn io_uring_queue_mmap(fd: i32, ring: *Ring, param: *Param) py.Error!i32 {
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
/// >>> io_uring_ring_dontfork(ring)
/// 0
pub fn io_uring_ring_dontfork(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_ring_dontfork(try ring.checkedPtr()));
}

/// Tear down `ring`: unmap its Submission & Completion Queues and close its `fd`.
///
/// Note
///     - Raises `RuntimeError` if `ring` is not initialized or already exited.
///
/// >>> io_uring_queue_exit(ring)
pub fn io_uring_queue_exit(ring: *Ring) py.Error!void {
    if (ring._io_uring.ring_fd > 0) {
        c.io_uring_queue_exit(&ring._io_uring);
        ring._io_uring.ring_fd = 0;
        const kept = ring._keep;
        ring._keep = null;
        py.decref(kept);
        if (ring._mem) |m| m.deinit(); // the kernel is done with it
        ring._mem = null;
    } else return py.raiseRuntimeError("`io_uring_queue_exit(ring)` not initialized or already exited!", .{});
}

/// TODO
///
/// Example
///     >>> cqe = Cqe(1024) # custom memory
///     ...
///     >>> io_uring_peek_batch_cqe(ring, cqe, 1024)
///     123
///
/// Warning
///     - Don't use this function, till this warning is removed or else its most likely segfault!!!
pub fn io_uring_peek_batch_cqe(ring: *Ring, cqe: *Cqe, count: u32) py.Error!void {
    _ = .{ ring, cqe, count };
    return py.raiseNotImplementedError("`io_uring_peek_batch_cqe`", .{});
    // TODO:
    // fn peekBatchCqe(ring: *Ring, cqe: *Cqe, count: u32) py.Error!void {
    // if (cqe._array) |_| return c.io_uring_peek_batch_cqe(try ring.checkedPtr(), cqe.outFor(ring), count);
}

/// Example
///     >>> io_uring_wait_cqes(ring, cqe, 123)
///     # or
///     >>> ts = timespec(1.5)  # timeout
///     >>>io_uring_wait_cqes(ring, cqe, 123, ts)
pub fn io_uring_wait_cqes(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) py.Error!i32 {
    const _sigmask = null; // TODO
    const _ts = if (ts) |t| t._timespec else null;
    return py.checkErrno(c.io_uring_wait_cqes(try ring.checkedPtr(), cqe.outFor(ring), wait_nr, _ts, _sigmask));
}

/// >>> io_uring_wait_cqes_min_timeout(ring)
pub fn io_uring_wait_cqes_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_ts_usec: u32) py.Error!i32 {
    const _sigmask = null; // TODO
    return py.checkErrno(c.io_uring_wait_cqes_min_timeout(
        try ring.checkedPtr(),
        cqe.outFor(ring),
        wait_nr,
        ts._timespec,
        min_ts_usec,
        _sigmask,
    ));
}

/// >>> ts = timespec(1.5)  # timeout
/// >>> io_uring_wait_cqe_timeout(ring, cqe, ts)
pub fn io_uring_wait_cqe_timeout(ring: *Ring, cqe: *Cqe, ts: *Timespec) py.Error!i32 {
    return py.checkErrno(c.io_uring_wait_cqe_timeout(try ring.checkedPtr(), cqe.outFor(ring), ts._timespec));
}

/// >>> io_uring_submit(ring)
/// 123
pub fn io_uring_submit(ring: *Ring) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    return py.checkErrno(c.io_uring_submit(try ring.checkedPtr()));
}

/// >>> io_uring_submit_and_wait(ring, 123)
pub fn io_uring_submit_and_wait(ring: *Ring, wait_nr: u32) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    return py.checkErrno(c.io_uring_submit_and_wait(try ring.checkedPtr(), wait_nr));
}

/// >>> io_uring_submit_and_wait_timeout(ring, cqe, 1)
/// # or
/// >>> ts = timespec(0.5)
/// >>> io_uring_submit_and_wait_timeout(ring, cqe, 1, ts)
pub fn io_uring_submit_and_wait_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    const _sigmask = null; // TODO
    const _ts = if (ts) |t| t._timespec else null;
    return py.checkErrno(c.io_uring_submit_and_wait_timeout(
        try ring.checkedPtr(),
        cqe.outFor(ring),
        wait_nr,
        _ts,
        _sigmask,
    ));
}

pub fn io_uring_submit_and_wait_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_wait: u32) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    const _sigmask = null; // TODO

    return py.checkErrno(c.io_uring_submit_and_wait_min_timeout(
        try ring.checkedPtr(),
        cqe.outFor(ring),
        wait_nr,
        ts._timespec,
        min_wait,
        _sigmask,
    ));
}

pub fn io_uring_submit_and_wait_reg(ring: *Ring, cqe: *Cqe, wait_nr: u32, reg_index: i32) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    return py.checkErrno(c.io_uring_submit_and_wait_reg(try ring.checkedPtr(), cqe.outFor(ring), wait_nr, reg_index));
}

pub fn io_uring_register_wait_reg(ring: *Ring, reg: *RegWait, nr: i32) py.Error!i32 {
    if (nr != 1) return py.raiseValueError("`io_uring_register_wait_reg(nr)` - only one `RegWait` can be registered from Python for now", .{});
    return py.checkErrno(c.io_uring_register_wait_reg(try ring.checkedPtr(), &reg._io_uring_reg_wait, nr));
}

pub fn io_uring_resize_rings(ring: *Ring, p: *Param) py.Error!i32 {
    return support.register("IORING_REGISTER_RESIZE_RINGS", c.io_uring_resize_rings(try ring.checkedPtr(), &p._io_uring_params));
}

pub fn io_uring_clone_buffers_offset(
    dst_ring: *Ring,
    src_ring: *Ring,
    dst_off: c_uint,
    src_off: c_uint,
    nr: c_uint,
    flags: ?c_uint,
) py.Error!i32 {
    const _flags = flags orelse 0;
    return support.register("IORING_REGISTER_CLONE_BUFFERS", c.io_uring_clone_buffers_offset(
        try dst_ring.checkedPtr(),
        try src_ring.checkedPtr(),
        dst_off,
        src_off,
        nr,
        _flags,
    ));
}

pub fn io_uring_clone_buffers(dst_ring: *Ring, src_ring: *Ring, flags: ?u32) py.Error!i32 {
    return support.register("IORING_REGISTER_CLONE_BUFFERS", c.__io_uring_clone_buffers(try dst_ring.checkedPtr(), try src_ring.checkedPtr(), flags orelse 0));
}

/// Example
///     >>> io_uring_register_buffers(ring, iovecs)
///     # with a tag for each buffer
///     >>> io_uring_register_buffers(ring, Iovec([bytearray(8), bytearray(8)]), [1, 2])
///
/// Note
///     - `io_uring_register_buffers` includes `io_uring_register_buffers_tags`
///     - `tags` needs one item for each buffer in `iovecs`.
pub fn io_uring_register_buffers(ring: *Ring, iovecs: *const Iovec, tags: ?py.Sequence(u64)) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, iovecs._len, "io_uring_register_buffers");
    return support.register("IORING_REGISTER_BUFFERS2", c.io_uring_register_buffers_tags(ptr, iovecs._iovec.?, _tags, @intCast(iovecs._len)));
}

/// The `__u64 *tags` for C: `null` for no tags, else the list, which must have one item for each of `count`.
fn tagsPtr(tags: ?py.Sequence(u64), count: usize, comptime name: []const u8) py.Error!?[*]const u64 {
    const list = tags orelse return null;
    if (list.items.len != count) return py.raiseValueError(
        "`" ++ name ++ "(..., tags)` - length of {d} does not match {d}",
        .{ list.items.len, count },
    );
    return list.items.ptr;
}

pub fn io_uring_register_buffers_sparse(ring: *Ring, nr: u32) py.Error!i32 {
    return support.register("IORING_REGISTER_BUFFERS2", c.io_uring_register_buffers_sparse(try ring.checkedPtr(), nr));
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_register_buffers_update_tag(ring: *Ring, iovecs: *const Iovec, tags: py.Sequence(u64), offset: ?u32) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, iovecs._len, "io_uring_register_buffers_update_tag");
    return support.register("IORING_REGISTER_BUFFERS_UPDATE", c.io_uring_register_buffers_update_tag(
        ptr,
        offset orelse 0,
        iovecs._iovec.?,
        _tags,
        @intCast(iovecs._len),
    ));
}

pub fn io_uring_unregister_buffers(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_BUFFERS", c.io_uring_unregister_buffers(try ring.checkedPtr()));
}

/// Register File Descriptor
///
/// Example
///     >>> ids = FileIndex([1, 2, 3])
///     >>> io_uring_register_files(ring, ids)
///     ...
///     >>> io_uring_unregister_files(ring)
///
/// Note
///     - Hold on to `ids` reference till the submit + wait process is done.
///     - "Registered files have less overhead per operation than normal files.
///     This is due to the kernel grabbing a reference count on a file when an
///     operation begins, and dropping it when it's done. When the process file
///     table is shared, for example if the process has ever created any
///     threads, then this cost goes up even more. Using registered files
///     reduces the overhead of file reference management across requests that
///     operate on a file."
pub fn io_uring_register_files(ring: *Ring, files: *const FileIndex) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_FILES",
        c.io_uring_register_files(try ring.checkedPtr(), files.fdSlice().ptr, @intCast(files._len)),
    );
}

/// Example
///     >>> io_uring_register_files_tags(ring, FileIndex([-1, -1]), [1, 2])
///
/// Note
///     - `tags` needs one item for each file in `files`.
pub fn io_uring_register_files_tags(ring: *Ring, files: *const FileIndex, tags: py.Sequence(u64)) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, files._len, "io_uring_register_files_tags");
    return support.register(
        "IORING_REGISTER_FILES2",
        c.io_uring_register_files_tags(ptr, files.fdSlice().ptr, _tags, @intCast(files._len)),
    );
}

pub fn io_uring_register_files_sparse(ring: *Ring, nr: u32) py.Error!i32 {
    return support.register("IORING_REGISTER_FILES2", c.io_uring_register_files_sparse(try ring.checkedPtr(), nr));
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_register_files_update_tag(ring: *Ring, files: *const FileIndex, tags: py.Sequence(u64), offset: ?u32) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, files._len, "io_uring_register_files_update_tag");
    const _offset = offset orelse 0;
    return support.register(
        "IORING_REGISTER_FILES_UPDATE2",
        c.io_uring_register_files_update_tag(ptr, _offset, files.fdSlice().ptr, _tags, @intCast(files._len)),
    );
}

/// >>> io_uring_unregister_files(ring)
pub fn io_uring_unregister_files(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_FILES", c.io_uring_unregister_files(try ring.checkedPtr()));
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_register_files_update(ring: *Ring, fds: *const FileIndex, offset: ?u32) py.Error!i32 {
    const _offset = offset orelse 0;
    return support.register("IORING_REGISTER_FILES_UPDATE", c.io_uring_register_files_update(try ring.checkedPtr(), _offset, fds.fdSlice().ptr, @intCast(fds._len)));
}

/// >>> io_uring_register_eventfd(fd)
pub fn io_uring_register_eventfd(ring: *Ring, fd: i32) py.Error!i32 {
    return support.register("IORING_REGISTER_EVENTFD", c.io_uring_register_eventfd(try ring.checkedPtr(), fd));
}

pub fn io_uring_register_eventfd_async(ring: *Ring, fd: i32) py.Error!i32 {
    return support.register("IORING_REGISTER_EVENTFD_ASYNC", c.io_uring_register_eventfd_async(try ring.checkedPtr(), fd));
}

/// >>> io_uring_unregister_eventfd(ring)
pub fn io_uring_unregister_eventfd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_EVENTFD", c.io_uring_unregister_eventfd(try ring.checkedPtr()));
}

pub fn io_uring_register_probe(ring: *Ring, probe: *Probe, nr: u32) py.Error!i32 {
    _ = .{ ring, probe, nr };
    return py.raiseNotImplementedError("`io_uring_register_probe` - caught the zig bug!", .{});
    // return py.checkErrno(c.io_uring_register_probe(try ring.checkedPtr(), probe._io_uring_probe, nr));
}

/// >>> io_uring_register_personality(ring)
/// 123  # id
pub fn io_uring_register_personality(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_PERSONALITY", c.io_uring_register_personality(try ring.checkedPtr()));
}

/// >>> io_uring_unregister_personality(ring, id)
pub fn io_uring_unregister_personality(ring: *Ring, id: i32) py.Error!i32 {
    return support.register("IORING_UNREGISTER_PERSONALITY", c.io_uring_unregister_personality(try ring.checkedPtr(), id));
}

pub fn io_uring_register_restrictions(ring: *Ring, res: *Restriction) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_RESTRICTIONS",
        c.io_uring_register_restrictions(try ring.checkedPtr(), res._io_uring_restriction orelse return py.raiseValueError("`Restriction()` is empty: `add()` what is allowed", .{}), @intCast(res._len)),
    );
}

/// >>> io_uring_enable_rings(ring)
pub fn io_uring_enable_rings(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_ENABLE_RINGS", c.io_uring_enable_rings(try ring.checkedPtr()));
}

/// >>> io_uring_register_ring_fd(ring)
pub fn io_uring_register_ring_fd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_RING_FDS", c.io_uring_register_ring_fd(try ring.checkedPtr()));
}

/// >>> io_uring_unregister_ring_fd(ring)
pub fn io_uring_unregister_ring_fd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_RING_FDS", c.io_uring_unregister_ring_fd(try ring.checkedPtr()));
}

/// >>> io_uring_close_ring_fd(ring)
pub fn io_uring_close_ring_fd(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_close_ring_fd(try ring.checkedPtr()));
}

pub fn io_uring_register_buf_ring(ring: *Ring, reg: *BufReg, flags: ?u32) py.Error!i32 {
    const _flags: u32 = if (flags) |f| f else 0;
    return support.register("IORING_REGISTER_PBUF_RING", c.io_uring_register_buf_ring(try ring.checkedPtr(), &reg._io_uring_buf_reg, _flags));
}

pub fn io_uring_unregister_buf_ring(ring: *Ring, bgid: i32) py.Error!i32 {
    return support.register("IORING_UNREGISTER_PBUF_RING", c.io_uring_unregister_buf_ring(try ring.checkedPtr(), bgid));
}

/// The kernel's current head of the buffer ring `buf_group` (how many buffers it has used).
///
/// Example
///     >>> io_uring_buf_ring_head(ring, 1)
///     0
pub fn io_uring_buf_ring_head(ring: *Ring, buf_group: i32) py.Error!u16 {
    var head: u16 = 0;
    _ = try support.register("IORING_REGISTER_PBUF_STATUS", c.io_uring_buf_ring_head(try ring.checkedPtr(), buf_group, &head));
    return head;
}

pub fn io_uring_register_sync_cancel(ring: *Ring, reg: *SyncCancelReg) py.Error!i32 {
    return support.register("IORING_REGISTER_SYNC_CANCEL", c.io_uring_register_sync_cancel(try ring.checkedPtr(), &reg._io_uring_sync_cancel_reg));
}

pub fn io_uring_register_sync_msg(sqe: *Sqe) py.Error!i32 {
    return support.register("IORING_REGISTER_SEND_MSG_RING", c.io_uring_register_sync_msg(&sqe._io_uring_sqe.?[0]));
}

pub fn io_uring_register_file_alloc_range(ring: *Ring, off: u32, len: u32) py.Error!i32 {
    return support.register("IORING_REGISTER_FILE_ALLOC_RANGE", c.io_uring_register_file_alloc_range(try ring.checkedPtr(), off, len));
}

pub fn io_uring_register_napi(ring: *Ring, napi: *Napi) py.Error!i32 {
    return support.register("IORING_REGISTER_NAPI", c.io_uring_register_napi(try ring.checkedPtr(), &napi._io_uring_napi));
}

pub fn io_uring_unregister_napi(ring: *Ring, napi: *Napi) py.Error!i32 {
    return support.register("IORING_UNREGISTER_NAPI", c.io_uring_unregister_napi(try ring.checkedPtr(), &napi._io_uring_napi));
}

pub fn io_uring_register_ifq(ring: *Ring, reg: *ZcrxIfqReg) py.Error!i32 {
    return support.register("IORING_REGISTER_ZCRX_IFQ", c.io_uring_register_ifq(try ring.checkedPtr(), ifqReg(reg)));
}

/// >>> io_uring_register_query(Query(IO_URING_QUERY_SCQ))
///
/// Note
///     - Needs no ring. Refer to `help(Query)`.
pub fn io_uring_register_query(query: *Query) py.Error!i32 {
    // `query_data` is an address: set it at each call.
    query._hdr.query_data = @intFromPtr(&query._data);
    query._hdr.size = @sizeOf(@TypeOf(query._data));
    query._hdr.next_entry = 0;
    return support.register("IORING_REGISTER_QUERY", c.io_uring_register_query(&query._hdr));
}

pub fn io_uring_register_zcrx_ctrl(ring: *Ring, ctrl: *ZcrxCtrl) py.Error!i32 {
    return support.register("IORING_REGISTER_ZCRX_CTRL", c.io_uring_register_zcrx_ctrl(try ring.checkedPtr(), &ctrl._zcrx_ctrl));
}

pub fn io_uring_register_clock(ring: *Ring, arg: *ClockRegister) py.Error!i32 {
    return support.register("IORING_REGISTER_CLOCK", c.io_uring_register_clock(try ring.checkedPtr(), &arg._io_uring_clock_register));
}

pub fn io_uring_register_bpf_filter(ring: *Ring, bpf: *Bpf) py.Error!i32 {
    return support.register("IORING_REGISTER_BPF_FILTER", c.io_uring_register_bpf_filter(try ring.checkedPtr(), &bpf._io_uring_bpf));
}

pub fn io_uring_register_bpf_filter_task(bpf: *Bpf) py.Error!i32 {
    return support.register("IORING_REGISTER_BPF_FILTER", c.io_uring_register_bpf_filter_task(&bpf._io_uring_bpf));
}

pub fn io_uring_get_events(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_get_events(try ring.checkedPtr()));
}

pub fn io_uring_submit_and_get_events(ring: *Ring) py.Error!i32 {
    defer ring.releaseSubmitted(); // the kernel has read the prepared paths
    return py.checkErrno(c.io_uring_submit_and_get_events(try ring.checkedPtr()));
}

pub fn io_uring_enter(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sig: *SigsetT) py.Error!i32 {
    return py.checkErrno(c.io_uring_enter(fd, to_submit, min_complete, flags, sig._sigset_t));
}

pub fn io_uring_enter2(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sz: usize, arg: ?usize) py.Error!i32 {
    return py.checkErrno(c.io_uring_enter2(fd, to_submit, min_complete, flags, if (arg) |a| @ptrFromInt(a) else null, sz));
}

pub fn io_uring_setup(entries: u32, p: *Param) py.Error!i32 {
    return support.setup(c.io_uring_setup(entries, &p._io_uring_params), p._io_uring_params.flags);
}

pub fn io_uring_register(fd: u32, opcode: u32, nr_args: u32, arg: ?usize) py.Error!i32 {
    return support.registerOp(opcode, c.io_uring_register(fd, opcode, if (arg) |a| @ptrFromInt(a) else null, nr_args));
}

/// `reg` with `region_uptr` pointing at its description (which lives in the same object).
fn regionReg(reg: *MemRegionReg) *c.io_uring_mem_region_reg {
    reg._io_uring_mem_region_reg.region_uptr = @intFromPtr(&reg._desc);
    return &reg._io_uring_mem_region_reg;
}

/// `reg` with `area_ptr` and `region_ptr` pointing at their descriptions (in the same object).
fn ifqReg(reg: *class.ZcrxIfqReg) *c.io_uring_zcrx_ifq_reg {
    reg._io_uring_zcrx_ifq_reg.area_ptr = @intFromPtr(&reg._area);
    reg._io_uring_zcrx_ifq_reg.region_ptr = @intFromPtr(&reg._region);
    return &reg._io_uring_zcrx_ifq_reg;
}

pub fn io_uring_register_region(ring: *Ring, reg: *MemRegionReg) py.Error!i32 {
    return support.register("IORING_REGISTER_MEM_REGION", c.io_uring_register_region(try ring.checkedPtr(), regionReg(reg)));
}

/// Note
///     - `OSError` if the kernel refuses (C liburing's `err` out-parameter is the error number).
///
/// Type
///     return: BufRing
pub fn io_uring_setup_buf_ring(ring: *Ring, nentries: u32, bgid: i32, flags: u32) py.Error!*Object {
    var err: c_int = 0;
    if (c.io_uring_setup_buf_ring(try ring.checkedPtr(), nentries, bgid, flags, &err)) |br| {
        return class.BufRingType.new(.{ ._io_uring_buf_ring = br });
    }
    _ = try py.checkErrno(if (err < 0) err else -err);
    return py.raiseRuntimeError("`io_uring_setup_buf_ring` - could not be initialized!", .{});
}

pub fn io_uring_free_buf_ring(ring: *Ring, br: *BufRing, nentries: u32, bgid: i32) py.Error!i32 {
    return py.checkErrno(c.io_uring_free_buf_ring(try ring.checkedPtr(), br._io_uring_buf_ring.?, nentries, bgid));
}

pub fn io_uring_set_iowait(ring: *Ring, enable_iowait: bool) py.Error!i32 {
    return py.checkErrno(c.io_uring_set_iowait(try ring.checkedPtr(), enable_iowait));
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
    return class.CqeIterType.new(.{
        ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(try ring.checkedPtr()),
        ._ring = class.keep(class.RingType.object(ring)),
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
    _ = try class.RingType.data(ring).checkedPtr();
    class.setOwned(&cqe._ring, ring); // `cqe[i]` follows this ring's completion queue
    return c.io_uring_cqe_iter_next(&iter._io_uring_cqe_iter, &cqe._io_uring_cqe);
}

pub fn io_uring_cq_advance(ring: *Ring, nr: u32) py.Error!void {
    c.io_uring_cq_advance(try ring.checkedPtr(), nr);
}

pub fn io_uring_cqe_seen(ring: *Ring, cqe: *CQE) py.Error!void {
    c.io_uring_cqe_seen(try ring.checkedPtr(), try cqe.cqePtr());
}

/// >>> io_uring_sqe_set_data(sqe, python_object)
///
/// Warning
///     - Not tested!!!
pub fn io_uring_sqe_set_data(sqe: *SQE, data: usize) py.Error!void {
    c.io_uring_sqe_set_data(try sqe.sqePtr(), @ptrFromInt(data)); // `data`: an address, as `PyLong_AsVoidPtr` read it
}

/// >>> python_object = io_uring_cqe_get_data(cqe[0])
///
/// Warning
///     - Not tested!!!
pub fn io_uring_cqe_get_data(cqe: *CQE) py.Error!usize {
    const ptr: ?*anyopaque = c.io_uring_cqe_get_data(try cqe.cqePtr()); // NOTE: This can return garbage data!
    if (ptr) |p| return @intFromPtr(p);
    return py.raiseValueError("`io_uring_cqe_get_data()` - received `null`", .{});
}

/// >>> io_uring_sqe_set_data64(sqe, 123)
pub fn io_uring_sqe_set_data64(sqe: *SQE, data: u64) py.Error!void {
    c.io_uring_sqe_set_data64(try sqe.sqePtr(), data);
}

/// >>> io_uring_cqe_get_data64(cqe)
/// 123
pub fn io_uring_cqe_get_data64(cqe: *CQE) py.Error!u64 {
    return c.io_uring_cqe_get_data64(try cqe.cqePtr());
}

/// >>> io_uring_sqe_set_flags(sqe, IOSQE_IO_HARDLINK)
pub fn io_uring_sqe_set_flags(sqe: *SQE, flags: u32) py.Error!void {
    c.io_uring_sqe_set_flags(try sqe.sqePtr(), flags);
}

/// >>> io_uring_sqe_set_buf_group(sqe, 123)
pub fn io_uring_sqe_set_buf_group(sqe: *SQE, bgid: i32) py.Error!void {
    c.io_uring_sqe_set_buf_group(try sqe.sqePtr(), bgid);
}

pub fn io_uring_prep_splice(
    sqe: *SQE,
    fd_in: i32,
    off_in: i64,
    fd_out: i32,
    off_out: i64,
    nbytes: u32,
    splice_flags: u32,
) py.Error!void {
    c.io_uring_prep_splice(try sqe.sqePtr(), fd_in, off_in, fd_out, off_out, nbytes, splice_flags);
}

pub fn io_uring_prep_tee(sqe: *SQE, fd_in: i32, fd_out: i32, nbytes: u32, splice_flags: u32) py.Error!void {
    c.io_uring_prep_tee(try sqe.sqePtr(), fd_in, fd_out, nbytes, splice_flags);
}

/// Example
///     >>> buffer = [bytearray(6), bytearray(4)]
///     >>> iovec = Iovec(buffer)
///     >>> io_uring_prep_readv(sqe, fd, iovec)
///     ...
///     >>> buffer
///     [bytearray(b"hi... "), bytearray(b"bye!")]
///
/// Note
///     - `io_uring_prep_readv` includes `io_uring_prep_readv2` feature as well.
pub fn io_uring_prep_readv(sqe: *SQE, fd: i32, iovec: *const Iovec, offset: ?u64, flags: ?i32) py.Error!void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_readv2(try sqe.sqePtr(), fd, iovec._iovec.?, @intCast(iovec._len), _offset, _flags);
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> buffer = bytearray(5)
///     >>> io_uring_prep_read_fixed(sqe, fd, buffer, buf_index)
///     ...
///     >>> buffer
///     bytearray(b"hi...")
pub fn io_uring_prep_read_fixed(sqe: *SQE, fd: i32, buff: py.WritableBuffer, buf_index: i32, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_read_fixed(try sqe.sqePtr(), fd, buff.data.ptr, try py.narrow(c_uint, buff.data.len, "`io_uring_prep_read_fixed(buff)` length"), _offset, buf_index);
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> buffer = [bytearray(5), bytearray(4)]
///     >>> iovec = Iovec(buffer)
///     >>> io_uring_prep_readv_fixed(sqe, fd, iovec, buf_index)
///     ...
///     >>> buffer
///     [bytearray(b"hi..."), bytearray(b"bye!")]
pub fn io_uring_prep_readv_fixed(
    sqe: *SQE,
    fd: i32,
    iovec: *const Iovec,
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) py.Error!void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_readv_fixed(try sqe.sqePtr(), fd, iovec._iovec.?, @intCast(iovec._len), _offset, _flags, buf_index);
}

/// Example
///     >>> buffer = [b'hi... '), b'bye!']
///     >>> iovec = Iovec(buffer)
///     >>> io_uring_prep_writev(sqe, fd, iovec)
///     ... ...
///     >>> cqe[0].res
///     10
///
/// Note
///     - `io_uring_prep_writev` includes `io_uring_prep_writev2` feature as well.
pub fn io_uring_prep_writev(sqe: *SQE, fd: i32, iovec: *const Iovec, offset: ?u64, flags: ?i32) py.Error!void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_writev2(try sqe.sqePtr(), fd, iovec._iovec.?, @intCast(iovec._len), _offset, _flags);
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> io_uring_prep_write_fixed(sqe, fd, b'hi...', buf_index)
///     ... ...
///     >>> cqe[0].res
///     5
pub fn io_uring_prep_write_fixed(sqe: *SQE, fd: i32, buff: py.Buffer, buf_index: i32, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_write_fixed(try sqe.sqePtr(), fd, buff.data.ptr, try py.narrow(c_uint, buff.data.len, "`io_uring_prep_write_fixed(buff)` length"), _offset, buf_index);
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> buffer = [b"hi... ", b"bye!"]
///     >>> iovec = Iovec(buffer)
///     >>> io_uring_prep_writev_fixed(sqe, fd, iovec, buf_index)
///     ...
///     >>> cqe[0].res
///     10
pub fn io_uring_prep_writev_fixed(
    sqe: *SQE,
    fd: i32,
    iovec: *const Iovec,
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) py.Error!void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_writev_fixed(try sqe.sqePtr(), fd, iovec._iovec.?, @intCast(iovec._len), _offset, _flags, buf_index);
}

pub fn io_uring_prep_recvmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg(try sqe.sqePtr(), fd, &msg._msghdr, _flags);
    try h.keepUntilSubmit(sqe, class.MsghdrType.object(msg)); // read at submit; hold it until the completion
}

pub fn io_uring_prep_recvmsg_multishot(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg_multishot(try sqe.sqePtr(), fd, &msg._msghdr, _flags);
    try h.keepUntilSubmit(sqe, class.MsghdrType.object(msg));
}

pub fn io_uring_prep_sendmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_sendmsg(try sqe.sqePtr(), fd, &msg._msghdr, _flags);
    try h.keepUntilSubmit(sqe, class.MsghdrType.object(msg));
}

pub fn io_uring_prep_poll_add(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!void {
    c.io_uring_prep_poll_add(try sqe.sqePtr(), fd, poll_mask);
}

pub fn io_uring_prep_poll_multishot(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!void {
    c.io_uring_prep_poll_multishot(try sqe.sqePtr(), fd, poll_mask);
}

pub fn io_uring_prep_poll_remove(sqe: *SQE, user_data: u64) py.Error!void {
    c.io_uring_prep_poll_remove(try sqe.sqePtr(), user_data);
}

pub fn io_uring_prep_poll_update(
    sqe: *SQE,
    old_user_data: u64,
    new_user_data: u64,
    poll_mask: u32,
    flags: ?u32,
) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_poll_update(try sqe.sqePtr(), old_user_data, new_user_data, poll_mask, _flags);
}

pub fn io_uring_prep_fsync(sqe: *SQE, fd: i32, fsync_flags: ?u32) py.Error!void {
    const _flags = fsync_flags orelse 0;
    c.io_uring_prep_fsync(try sqe.sqePtr(), fd, _flags);
}

/// >>> io_uring_prep_nop(sqe)
pub fn io_uring_prep_nop(sqe: *SQE) py.Error!void {
    c.io_uring_prep_nop(try sqe.sqePtr());
}

/// >>> io_uring_prep_nop128(sqe)
pub fn io_uring_prep_nop128(sqe: *SQE) py.Error!void {
    c.io_uring_prep_nop128(try sqe.sqePtr());
}

pub fn io_uring_prep_timeout(sqe: *SQE, ts: *Timespec, count: u32, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout(try sqe.sqePtr(), ts._timespec, count, _flags);
    try h.keepUntilSubmit(sqe, class.TimespecType.object(ts)); // the kernel reads `ts` at submit
}

pub fn io_uring_prep_timeout_remove(sqe: *SQE, user_data: u64, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_remove(try sqe.sqePtr(), user_data, _flags);
}

pub fn io_uring_prep_timeout_update(sqe: *SQE, ts: *Timespec, user_data: u64, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_update(try sqe.sqePtr(), ts._timespec, user_data, _flags);
    try h.keepUntilSubmit(sqe, class.TimespecType.object(ts));
}

/// Example
///     >>> addr = Sockaddr(AF_INET, "127.0.0.1", 12345)
///     ... ...
///     >>> io_uring_prep_accept(sqe, fd, addr)
pub fn io_uring_prep_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!void {
    const _flags = flags orelse 0;

    if (addr) |a| return c.io_uring_prep_accept(try sqe.sqePtr(), fd, a.addrPtr(), a._socklen, _flags);
    c.io_uring_prep_accept(try sqe.sqePtr(), fd, null, null, _flags);
}

/// Note
///     - Function argument `file_index` position has changed for C origin for better usability.
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
pub fn io_uring_prep_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, file_index: ?u32, flags: ?i32) py.Error!void {
    const _flags = flags orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    if (addr) |a| return c.io_uring_prep_accept_direct(
        try sqe.sqePtr(),
        fd,
        a.addrPtr(),
        a._socklen,
        _flags,
        _file_index,
    );
    c.io_uring_prep_accept_direct(try sqe.sqePtr(), fd, null, null, _flags, _file_index);
}

pub fn io_uring_prep_multishot_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!void {
    const _flags = flags orelse 0;
    if (addr) |a| return c.io_uring_prep_multishot_accept(try sqe.sqePtr(), fd, a.addrPtr(), a._socklen, _flags);
    c.io_uring_prep_multishot_accept(try sqe.sqePtr(), fd, null, null, _flags);
}

pub fn io_uring_prep_multishot_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!void {
    const _flags = flags orelse 0;
    if (addr) |a| {
        return c.io_uring_prep_multishot_accept_direct(
            try sqe.sqePtr(),
            fd,
            a.addrPtr(),
            a._socklen,
            _flags,
        );
    }
    c.io_uring_prep_multishot_accept_direct(try sqe.sqePtr(), fd, null, null, _flags);
}

pub fn io_uring_prep_cancel64(sqe: *SQE, user_data: u64, flags: ?i32) py.Error!void {
    c.io_uring_prep_cancel64(try sqe.sqePtr(), user_data, flags orelse 0);
}

pub fn io_uring_prep_cancel(sqe: *SQE, user_data: usize, flags: ?i32) py.Error!void {
    c.io_uring_prep_cancel(try sqe.sqePtr(), @ptrFromInt(user_data), flags orelse 0);
}

pub fn io_uring_prep_cancel_fd(sqe: *SQE, fd: i32, flags: ?u32) py.Error!void {
    c.io_uring_prep_cancel_fd(try sqe.sqePtr(), fd, flags orelse 0);
}

pub fn io_uring_prep_link_timeout(sqe: *SQE, ts: *Timespec, flags: u32) py.Error!void {
    c.io_uring_prep_link_timeout(try sqe.sqePtr(), ts._timespec, flags);
    try h.keepUntilSubmit(sqe, class.TimespecType.object(ts));
}

const SockaddrType = @import("socket.zig").SockaddrType;

pub fn io_uring_prep_connect(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!void {
    c.io_uring_prep_connect(try sqe.sqePtr(), fd, addr.addrPtr(), addr._socklen);
    try h.keepUntilSubmit(sqe, SockaddrType.object(addr)); // read at submit
}

pub fn io_uring_prep_bind(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!void {
    c.io_uring_prep_bind(try sqe.sqePtr(), fd, addr.addrPtr(), addr._socklen);
    try h.keepUntilSubmit(sqe, SockaddrType.object(addr));
}

pub fn io_uring_prep_listen(sqe: *SQE, fd: i32, backlog: i32) py.Error!void {
    c.io_uring_prep_listen(try sqe.sqePtr(), fd, backlog);
}

pub fn io_uring_prep_epoll_wait(sqe: *SQE, fd: i32, events: *EpollEvent, maxevents: i32, flags: ?u32) py.Error!void {
    if (events._owner != null or maxevents < 1 or maxevents > events._len)
        return py.raiseValueError("`maxevents` must be 1..{d}, the size of `EpollEvent(no=...)`", .{events._len});
    c.io_uring_prep_epoll_wait(try sqe.sqePtr(), fd, @ptrCast(events._events.?), maxevents, flags orelse 0);
}

pub fn io_uring_prep_files_update(sqe: *SQE, fds: *FileIndex, offset: ?i32) py.Error!void {
    // note: a `FileIndex` (not a list) so the fds stay alive until the kernel reads them.
    c.io_uring_prep_files_update(try sqe.sqePtr(), fds.fdSlice().ptr, @intCast(fds._len), offset orelse 0);
}

/// Mode
///     FALLOC_FL_KEEP_SIZE       # default is extend size
///     FALLOC_FL_PUNCH_HOLE      # de-allocates range
///     FALLOC_FL_NO_HIDE_STALE   # reserved codepoint
///     FALLOC_FL_COLLAPSE_RANGE
///     FALLOC_FL_ZERO_RANGE
///     FALLOC_FL_INSERT_RANGE
///     FALLOC_FL_UNSHARE_RANGE
pub fn io_uring_prep_fallocate(sqe: *SQE, fd: i32, mode: i32, offset: u64, len: u64) py.Error!void {
    c.io_uring_prep_fallocate(try sqe.sqePtr(), fd, mode, offset, len);
}

/// Open File
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_open(sqe, b'./file.ext')
///     >>> sqe.user_data = 123
///
/// Note
///     - Function argument `dfd` has been moved to end from how it is in C function.
///     - `io_uring_prep_open` includes `io_uring_prep_openat` as well.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_open(sqe: *SQE, path: *Object, flags: ?i32, mode: ?c.mode_t, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse 0;
    c.io_uring_prep_openat(try sqe.sqePtr(), _dfd, path_.path, _flags, _mode);
}

/// Open Direct
///
/// Example
///     >>> indexed = FileIndex([-1, -1, -1, -1])
///     >>> index = 3  # position of last ---^ `fds` registered
///     >>> io_uring_register_files(ring, fds)
///     >>> flags = liburing.O_TMPFILE | liburing.O_WRONLY
///     >>> sqe = liburing.io_uring_get_sqe(ring)
///     >>> io_uring_prep_open_direct(sqe, ".", flags, index)
///     ... ...
///     >>>.io_uring_prep_close_direct(sqe, index)
///     ... ...
///     >>> io_uring_unregister_files(ring)
///
/// Note
///     - Open direct does not use `fd` but `index`
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_open_direct` includes `io_uring_prep_openat_direct` as well.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_open_direct(
    sqe: *SQE,
    path: *Object,
    flags: ?i32,
    file_index: ?u32,
    mode: ?c.mode_t,
    dfd: ?i32,
) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse c.O_RDONLY;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat_direct(try sqe.sqePtr(), _dfd, path_.path, _flags, _mode, _file_index);
}

/// >>> io_uring_prep_close(sqe, fd)
pub fn io_uring_prep_close(sqe: *SQE, fd: i32) py.Error!void {
    c.io_uring_prep_close(try sqe.sqePtr(), fd);
}

/// >>> io_uring_prep_close_direct(sqe, file_index)
pub fn io_uring_prep_close_direct(sqe: *SQE, file_index: u32) py.Error!void {
    c.io_uring_prep_close_direct(try sqe.sqePtr(), file_index);
}

/// Example
///     >>> buf = bytearray(5)
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_read(sqe, fd, buf)
///     ... ...
///     >>> cqe[0].res
///     5
///     ... ...
///     >>> buf
///     bytearray(b'hi...')
pub fn io_uring_prep_read(sqe: *SQE, fd: i32, buf: py.WritableBuffer, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_read(try sqe.sqePtr(), fd, buf.data.ptr, try py.narrow(c_uint, buf.data.len, "`io_uring_prep_read(buf)` length"), _offset);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_read_multishot(sqe: *SQE, fd: i32, buf_group: i32, nbytes: ?u32, offset: ?u64) py.Error!void {
    const _nbytes = nbytes orelse 0;
    const _offset = offset orelse 0;
    c.io_uring_prep_read_multishot(try sqe.sqePtr(), fd, _nbytes, _offset, buf_group);
}

/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_write(sqe, fd, b"hi...")
///     ... ...
///     >>> cqe.res
///     5
pub fn io_uring_prep_write(sqe: *SQE, fd: i32, buf: py.Buffer, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_write(try sqe.sqePtr(), fd, buf.data.ptr, try py.narrow(c_uint, buf.data.len, "`io_uring_prep_write(buf)` length"), _offset);
}

/// Statx
///
/// Type
///     sqe:    SQE
///     stat:   Statx
///     path: str | os.PathLike[str]
///     flags:  int
///     mask:   int
///     dfd:    int
///     return: None
///
/// Example
///     >>> stat = Statx()
///     >>> if sqe := io_uring_get_sqe(ring)
///     ...     io_uring_prep_statx(sqe, stat, __file__)
///     ... ...
///     >>> stat.isfile
///     True
///     >>> stat.size
///     123
///
/// Flag
///     AT_EMPTY_PATH
///     AT_NO_AUTOMOUNT
///     AT_SYMLINK_NOFOLLOW     # Do not follow symbolic links.
///     AT_STATX_SYNC_AS_STAT
///     AT_STATX_FORCE_SYNC
///     AT_STATX_DONT_SYNC
///
/// Mask
///     STATX_TYPE          # Want|got `stx_mode & S_IFMT`
///     STATX_MODE          # Want|got `stx_mode & ~S_IFMT`
///     STATX_NLINK         # Want|got `stx_nlink`
///     STATX_UID           # Want|got `stx_uid`
///     STATX_GID           # Want|got `stx_gid`
///     STATX_ATIME         # Want|got `stx_atime`
///     STATX_MTIME         # Want|got `stx_mtime`
///     STATX_CTIME         # Want|got `stx_ctime`
///     STATX_INO           # Want|got `stx_ino`
///     STATX_SIZE          # Want|got `stx_size`
///     STATX_BLOCKS        # Want|got `stx_blocks`
///     STATX_BASIC_STATS   # [All of the above]
///     STATX_BTIME         # Want|got `stx_btime`
///     STATX_MNT_ID        # Got `stx_mnt_id`
///     # note: not supported
///     # STATX_DIOALIGN      # Want/got direct I/O alignment info
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `STATX_ALL` is depreciated, use `STATX_BASIC_STATS | STATX_BTIME` which is set by default.
pub fn io_uring_prep_statx(sqe: *SQE, statxbuf: *Statx, path: *Object, flags: ?i32, mask: ?u32, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    const _mask = mask orelse c.STATX_BASIC_STATS | c.STATX_BTIME; // replaces `STATX_ALL` as its depreciated!
    const _flags = flags orelse 0;
    c.io_uring_prep_statx(try sqe.sqePtr(), _dfd, path_.path, _flags, _mask, &statxbuf._statx);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_fadvise(sqe: *SQE, fd: i32, len: u32, advice: i32, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise(try sqe.sqePtr(), fd, _offset, len, advice);
}

pub fn io_uring_prep_madvise(sqe: *SQE, addr: usize, length: u32, advice: i32) py.Error!void {
    c.io_uring_prep_madvise(try sqe.sqePtr(), @ptrFromInt(addr), length, advice);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_fadvise64(sqe: *SQE, fd: i32, len: c.off_t, advice: i32, offset: ?u64) py.Error!void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise64(try sqe.sqePtr(), fd, _offset, len, advice);
}

pub fn io_uring_prep_madvise64(sqe: *SQE, addr: usize, length: c.off_t, advice: i32) py.Error!void {
    c.io_uring_prep_madvise64(try sqe.sqePtr(), @ptrFromInt(addr), length, advice);
}

pub fn io_uring_prep_send(sqe: *SQE, sockfd: i32, buf: py.Buffer, flags: ?i32) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_send(try sqe.sqePtr(), sockfd, buf.data.ptr, buf.data.len, _flags);
}

pub fn io_uring_prep_send_bundle(sqe: *SQE, sockfd: i32, len: ?usize, flags: ?i32) py.Error!void {
    c.io_uring_prep_send_bundle(try sqe.sqePtr(), sockfd, len orelse 0, flags orelse 0);
}

pub fn io_uring_prep_send_set_addr(sqe: *SQE, dest_addr: *Sockaddr) py.Error!void {
    c.io_uring_prep_send_set_addr(try sqe.sqePtr(), dest_addr.addrPtr(), @intCast(dest_addr._socklen));
    try h.keepUntilSubmit(sqe, SockaddrType.object(dest_addr));
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_sendto(sqe: *SQE, sockfd: i32, buf: py.Buffer, addr: *Sockaddr, flags: ?i32) py.Error!void {
    c.io_uring_prep_sendto(
        try sqe.sqePtr(),
        sockfd,
        buf.data.ptr,
        buf.data.len,
        flags orelse 0,
        addr.addrPtr(),
        addr._socklen,
    );
    try h.keepUntilSubmit(sqe, SockaddrType.object(addr));
}

pub fn io_uring_prep_send_zc(sqe: *SQE, sockfd: i32, buf: py.Buffer, flags: ?i32, zc_flags: ?u32) py.Error!void {
    c.io_uring_prep_send_zc(try sqe.sqePtr(), sockfd, buf.data.ptr, buf.data.len, flags orelse 0, zc_flags orelse 0);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_send_zc_fixed(
    sqe: *SQE,
    sockfd: i32,
    buf: py.Buffer,
    buf_index: ?u32,
    flags: ?i32,
    zc_flags: ?u32,
) py.Error!void {
    c.io_uring_prep_send_zc_fixed(
        try sqe.sqePtr(),
        sockfd,
        buf.data.ptr,
        buf.data.len,
        flags orelse 0,
        zc_flags orelse 0,
        buf_index orelse 0,
    );
}

pub fn io_uring_prep_sendmsg_zc(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!void {
    c.io_uring_prep_sendmsg_zc(try sqe.sqePtr(), fd, &msg._msghdr, flags orelse 0);
    try h.keepUntilSubmit(sqe, class.MsghdrType.object(msg));
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///
/// Warning
///     - Coded but not tested!!!
pub fn io_uring_prep_sendmsg_zc_fixed(sqe: *SQE, fd: i32, msg: *Msghdr, buf_index: u32, flags: ?u32) py.Error!void {
    c.io_uring_prep_sendmsg_zc_fixed(try sqe.sqePtr(), fd, &msg._msghdr, flags orelse 0, buf_index);
    try h.keepUntilSubmit(sqe, class.MsghdrType.object(msg));
}

pub fn io_uring_prep_recv(sqe: *SQE, sockfd: i32, buf: ?py.WritableBuffer, flags: ?i32) py.Error!void {
    if (buf) |b| {
        c.io_uring_prep_recv(try sqe.sqePtr(), sockfd, b.data.ptr, b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv(try sqe.sqePtr(), sockfd, null, 0, flags orelse 0);
    }
}

pub fn io_uring_prep_recv_multishot(sqe: *SQE, sockfd: i32, buf: ?py.WritableBuffer, flags: ?i32) py.Error!void {
    if (buf) |b| {
        c.io_uring_prep_recv_multishot(try sqe.sqePtr(), sockfd, b.data.ptr, b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv_multishot(try sqe.sqePtr(), sockfd, null, 0, flags orelse 0);
    }
}

/// Checks that `buf` holds a message received by `io_uring_prep_recvmsg_multishot` (`ValueError` if it is too
/// short for the `namelen` and `controllen` of `msgh`) and gives its parts.
///
/// Type
///     return: RecvmsgOut
pub fn io_uring_recvmsg_validate(buf: *Object, msgh: *Msghdr) py.Error!*Object {
    const view = try py.WritableBuffer.from(buf);
    errdefer view.deinit();
    const len = try py.narrow(c_int, view.data.len, "`io_uring_recvmsg_validate(buf)` length");
    const out = c.io_uring_recvmsg_validate(view.data.ptr, len, &msgh._msghdr) orelse
        return py.raiseValueError("`io_uring_recvmsg_validate(buf)` - `buf` is too short for the header, name and control data", .{});
    // the view moves into the result, so the buffer stays locked (can not be resized) while it lives
    return class.RecvmsgOutType.new(.{ ._recvmsg_out = out, ._len = view.data.len, ._view = .{ .data = view.data, .view = view.view } });
}

/// The socket address the message came from (`bytes`: the start of a `sockaddr`, `out.namelen` long).
pub fn io_uring_recvmsg_name(o: *RecvmsgOut) py.Bytes {
    const name: [*]const u8 = @ptrCast(c.io_uring_recvmsg_name(o._recvmsg_out.?));
    const room = o._len - @sizeOf(c.io_uring_recvmsg_out);
    return .{ .data = name[0..@min(o._recvmsg_out.?.namelen, room)] };
}

/// The first control message, or `None`.
///
/// Type
///     return: Cmsghdr | None
pub fn io_uring_recvmsg_cmsg_firsthdr(o: *RecvmsgOut, msgh: *Msghdr) py.Error!?*Object {
    const hdr = c.io_uring_recvmsg_cmsg_firsthdr(o._recvmsg_out.?, &msgh._msghdr) orelse return null;
    return try class.CmsghdrType.new(.{ ._cmsghdr = hdr, ._owner = class.keep(class.RecvmsgOutType.object(o)) });
}

/// The control message after `cmsg`, or `None`.
///
/// Type
///     return: Cmsghdr | None
pub fn io_uring_recvmsg_cmsg_nexthdr(o: *RecvmsgOut, msgh: *Msghdr, cmsg: *Cmsghdr) py.Error!?*Object {
    const hdr = c.io_uring_recvmsg_cmsg_nexthdr(o._recvmsg_out.?, &msgh._msghdr, cmsg._cmsghdr.?) orelse return null;
    return try class.CmsghdrType.new(.{ ._cmsghdr = hdr, ._owner = class.keep(class.RecvmsgOutType.object(o)) });
}

/// The data of the message (`bytes`, `out.payloadlen` long, or less if the buffer ends first).
pub fn io_uring_recvmsg_payload(o: *RecvmsgOut, msgh: *Msghdr) py.Bytes {
    const start: [*]const u8 = @ptrCast(c.io_uring_recvmsg_payload(o._recvmsg_out.?, &msgh._msghdr));
    const room: usize = @intCast(c.io_uring_recvmsg_payload_length(o._recvmsg_out.?, @intCast(o._len), &msgh._msghdr));
    return .{ .data = start[0..@min(o._recvmsg_out.?.payloadlen, room)] };
}

/// How many bytes the payload may take in a buffer of `buf_len`.
pub fn io_uring_recvmsg_payload_length(o: *RecvmsgOut, buf_len: i32, msgh: *Msghdr) u32 {
    return c.io_uring_recvmsg_payload_length(o._recvmsg_out.?, buf_len, &msgh._msghdr);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_openat2(sqe: *SQE, path: *Object, how: *OpenHow, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_openat2(try sqe.sqePtr(), _dfd, path_.path, &how._open_how);
}

/// Note
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_openat2_direct(sqe: *SQE, path: *Object, how: *OpenHow, file_index: ?u32, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat2_direct(try sqe.sqePtr(), _dfd, path_.path, &how._open_how, _file_index);
}

pub fn io_uring_prep_epoll_ctl(sqe: *SQE, epfd: i32, fd: i32, op: i32, ev: *EpollEvent) py.Error!void {
    c.io_uring_prep_epoll_ctl(try sqe.sqePtr(), epfd, fd, op, @ptrCast(&ev._events.?[ev._index]));
    try h.keepUntilSubmit(sqe, class.EpollEventType.object(ev)); // read at submit
}

/// Provides `nr` buffers of `len(addr) // nr` bytes each, laid out one after the other in `addr`.
///
/// Example
///     >>> area = bytearray(64)
///     >>> io_uring_prep_provide_buffers(sqe, area, 4, 1, 0)  # 4 buffers of 16 bytes: group 1, ids 0..3
///
/// Note
///     - Hold on to `addr` while the buffers are in use.
pub fn io_uring_prep_provide_buffers(sqe: *SQE, addr: py.WritableBuffer, nr: i32, bgid: i32, bid: i32) py.Error!void {
    if (nr <= 0) return py.raiseValueError("`io_uring_prep_provide_buffers(nr)` must be at least 1", .{});
    const each = addr.data.len / @as(usize, @intCast(nr)); // cast: nr > 0
    if (each == 0) return py.raiseValueError("`io_uring_prep_provide_buffers(addr)` is shorter than `nr` buffers", .{});
    c.io_uring_prep_provide_buffers(try sqe.sqePtr(), addr.data.ptr, try py.narrow(c_int, each, "`io_uring_prep_provide_buffers(addr)` buffer length"), nr, bgid, bid);
}

pub fn io_uring_prep_remove_buffers(sqe: *SQE, nr: i32, bgid: i32) py.Error!void {
    c.io_uring_prep_remove_buffers(try sqe.sqePtr(), nr, bgid);
}

pub fn io_uring_prep_shutdown(sqe: *SQE, fd: i32, how: i32) py.Error!void {
    c.io_uring_prep_shutdown(try sqe.sqePtr(), fd, how);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_unlink` includes `io_uring_prep_unlinkat` feature.
///
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_unlink(sqe: *SQE, path: *Object, flags: ?i32, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    c.io_uring_prep_unlinkat(try sqe.sqePtr(), dfd orelse AT_FDCWD, path_.path, flags orelse 0);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_rename` includes `io_uring_prep_renameat` feature.
///
/// Type
///     oldpath: str | os.PathLike[str]
///     newpath: str | os.PathLike[str]
pub fn io_uring_prep_rename(
    sqe: *SQE,
    oldpath: *Object,
    newpath: *Object,
    flags: ?u32,
    olddfd: ?i32,
    newdfd: ?i32,
) py.Error!void {
    const oldpath_ = try h.toPath(oldpath);
    defer oldpath_.deinit();
    try h.keepUntilSubmit(sqe, oldpath_.obj);
    const newpath_ = try h.toPath(newpath);
    defer newpath_.deinit();
    try h.keepUntilSubmit(sqe, newpath_.obj);
    const _flags = flags orelse 0;
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    c.io_uring_prep_renameat(try sqe.sqePtr(), _olddfd, oldpath_.path, _newdfd, newpath_.path, _flags);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_sync_file_range(sqe: *SQE, fd: i32, len: u32, offset: ?u64, flags: ?i32) py.Error!void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_sync_file_range(try sqe.sqePtr(), fd, len, _offset, _flags);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_mkdir` includes `io_uring_prep_mkdirat` feature.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_mkdir(sqe: *SQE, path: *Object, mode: c.mode_t, dfd: ?i32) py.Error!void {
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_mkdirat(try sqe.sqePtr(), _dfd, path_.path, mode);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_symlink` includes `io_uring_prep_symlinkat` feature.
///
/// Type
///     target: str | os.PathLike[str]
///     linkpath: str | os.PathLike[str]
pub fn io_uring_prep_symlink(sqe: *SQE, target: *Object, linkpath: *Object, newdirfd: ?i32) py.Error!void {
    const target_ = try h.toPath(target);
    defer target_.deinit();
    try h.keepUntilSubmit(sqe, target_.obj);
    const linkpath_ = try h.toPath(linkpath);
    defer linkpath_.deinit();
    try h.keepUntilSubmit(sqe, linkpath_.obj);
    const _newdirfd = newdirfd orelse AT_FDCWD;
    c.io_uring_prep_symlinkat(try sqe.sqePtr(), target_.path, _newdirfd, linkpath_.path);
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_link` includes `io_uring_prep_linkat` feature.
///
/// Type
///     oldpath: str | os.PathLike[str]
///     newpath: str | os.PathLike[str]
pub fn io_uring_prep_link(
    sqe: *SQE,
    oldpath: *Object,
    newpath: *Object,
    flags: ?i32,
    olddfd: ?i32,
    newdfd: ?i32,
) py.Error!void {
    const oldpath_ = try h.toPath(oldpath);
    defer oldpath_.deinit();
    try h.keepUntilSubmit(sqe, oldpath_.obj);
    const newpath_ = try h.toPath(newpath);
    defer newpath_.deinit();
    try h.keepUntilSubmit(sqe, newpath_.obj);
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    const _flags = flags orelse 0;
    c.io_uring_prep_linkat(try sqe.sqePtr(), _olddfd, oldpath_.path, _newdfd, newpath_.path, _flags);
}

pub fn io_uring_prep_msg_ring_cqe_flags(
    sqe: *SQE,
    fd: i32,
    len: u32,
    data: u64,
    flags: u32,
    cqe_flags: u32,
) py.Error!void {
    c.io_uring_prep_msg_ring_cqe_flags(try sqe.sqePtr(), fd, len, data, flags, cqe_flags);
}

pub fn io_uring_prep_msg_ring(sqe: *SQE, fd: i32, len: u32, data: u64, flags: ?u32) py.Error!void {
    c.io_uring_prep_msg_ring(try sqe.sqePtr(), fd, len, data, flags orelse 0);
}

pub fn io_uring_prep_msg_ring_fd(
    sqe: *SQE,
    fd: i32,
    source_fd: i32,
    target_fd: i32,
    data: u64,
    flags: ?u32,
) py.Error!void {
    c.io_uring_prep_msg_ring_fd(try sqe.sqePtr(), fd, source_fd, target_fd, data, flags orelse 0);
}

pub fn io_uring_prep_msg_ring_fd_alloc(sqe: *SQE, fd: i32, source_fd: i32, data: u64, flags: ?u32) py.Error!void {
    c.io_uring_prep_msg_ring_fd_alloc(try sqe.sqePtr(), fd, source_fd, data, flags orelse 0);
}

/// Type
///     name: str
///     path: str | os.PathLike[str]
pub fn io_uring_prep_getxattr(sqe: *SQE, name: *Object, value: py.WritableBuffer, path: *Object, len: u32) py.Error!void {
    const name_ = try py.fromPython([:0]const u8, name); // a `str`, read by the kernel at submit
    try h.keepUntilSubmit(sqe, name);
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    c.io_uring_prep_getxattr(try sqe.sqePtr(), name_, value.data.ptr, path_.path, len);
}

/// Type
///     name: str
///     path: str | os.PathLike[str]
pub fn io_uring_prep_setxattr(
    sqe: *SQE,
    name: *Object,
    value: py.Buffer,
    path: *Object,
    flags: i32,
    len: u32,
) py.Error!void {
    const name_ = try py.fromPython([:0]const u8, name); // a `str`, read by the kernel at submit
    try h.keepUntilSubmit(sqe, name);
    const path_ = try h.toPath(path);
    defer path_.deinit();
    try h.keepUntilSubmit(sqe, path_.obj);
    c.io_uring_prep_setxattr(
        try sqe.sqePtr(),
        name_,
        value.data.ptr,
        path_.path,
        flags,
        len,
    );
}

/// Type
///     name: str
pub fn io_uring_prep_fgetxattr(sqe: *SQE, fd: i32, name: *Object, value: py.WritableBuffer, len: u32) py.Error!void {
    const name_ = try py.fromPython([:0]const u8, name); // a `str`, read by the kernel at submit
    try h.keepUntilSubmit(sqe, name);
    c.io_uring_prep_fgetxattr(try sqe.sqePtr(), fd, name_, value.data.ptr, len);
}

/// Type
///     name: str
pub fn io_uring_prep_fsetxattr(sqe: *SQE, fd: i32, name: *Object, value: py.Buffer, flags: i32, len: u32) py.Error!void {
    const name_ = try py.fromPython([:0]const u8, name); // a `str`, read by the kernel at submit
    try h.keepUntilSubmit(sqe, name);
    c.io_uring_prep_fsetxattr(try sqe.sqePtr(), fd, name_, value.data.ptr, flags, len);
}

pub fn io_uring_prep_socket(sqe: *SQE, domain: i32, @"type": i32, protocol: ?i32, flags: ?u32) py.Error!void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    c.io_uring_prep_socket(try sqe.sqePtr(), domain, @"type", _protocol, _flags);
}

/// Note
///     - `io_uring_prep_socket_direct` includes `io_uring_prep_socket_direct_alloc` feature.
pub fn io_uring_prep_socket_direct(
    sqe: *SQE,
    domain: i32,
    Type: i32,
    protocol: ?i32,
    file_index: ?u32,
    flags: ?u32,
) py.Error!void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_socket_direct(try sqe.sqePtr(), domain, Type, _protocol, _file_index, _flags);
}

pub fn io_uring_prep_uring_cmd(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!void {
    c.io_uring_prep_uring_cmd(try sqe.sqePtr(), cmd_op, fd);
}

pub fn io_uring_prep_uring_cmd128(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!void {
    c.io_uring_prep_uring_cmd128(try sqe.sqePtr(), cmd_op, fd);
}

/// Example
///     >>> buf = bytearray((1).to_bytes(4, "little"))
///     >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_KEEPALIVE, buf)
///     # or
///     >>> buf = bytearray(b'eth1')
///     >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, ..., buf)
///
/// Opcode
///     io_uring_socket_op
///         SOCKET_URING_OP_SIOCINQ
///         SOCKET_URING_OP_SIOCOUTQ
///         SOCKET_URING_OP_GETSOCKOPT
///         SOCKET_URING_OP_SETSOCKOPT
///         SOCKET_URING_OP_TX_TIMESTAMP
///         SOCKET_URING_OP_GETSOCKNAME
///
/// Note
///     - remember to hold on to `buf` as new result will be populated into it.
///     - `cqe.res` will return `len()` of populating data(`buf`).
///     - min length of `buf` must be `4`.
///     - watch out for "big" or "little" endian, keep it same or it will switch to systems default.
pub fn io_uring_prep_cmd_sock(
    sqe: *SQE,
    cmd_op: i32,
    fd: i32,
    level: i32,
    optname: i32,
    optval: py.WritableBuffer,
) py.Error!void {
    c.io_uring_prep_cmd_sock(try sqe.sqePtr(), cmd_op, fd, level, optname, optval.data.ptr, try py.narrow(c_int, optval.data.len, "`io_uring_prep_cmd_sock(optval)` length"));
}

/// Example
///     >>> sockaddr = Sockaddr()
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cmd_getsockname(sqe, sockfd, sockaddr)
pub fn io_uring_prep_cmd_getsockname(sqe: *SQE, fd: i32, sockaddr: *Sockaddr, peer: ?i32) py.Error!void {
    c.io_uring_prep_cmd_getsockname(
        try sqe.sqePtr(),
        fd,
        sockaddr.addrPtr(),
        &sockaddr._socklen,
        peer orelse 0,
    );
}

pub fn io_uring_prep_waitid(
    sqe: *SQE,
    idtype: c.idtype_t,
    id: c.id_t,
    infop: *SigsetT,
    options: i32,
    flags: ?u32,
) py.Error!void {
    const _flags = flags orelse 0;
    c.io_uring_prep_waitid(try sqe.sqePtr(), idtype, id, @ptrCast(infop._sigset_t), options, _flags);
}

pub fn io_uring_prep_futex_wake(
    sqe: *SQE,
    futex: *Futex,
    val: u64,
    mask: u64,
    futex_flags: ?u32,
    flags: ?u32,
) py.Error!void {
    c.io_uring_prep_futex_wake(try sqe.sqePtr(), futex._futex, val, mask, futex_flags orelse 0, flags orelse 0);
}

pub fn io_uring_prep_futex_wait(
    sqe: *SQE,
    futex: *Futex,
    val: u64,
    mask: u64,
    futex_flags: ?u32,
    flags: ?u32,
) py.Error!void {
    c.io_uring_prep_futex_wait(try sqe.sqePtr(), futex._futex, val, mask, futex_flags orelse 0, flags orelse 0);
}

pub fn io_uring_prep_futex_waitv(sqe: *SQE, futex: *Futex, flags: ?u32) py.Error!void {
    if (futex._futex_waitv) |v| {
        c.io_uring_prep_futex_waitv(try sqe.sqePtr(), v, futex._len, flags orelse 0);
    } else return py.raiseValueError("`io_uring_prep_futex_waitv` - `vector` is not enabled in `Futex`", .{});
}

pub fn io_uring_prep_fixed_fd_install(sqe: *SQE, fd: i32, flags: ?u32) py.Error!void {
    c.io_uring_prep_fixed_fd_install(try sqe.sqePtr(), fd, flags orelse 0);
}

pub fn io_uring_prep_ftruncate(sqe: *SQE, fd: i32, len: ?c.loff_t) py.Error!void {
    const _len = len orelse 0;
    c.io_uring_prep_ftruncate(try sqe.sqePtr(), fd, _len);
}

pub fn io_uring_prep_cmd_discard(sqe: *SQE, fd: i32, offset: u64, nbytes: u64) py.Error!void {
    c.io_uring_prep_cmd_discard(try sqe.sqePtr(), fd, offset, nbytes);
}

/// The two fds of the new pipe are written into `fds` (read end, then write end) when the request completes.
///
/// Example
///     >>> fds = array.array("i", [-1, -1])  # or a `bytearray(8)`
///     >>> io_uring_prep_pipe(sqe, fds, O_CLOEXEC)
///     ... # after the completion: fds[0], fds[1]
///
/// Note
///     - Hold on to `fds` until the request has completed.
pub fn io_uring_prep_pipe(sqe: *SQE, fds: py.WritableBuffer, pipe_flags: i32) py.Error!void {
    c.io_uring_prep_pipe(try sqe.sqePtr(), try pipeFds(fds), pipe_flags);
}

/// Like `io_uring_prep_pipe`, but the pipe's fds go into the registered file table: `fds` gets the two
/// slots (`file_index` for the read end; `IORING_FILE_INDEX_ALLOC` lets the kernel pick both).
pub fn io_uring_prep_pipe_direct(sqe: *SQE, fds: py.WritableBuffer, pipe_flags: i32, file_index: ?u32) py.Error!void {
    c.io_uring_prep_pipe_direct(try sqe.sqePtr(), try pipeFds(fds), pipe_flags, file_index orelse c.IORING_FILE_INDEX_ALLOC);
}

/// `fds` as the `int[2]` the kernel fills in (`ValueError` if it is too small).
fn pipeFds(fds: py.WritableBuffer) py.Error![*]c_int {
    if (fds.data.len < 2 * @sizeOf(c_int)) return py.raiseValueError("`fds` must hold two ints (8 bytes)", .{});
    return @ptrCast(@alignCast(fds.data.ptr));
}

pub fn io_uring_sq_ready(ring: *Ring) py.Error!u32 {
    return c.io_uring_sq_ready(try ring.checkedPtr());
}

pub fn io_uring_sq_space_left(ring: *Ring) py.Error!u32 {
    return c.io_uring_sq_space_left(try ring.checkedPtr());
}

/// How many completion queue slots `cqe` takes: `1`, or `2` for a big (`IORING_CQE_F_32`) entry.
///
/// Example
///     >>> io_uring_cq_advance(ring, io_uring_cqe_nr(cqe[0]))
pub fn io_uring_cqe_nr(cqe: *class.CQE) py.Error!u32 {
    return c.io_uring_cqe_nr(try cqe.cqePtr());
}

/// Bytes the kernel needs to map a ring of `entries` with `flags`.
///
/// Example
///     >>> io_uring_memory_size(8, 0)
///     16384
pub fn io_uring_memory_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_memory_size(entries, flags));
}

pub fn io_uring_memory_size_params(entries: u32, p: *Param) py.Error!isize {
    return py.checkErrno(c.io_uring_memory_size_params(entries, &p._io_uring_params));
}

/// Bytes of locked memory (`RLIMIT_MEMLOCK`) a ring of `entries` with `flags` needs.
pub fn io_uring_mlock_size(entries: u32, flags: u32) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size(entries, flags));
}

pub fn io_uring_mlock_size_params(entries: u32, p: *Param) py.Error!isize {
    return py.checkErrno(c.io_uring_mlock_size_params(entries, &p._io_uring_params));
}

/// Fills `sqe` with the common fields: the building block of every `io_uring_prep_*`.
///
/// Example
///     >>> io_uring_prep_rw(sqe, IORING_OP_NOP, 0, 0, 0, 0)
///
/// Note
///     - Function arguments position has changed for C origin: `sqe` is first. `addr` is an address (int, `0` for NULL).
pub fn io_uring_prep_rw(sqe: *SQE, op: u8, fd: i32, addr: usize, len: u32, offset: u64) py.Error!void {
    c.io_uring_prep_rw(op, try sqe.sqePtr(), fd, if (addr == 0) null else @ptrFromInt(addr), len, offset);
}

/// Limits the cpus the ring's async workers (`io-wq`) may run on to those set in `mask` (`bytes` / `bytearray`
/// in the `cpu_set_t` layout, bit `n` of byte `n // 8` for cpu `n`).
///
/// Example
///     >>> io_uring_register_iowq_aff(ring, bytes([0b11]))  # cpus 0 and 1
pub fn io_uring_register_iowq_aff(ring: *Ring, mask: py.Buffer) py.Error!i32 {
    return support.register("IORING_REGISTER_IOWQ_AFF", c.io_uring_register_iowq_aff(try ring.checkedPtr(), mask.data.len, @ptrCast(@alignCast(mask.data.ptr))));
}

pub fn io_uring_unregister_iowq_aff(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_IOWQ_AFF", c.io_uring_unregister_iowq_aff(try ring.checkedPtr()));
}

/// Sets the most `io-wq` workers the ring may run: `bounded` (regular files) and `unbounded` (sockets, ...);
/// `0` leaves one as is. Gives the previous `(bounded, unbounded)`.
///
/// Example
///     >>> io_uring_register_iowq_max_workers(ring, 0, 0)  # just read the current limits
///     (4, 8)
pub fn io_uring_register_iowq_max_workers(ring: *Ring, bounded: u32, unbounded: u32) py.Error!struct { u32, u32 } {
    var values = [2]c_uint{ bounded, unbounded };
    _ = try support.register("IORING_REGISTER_IOWQ_MAX_WORKERS", c.io_uring_register_iowq_max_workers(try ring.checkedPtr(), &values));
    return .{ values[0], values[1] };
}

pub fn io_uring_sqring_wait(ring: *Ring) py.Error!i32 {
    return c.io_uring_sqring_wait(try ring.checkedPtr());
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
    return py.checkErrno(c.io_uring_wait_cqe_nr(try ring.checkedPtr(), cqe.outFor(ring), wait_nr));
}

/// >>> io_uring_peek_cqe(ring, cqe)
pub fn io_uring_peek_cqe(ring: *Ring, cqe_ptr: *Cqe) py.Error!i32 {
    return py.checkErrno(c.io_uring_peek_cqe(try ring.checkedPtr(), cqe_ptr.outFor(ring)));
}

pub fn io_uring_wait_cqe(ring: *Ring, cqe: *Cqe) py.Error!i32 {
    return py.checkErrno(c.io_uring_wait_cqe(try ring.checkedPtr(), cqe.outFor(ring)));
}

pub fn io_uring_buf_ring_mask(ring_entries: u32) i32 {
    return c.io_uring_buf_ring_mask(ring_entries);
}

pub fn io_uring_buf_ring_init(br: *BufRing) void {
    c.io_uring_buf_ring_init(br._io_uring_buf_ring.?);
}

pub fn io_uring_buf_ring_add(br: *BufRing, addr: py.Buffer, bid: u16, mask: i32, buf_offset: ?i32) py.Error!void {
    const _buf_offset = buf_offset orelse 0;
    c.io_uring_buf_ring_add(
        br._io_uring_buf_ring.?,
        @constCast(addr.data.ptr),
        try py.narrow(c_uint, addr.data.len, "`io_uring_buf_ring_add(addr)` length"),
        bid,
        mask,
        _buf_offset,
    );
}

pub fn io_uring_buf_ring_advance(br: *BufRing, count: i32) void {
    c.io_uring_buf_ring_advance(br._io_uring_buf_ring.?, count);
}

pub fn io_uring_buf_ring_cq_advance(ring: *Ring, br: *BufRing, count: i32) py.Error!void {
    c.io_uring_buf_ring_cq_advance(try ring.checkedPtr(), br._io_uring_buf_ring.?, count);
}

pub fn io_uring_buf_ring_available(ring: *Ring, br: *BufRing, bgid: u16) py.Error!i32 {
    return c.io_uring_buf_ring_available(try ring.checkedPtr(), br._io_uring_buf_ring.?, bgid);
}

/// Example
///     >>> if sqe := io_uring_get_sqe(ring):
///     ...   # do stuff...
///
/// Type
///     return: SQE | None
pub fn io_uring_get_sqe(ring: *Ring) py.Error!?*Object {
    if (c.io_uring_get_sqe(try ring.checkedPtr())) |sqe| {
        return try class.SQEType.new(.{ ._sqe = sqe, ._owner = class.keep(class.RingType.object(ring)) });
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
    if (c.io_uring_get_sqe128(r)) |sqe| {
        return try class.SQEType.new(.{ ._sqe = sqe, ._owner = class.keep(class.RingType.object(ring)) });
    }
    return null; // None
}

/// Liburing Version Major
///
/// Note
///     - `io_uring_major_version` has been renamed to `liburing_version_major`
pub fn liburing_version_major() i32 {
    return c.io_uring_major_version();
}

/// Liburing Version Minor
///
/// Note
///     - `io_uring_minor_version` has been renamed to `liburing_version_minor`
pub fn liburing_version_minor() i32 {
    return c.io_uring_minor_version();
}

/// Liburing Version Check
///
/// Note
///     - `io_uring_check_version` has been renamed to `liburing_version_check`
pub fn liburing_version_check(major: u16, minor: u16) bool {
    return c.io_uring_check_version(major, minor);
}
