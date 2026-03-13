//! Liburing - io_uring related functions
const c = @import("c.zig").c;
const e = @import("error.zig");
const oz = @import("PyOZ");
const std = @import("std");
const FileIndex = @import("helper.zig").FileIndex;
const class = @import("class.zig");
const Statx = @import("statx.zig").Statx;
const AT_FDCWD = @import("const.zig").AT_FDCWD;
const Sockaddr = @import("socket.zig").Sockaddr;

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
const Ring = class.Ring;
const CQE = class.CQE;
const Cqe = class.Cqe;
const SQE = class.SQE;
const Sqe = class.Sqe;
const Bpf = class.Bpf;

///Example
///    >>> probe = io_uring_get_probe_ring(ring)
///    ... ...
///    >>> io_uring_free_probe(probe)
///
///Note
///    - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
pub fn io_uring_get_probe_ring(ring: *Ring) ?Probe {
    if (c.io_uring_get_probe_ring(ring._io_uring)) |p| return .{ ._io_uring_probe = p };
    return oz.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe_ring()`");
}

///>>> io_uring_get_probe()
pub fn io_uring_get_probe() ?Probe {
    if (c.io_uring_get_probe()) |p| return .{ ._io_uring_probe = p };
    return oz.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe()`");
}

///>>> io_uring_free_probe(probe)
pub fn io_uring_free_probe(probe: *Probe) void {
    if (probe._io_uring_probe) |p| {
        c.io_uring_free_probe(p);
        probe._io_uring_probe = null;
    }
}

///>>> io_uring_opcode_supported(probe, op)
/// True # or False
pub fn io_uring_opcode_supported(probe: *Probe, op: i32) bool {
    return (c.io_uring_opcode_supported(probe._io_uring_probe, op) == 1);
}

///Warning
///    - Coded but not tested!!!
pub fn io_uring_queue_init_mem(entries: u32, ring: *Ring, p: *Param, buf: ?*anyopaque, buf_size: usize) ?i32 {
    return e.trap_error(c.io_uring_queue_init_mem(entries, ring._io_uring, p._io_uring_params, buf, buf_size));
}

pub fn io_uring_queue_init_params(entries: u32, ring: *Ring, param: *Param) ?i32 {
    return e.trap_error(c.io_uring_queue_init_params(entries, ring._io_uring, param._io_uring_params));
}

///Setup `Ring` Submission & Completion Queues
///
///Example
///    >>> ring = Ring()
///    >>> try:
///    ...     io_uring_queue_init(1024, ring)
///    ...     # do stuff ...
///    >>> finally:
///    ...     io_uring_queue_exit(ring)
pub fn io_uring_queue_init(entries: u32, ring: *Ring, flags: ?u32) ?i32 {
    if (ring._io_uring) |io_uring| {
        if (io_uring.ring_fd > 0) return oz.raiseRuntimeError("`io_uring_queue_init(ring)` already initialized!");
        return e.trap_error(c.io_uring_queue_init(entries, io_uring, flags orelse 0));
    }
    return oz.raiseRuntimeError("`ring = Ring()` not initialized!");
}

///>>> io_uring_queue_mmap(fd, param, ring)
///
///Warning
///    - Coded but not tested!!!
pub fn io_uring_queue_mmap(fd: i32, ring: *Ring, param: *Param) ?i32 {
    return e.trap_error(c.io_uring_queue_mmap(fd, @ptrCast(ring._io_uring), @ptrCast(param._io_uring_params)));
}

///>>> io_uring_ring_dontfork(ring)
pub fn io_uring_ring_dontfork(ring: *Ring) ?i32 {
    // note: currently there is no `test` or `man` page for `io_uring_ring_dontfork` so guessing how it should work!
    return e.trap_error(c.io_uring_ring_dontfork(ring._io_uring));
}

///>>> io_uring_queue_exit(ring)
pub fn io_uring_queue_exit(ring: *Ring) ?void {
    if (ring._io_uring) |io_uring| {
        if (io_uring.ring_fd > 0) {
            c.io_uring_queue_exit(io_uring);
            io_uring.ring_fd = 0;
            return;
        }
    }
    return oz.raiseRuntimeError("`io_uring_queue_exit(ring)` not initialized or already exited!");
}

///Example
///    >>> cqe = Cqe(1024) # custom memory
///    ...
///    >>> io_uring_peek_batch_cqe(ring, cqe, 1024)
///    123
///
///Warning
///    - Don't use this function, till this warning is removed or else its most likely segfault!!!
pub fn io_uring_peek_batch_cqe(_: *Ring, _: *Cqe, _: u32) ?void {
    return oz.raiseNotImplementedError("`io_uring_peek_batch_cqe` is fully implemented yet!");
    // TODO:
    // fn peekBatchCqe(ring: *Ring, cqe: *Cqe, count: u32) ?void {
    // if (cqe._array) |_| return c.io_uring_peek_batch_cqe(ring._io_uring, &cqe._io_uring_cqe, count);
}

///Example
///    >>> io_uring_wait_cqes(ring, cqe, 123)
///    # or
///    >>> ts = timespec(1.5)  # timeout
///    >>>io_uring_wait_cqes(ring, cqe, 123, ts)
pub fn io_uring_wait_cqes(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) ?i32 {
    const _sigmask = null; // TODO
    const _ts = if (ts) |t| t._timespec else null;
    return e.trap_error(c.io_uring_wait_cqes(ring._io_uring, &cqe._io_uring_cqe, wait_nr, _ts, _sigmask));
}

///>>> io_uring_wait_cqes_min_timeout(ring)
pub fn io_uring_wait_cqes_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_ts_usec: u32) ?i32 {
    const _sigmask = null; // TODO
    return e.trap_error(c.io_uring_wait_cqes_min_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        ts._timespec,
        min_ts_usec,
        _sigmask,
    ));
}

///>>> ts = timespec(1.5)  # timeout
///>>> io_uring_wait_cqe_timeout(ring, cqe, ts)
pub fn io_uring_wait_cqe_timeout(ring: *Ring, cqe: *Cqe, ts: *Timespec) ?i32 {
    return e.trap_error(c.io_uring_wait_cqe_timeout(ring._io_uring, &cqe._io_uring_cqe, ts._timespec));
}

///>>> io_uring_submit(ring)
///123
pub fn io_uring_submit(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_submit(ring._io_uring));
}

///>>> io_uring_submit_and_wait(ring, 123)
pub fn io_uring_submit_and_wait(ring: *Ring, wait_nr: u32) ?i32 {
    return e.trap_error(c.io_uring_submit_and_wait(ring._io_uring, wait_nr));
}

///>>> io_uring_submit_and_wait_timeout(ring, cqe, 1)
///# or
///>>> ts = timespec(0.5)
///>>> io_uring_submit_and_wait_timeout(ring, cqe, 1, ts)
pub fn io_uring_submit_and_wait_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) ?i32 {
    const _sigmask = null; // TODO
    const _ts = if (ts) |t| t._timespec else null;
    return e.trap_error(c.io_uring_submit_and_wait_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        _ts,
        _sigmask,
    ));
}

pub fn io_uring_submit_and_wait_min_timeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_wait: u32) ?i32 {
    const _sigmask = null; // TODO

    return e.trap_error(c.io_uring_submit_and_wait_min_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        ts._timespec,
        min_wait,
        _sigmask,
    ));
}

pub fn io_uring_submit_and_wait_reg(ring: *Ring, cqe: *Cqe, wait_nr: u32, reg_index: i32) ?i32 {
    return e.trap_error(c.io_uring_submit_and_wait_reg(ring._io_uring, &cqe._io_uring_cqe, wait_nr, reg_index));
}

pub fn io_uring_register_wait_reg(ring: *Ring, reg: *RegWait, nr: i32) ?i32 {
    return e.trap_error(c.io_uring_register_wait_reg(ring._io_uring, reg._io_uring_reg_wait, nr));
}

pub fn io_uring_resize_rings(ring: *Ring, p: *Param) ?i32 {
    return e.trap_error(c.io_uring_resize_rings(ring._io_uring, p._io_uring_params));
}

pub fn io_uring_clone_buffers_offset(
    dst_ring: *Ring,
    src_ring: *Ring,
    dst_off: c_uint,
    src_off: c_uint,
    nr: c_uint,
    flags: ?c_uint,
) ?i32 {
    const _flags = flags orelse 0;
    return e.trap_error(c.io_uring_clone_buffers_offset(
        dst_ring._io_uring,
        src_ring._io_uring,
        dst_off,
        src_off,
        nr,
        _flags,
    ));
}

///Warning
///    - Coded but not tested!!!
pub fn io_uring_clone_buffers(dst_ring: *Ring, src_ring: *Ring, flags: ?u32) ?i32 {
    return e.trap_error(c.__io_uring_clone_buffers(dst_ring._io_uring, src_ring._io_uring, flags orelse 0));
}

///Note
///    - `io_uring_register_buffers` includes `io_uring_register_buffers_tags`
///
///Warning
///    - Coded but not tested!!!
pub fn io_uring_register_buffers(ring: *Ring, iovecs: *const Iovec, tags: ?u64) ?i32 {
    const _tags = tags orelse 0;
    return e.trap_error(c.io_uring_register_buffers_tags(ring._io_uring, iovecs._iovec, _tags, @intCast(iovecs._len)));
}

pub fn io_uring_register_buffers_sparse(ring: *Ring, nr: u32) ?i32 {
    return e.trap_error(c.io_uring_register_buffers_sparse(ring._io_uring, nr));
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub fn io_uring_register_buffers_update_tag(ring: *Ring, iovecs: *const Iovec, tags: *const u64, offset: ?u32) ?i32 {
    return e.trap_error(c.io_uring_register_buffers_update_tag(
        ring._io_uring,
        offset orelse 0,
        iovecs._iovec,
        tags,
        @intCast(iovecs._len),
    ));
}

pub fn io_uring_unregister_buffers(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_unregister_buffers(ring._io_uring));
}

///Register File Descriptor
///
///Example
///    >>> ids = FileIndex([1, 2, 3])
///    >>> io_uring_register_files(ring, ids)
///    ...
///    >>> io_uring_unregister_files(ring)
///
///Note
///    - Hold on to `ids` reference till the submit + wait process is done.
///    - "Registered files have less overhead per operation than normal files.
///    This is due to the kernel grabbing a reference count on a file when an
///    operation begins, and dropping it when it's done. When the process file
///    table is shared, for example if the process has ever created any
///    threads, then this cost goes up even more. Using registered files
///    reduces the overhead of file reference management across requests that
///    operate on a file."
///
///Warning
///    - Coded but not tested!!!
pub fn io_uring_register_files(ring: *Ring, files: FileIndex) ?i32 {
    return e.trap_error(
        c.io_uring_register_files(ring._io_uring, files._fds, @intCast(files._len)),
    );
}

pub fn io_uring_register_files_tags(ring: *Ring, files: FileIndex, tags: u64) ?i32 {
    return e.trap_error(
        c.io_uring_register_files_tags(ring._io_uring, files._fds, tags, @intCast(files._len)),
    );
}

pub fn io_uring_register_files_sparse(ring: *Ring, nr: u32) ?i32 {
    return e.trap_error(c.io_uring_register_files_sparse(ring._io_uring, nr));
}

///Note
///    - Function arguments position has changed for C origin for better usability.
pub fn io_uring_register_files_update_tag(ring: *Ring, files: FileIndex, tags: *const u64, offset: ?u32) ?i32 {
    const _offset = offset orelse 0;
    return e.trap_error(
        c.io_uring_register_files_update_tag(ring._io_uring, _offset, files._fds, tags, @intCast(files._len)),
    );
}

///>>> io_uring_unregister_files(ring)
pub fn io_uring_unregister_files(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_unregister_files(ring._io_uring));
}

///Note
///    - Function arguments position has changed for C origin for better usability.
pub fn io_uring_register_files_update(ring: *Ring, fds: FileIndex, offset: ?u32) ?i32 {
    const _offset = offset orelse 0;
    return e.trap_error(c.io_uring_register_files_update(ring._io_uring, _offset, fds._fds, @intCast(fds._len)));
}

///>>> io_uring_register_eventfd(fd)
pub fn io_uring_register_eventfd(ring: *Ring, fd: i32) ?i32 {
    return e.trap_error(c.io_uring_register_eventfd(ring._io_uring, fd));
}

pub fn io_uring_register_eventfd_async(ring: *Ring, fd: i32) ?i32 {
    return e.trap_error(c.io_uring_register_eventfd_async(ring._io_uring, fd));
}

///>>> io_uring_unregister_eventfd(ring)
pub fn io_uring_unregister_eventfd(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_unregister_eventfd(ring._io_uring));
}

pub fn io_uring_register_probe(_: *Ring, _: *Probe, _: u32) ?i32 {
    return oz.raiseNotImplementedError("`io_uring_register_probe` - caught the zig bug!");
    // return e.trap_error(c.io_uring_register_probe(ring._io_uring, probe._io_uring_probe, nr));
}

///>>> io_uring_register_personality(ring)
///123  # id
pub fn io_uring_register_personality(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_register_personality(ring._io_uring));
}

///>>> io_uring_unregister_personality(ring, id)
pub fn io_uring_unregister_personality(ring: *Ring, id: i32) ?i32 {
    return e.trap_error(c.io_uring_unregister_personality(ring._io_uring, id));
}

pub fn io_uring_register_restrictions(ring: *Ring, res: *Restriction) ?i32 {
    return e.trap_error(c.io_uring_register_restrictions(ring._io_uring, res._io_uring_restriction, @intCast(res._len)));
}

///>>> io_uring_enable_rings(ring)
pub fn io_uring_enable_rings(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_enable_rings(ring._io_uring));
}

///>>> io_uring_register_ring_fd(ring)
pub fn io_uring_register_ring_fd(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_register_ring_fd(ring._io_uring));
}

///>>> io_uring_unregister_ring_fd(ring)
pub fn io_uring_unregister_ring_fd(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_unregister_ring_fd(ring._io_uring));
}

///>>> io_uring_close_ring_fd(ring)
pub fn io_uring_close_ring_fd(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_close_ring_fd(ring._io_uring));
}

pub fn io_uring_register_buf_ring(ring: *Ring, reg: *BufReg, flags: ?u32) ?i32 {
    const _flags: u32 = if (flags) |f| f else 0;
    return e.trap_error(c.io_uring_register_buf_ring(ring._io_uring, reg._io_uring_buf_reg, _flags));
}

pub fn io_uring_unregister_buf_ring(ring: *Ring, bgid: i32) ?i32 {
    return e.trap_error(c.io_uring_unregister_buf_ring(ring._io_uring, bgid));
}

pub fn io_uring_buf_ring_head(ring: *Ring, buf_group: i32, head: *u16) ?i32 {
    return e.trap_error(c.io_uring_buf_ring_head(ring._io_uring, buf_group, head));
}

pub fn io_uring_register_sync_cancel(ring: *Ring, reg: *SyncCancelReg) ?i32 {
    return e.trap_error(c.io_uring_register_sync_cancel(ring._io_uring, reg._io_uring_sync_cancel_reg));
}

pub fn io_uring_register_sync_msg(sqe: *Sqe) ?i32 {
    return e.trap_error(c.io_uring_register_sync_msg(sqe._io_uring_sqe));
}

pub fn io_uring_register_file_alloc_range(ring: *Ring, off: u32, len: u32) ?i32 {
    return e.trap_error(c.io_uring_register_file_alloc_range(ring._io_uring, off, len));
}

pub fn io_uring_register_napi(ring: *Ring, napi: *Napi) ?i32 {
    return e.trap_error(c.io_uring_register_napi(ring._io_uring, napi._io_uring_napi));
}

pub fn io_uring_unregister_napi(ring: *Ring, napi: *Napi) ?i32 {
    return e.trap_error(c.io_uring_unregister_napi(ring._io_uring, napi._io_uring_napi));
}

pub fn io_uring_register_ifq(ring: *Ring, reg: *ZcrxIfqReg) ?i32 {
    return e.trap_error(c.io_uring_register_ifq(ring._io_uring, reg._io_uring_zcrx_ifq_reg));
}

pub fn io_uring_register_clock(ring: *Ring, arg: *ClockRegister) ?i32 {
    return e.trap_error(c.io_uring_register_clock(ring._io_uring, arg._io_uring_clock_register));
}

pub fn io_uring_register_bpf_filter(ring: *Ring, bpf: *Bpf) ?i32 {
    return e.trap_error(c.io_uring_register_bpf_filter(ring._io_uring, bpf._io_uring_bpf));
}

pub fn io_uring_register_bpf_filter_task(bpf: *Bpf) ?i32 {
    return e.trap_error(c.io_uring_register_bpf_filter_task(bpf._io_uring_bpf));
}

pub fn io_uring_get_events(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_get_events(ring._io_uring));
}

pub fn io_uring_submit_and_get_events(ring: *Ring) ?i32 {
    return e.trap_error(c.io_uring_submit_and_get_events(ring._io_uring));
}

pub fn io_uring_enter(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sig: *SigsetT) ?i32 {
    return e.trap_error(c.io_uring_enter(fd, to_submit, min_complete, flags, sig._sigset_t));
}

pub fn io_uring_enter2(fd: u32, to_submit: u32, min_complete: u32, flags: u32, arg: ?*anyopaque, sz: usize) ?i32 {
    return e.trap_error(c.io_uring_enter2(fd, to_submit, min_complete, flags, arg, sz));
}

pub fn io_uring_setup(entries: u32, p: *Param) ?i32 {
    return e.trap_error(c.io_uring_setup(entries, p._io_uring_params));
}

pub fn io_uring_register(fd: u32, opcode: u32, arg: ?*anyopaque, nr_args: u32) ?i32 {
    return e.trap_error(c.io_uring_register(fd, opcode, arg, nr_args));
}

pub fn io_uring_register_region(ring: *Ring, reg: MemRegionReg) ?i32 {
    return e.trap_error(c.io_uring_register_region(ring._io_uring, reg._io_uring_mem_region_reg));
}

pub fn io_uring_setup_buf_ring(ring: *Ring, nentries: u32, bgid: i32, flags: u32, err: *i32) ?BufRing {
    if (c.io_uring_setup_buf_ring(ring._io_uring, nentries, bgid, flags, err)) |br| {
        return .{ ._io_uring_buf_ring = br };
    }
    return oz.raiseRuntimeError("`io_uring_setup_buf_ring` - could not be initialized!");
}

pub fn io_uring_free_buf_ring(ring: *Ring, br: BufRing, nentries: u32, bgid: i32) ?i32 {
    return e.trap_error(c.io_uring_free_buf_ring(ring._io_uring, br._io_uring_buf_ring, nentries, bgid));
}

pub fn io_uring_set_iowait(ring: *Ring, enable_iowait: bool) ?i32 {
    return e.trap_error(c.io_uring_set_iowait(ring._io_uring, enable_iowait));
}

///Example
///    >>> cqe_iter = io_uring_cqe_iter_init(ring)
///    >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///
///Note
///    - `io_uring_cqe_iter_init` must be used with `io_uring_cqe_iter_next`
///    - Refer to `help(io_uring_cqe_iter_next)` for better example.
pub inline fn io_uring_cqe_iter_init(ring: *Ring) CqeIter {
    return .{ ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(ring._io_uring) };
}

///Example
///    # Must submit `sqe` before:
///    ... ...
///    >>> ready = 0
///    >>> cqe_iter = io_uring_cqe_iter_init(ring)
///    >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
///    >>>     ready += 1
///    >>>     entry = cqe[0]  # only index `0` data gets updated!!!
///    >>>     entry.user_data, entry.res  # do something with info
///    ...     ...
///    # either:
///    >>>     io_uring_cqe_seen(ring, entry)  # within `while` loop
///    # or
///    >>> io_uring_cq_advance(ring, ready)  # after `while` loop is finished (probably faster).
///
///Note
///    - Only `cqe[0]` gets updated with new completed entry value.
///    - Getting iter is low level and very touchy must be used as shown in example.
///    - Consider using `CqeIter` instead, in `for` loop.
pub inline fn io_uring_cqe_iter_next(iter: *CqeIter, cqe: *Cqe) bool {
    return c.io_uring_cqe_iter_next(&iter._io_uring_cqe_iter, &cqe._io_uring_cqe);
}

pub inline fn io_uring_cq_advance(ring: *Ring, nr: u32) void {
    c.io_uring_cq_advance(ring._io_uring, nr);
}

pub inline fn io_uring_cqe_seen(ring: *Ring, cqe: *CQE) void {
    c.io_uring_cqe_seen(ring._io_uring, cqe._cqe);
}

///>>> io_uring_sqe_set_data(sqe, python_object)
///
///Warning
///    - Not tested!!!
pub inline fn io_uring_sqe_set_data(sqe: *SQE, data: *oz.py.PyObject) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(data)) |ptr| {
        oz.py.Py_IncRef(data);
        c.io_uring_sqe_set_data(sqe._sqe, ptr);
    } else return null;
}

///>>> python_object = io_uring_cqe_get_data(cqe[0])
///
///Warning
///    - Not tested!!!
pub inline fn io_uring_cqe_get_data(cqe: *CQE) ?*oz.py.PyObject {
    const ptr: ?*anyopaque = c.io_uring_cqe_get_data(cqe._cqe); // NOTE: This can return garbage data!
    if (ptr == null) return oz.raiseValueError("`io_uring_cqe_get_data()` - received `null`");
    const data: ?*oz.py.PyObject = oz.py.c.PyLong_FromVoidPtr(ptr);
    if (data == null) return null;
    defer oz.py.Py_DecRef(data);
    return data;
}

///>>> io_uring_sqe_set_data64(sqe, 123)
pub inline fn io_uring_sqe_set_data64(sqe: *SQE, data: u64) ?void {
    c.io_uring_sqe_set_data64(sqe._sqe, data);
}

///>>> io_uring_cqe_get_data64(cqe)
///123
pub inline fn io_uring_cqe_get_data64(cqe: *CQE) ?u64 {
    return c.io_uring_cqe_get_data64(cqe._cqe);
}

///>>> io_uring_sqe_set_flags(sqe, IOSQE_IO_HARDLINK)
pub inline fn io_uring_sqe_set_flags(sqe: *SQE, flags: u32) void {
    c.io_uring_sqe_set_flags(sqe._sqe, flags);
}

///>>> io_uring_sqe_set_buf_group(sqe, 123)
pub inline fn io_uring_sqe_set_buf_group(sqe: *SQE, bgid: i32) void {
    c.io_uring_sqe_set_buf_group(sqe._sqe, bgid);
}

pub inline fn io_uring_prep_splice(
    sqe: *SQE,
    fd_in: i32,
    off_in: i64,
    fd_out: i32,
    off_out: i64,
    nbytes: u32,
    splice_flags: u32,
) ?void {
    c.io_uring_prep_splice(sqe._sqe, fd_in, off_in, fd_out, off_out, nbytes, splice_flags);
}

pub inline fn io_uring_prep_tee(sqe: *SQE, fd_in: i32, fd_out: i32, nbytes: u32, splice_flags: u32) void {
    c.io_uring_prep_tee(sqe._sqe, fd_in, fd_out, nbytes, splice_flags);
}

///Example
///    >>> buffer = [bytearray(6), bytearray(4)]
///    >>> iovec = Iovec(buffer)
///    >>> io_uring_prep_readv(sqe, fd, iovec)
///    ...
///    >>> buffer
///    [bytearray(b"hi... "), bytearray(b"bye!")]
///
///Note
///    - `io_uring_prep_readv` includes `io_uring_prep_readv2` feature as well.
pub inline fn io_uring_prep_readv(sqe: *SQE, fd: i32, iovec: Iovec, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_readv2(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags);
}

///Example
///    >>> # `buf_index` = registered IO buffer
///    >>> buffer = bytearray(5)
///    >>> io_uring_prep_read_fixed(sqe, fd, buffer, buf_index)
///    ...
///    >>> buffer
///    bytearray(b"hi...")
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_read_fixed(sqe: *SQE, fd: i32, buff: oz.ByteArray, buf_index: i32, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    c.io_uring_prep_read_fixed(sqe._sqe, fd, @ptrCast(buff.data), @intCast(buff.data.len), _offset, buf_index);
}

///Example
///    >>> # `buf_index` = registered IO buffer
///    >>> buffer = [bytearray(5), bytearray(4)]
///    >>> iovec = Iovec(buffer)
///    >>> io_uring_prep_readv_fixed(sqe, fd, iovec, buf_index)
///    ...
///    >>> buffer
///    [bytearray(b"hi..."), bytearray(b"bye!")]
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_readv_fixed(
    sqe: *SQE,
    fd: i32,
    iovec: Iovec,
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_readv_fixed(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags, buf_index);
}

///Example
///    >>> buffer = [b'hi... '), b'bye!']
///    >>> iovec = Iovec(buffer)
///    >>> io_uring_prep_writev(sqe, fd, iovec)
///    ... ...
///    >>> cqe[0].res
///    10
///
///Note
///    - `io_uring_prep_writev` includes `io_uring_prep_writev2` feature as well.
pub inline fn io_uring_prep_writev(sqe: *SQE, fd: i32, iovec: Iovec, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_writev2(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags);
}

///Example
///    >>> # `buf_index` = registered IO buffer
///    >>> io_uring_prep_write_fixed(sqe, fd, b'hi...', buf_index)
///    ... ...
///    >>> cqe[0].res
///    5
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_write_fixed(sqe: *SQE, fd: i32, buff: oz.Bytes, buf_index: i32, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    c.io_uring_prep_write_fixed(sqe._sqe, fd, @ptrCast(buff.data), @intCast(buff.data.len), _offset, buf_index);
}

///Example
///    >>> # `buf_index` = registered IO buffer
///    >>> buffer = [b"hi... ", b"bye!"]
///    >>> iovec = Iovec(buffer)
///    >>> io_uring_prep_writev_fixed(sqe, fd, iovec, buf_index)
///    ...
///    >>> cqe[0].res
///    10
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_writev_fixed(
    sqe: *SQE,
    fd: i32,
    iovec: Iovec,
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_writev_fixed(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags, buf_index);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_recvmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg(sqe._sqe, fd, msg._msghdr, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_recvmsg_multishot(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg_multishot(sqe._sqe, fd, msg._msghdr, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_sendmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_sendmsg(sqe._sqe, fd, msg._msghdr, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_poll_add(sqe: *SQE, fd: i32, poll_mask: u32) void {
    c.io_uring_prep_poll_add(sqe._sqe, fd, poll_mask);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_poll_multishot(sqe: *SQE, fd: i32, poll_mask: u32) void {
    c.io_uring_prep_poll_multishot(sqe._sqe, fd, poll_mask);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_poll_remove(sqe: *SQE, user_data: u64) ?void {
    c.io_uring_prep_poll_remove(sqe._sqe, user_data);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_poll_update(
    sqe: *SQE,
    old_user_data: u64,
    new_user_data: u64,
    poll_mask: u32,
    flags: ?u32,
) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_poll_update(sqe._sqe, old_user_data, new_user_data, poll_mask, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fsync(sqe: *SQE, fd: i32, fsync_flags: ?u32) void {
    const _flags = fsync_flags orelse 0;
    c.io_uring_prep_fsync(sqe._sqe, fd, _flags);
}

///>>> io_uring_prep_nop(sqe)
pub inline fn io_uring_prep_nop(sqe: *SQE) void {
    c.io_uring_prep_nop(sqe._sqe);
}

///>>> io_uring_prep_nop128(sqe)
pub inline fn io_uring_prep_nop128(sqe: *SQE) void {
    c.io_uring_prep_nop128(sqe._sqe);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_timeout(sqe: *SQE, ts: *Timespec, count: u32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout(sqe._sqe, ts._timespec, count, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_timeout_remove(sqe: *SQE, user_data: u64, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_remove(sqe._sqe, user_data, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_timeout_update(sqe: *SQE, ts: *Timespec, user_data: u64, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_update(sqe._sqe, ts._timespec, user_data, _flags);
}

///Example
///    >>> addr = Sockaddr(AF_INET, "127.0.0.1", 12345)
///    ... ...
///    >>> io_uring_prep_accept(sqe, fd, addr)
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;

    if (addr) |a| return c.io_uring_prep_accept(sqe._sqe, fd, @ptrFromInt(a._sockaddr), a._socklen, _flags);
    c.io_uring_prep_accept(sqe._sqe, fd, null, null, _flags);
}

///Note
///    - Function argument `file_index` position has changed for C origin for better usability.
///    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///    Allocated descriptor is returned in the `cqe.res`.
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, file_index: ?u32, flags: ?i32) void {
    const _flags = flags orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    if (addr) |a| return c.io_uring_prep_accept_direct(
        sqe._sqe,
        fd,
        @ptrFromInt(a._sockaddr),
        a._socklen,
        _flags,
        _file_index,
    );
    c.io_uring_prep_accept_direct(sqe._sqe, fd, null, null, _flags, _file_index);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_multishot_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;
    if (addr) |a| return c.io_uring_prep_multishot_accept(sqe._sqe, fd, @ptrFromInt(a._sockaddr), a._socklen, _flags);
    c.io_uring_prep_multishot_accept(sqe._sqe, fd, null, null, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_multishot_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;
    if (addr) |a| {
        return c.io_uring_prep_multishot_accept_direct(
            sqe._sqe,
            fd,
            @ptrFromInt(a._sockaddr),
            a._socklen,
            _flags,
        );
    }
    c.io_uring_prep_multishot_accept_direct(sqe._sqe, fd, null, null, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_cancel64(sqe: *SQE, user_data: u64, flags: ?i32) void {
    c.io_uring_prep_cancel64(sqe._sqe, user_data, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_cancel(sqe: *SQE, user_data: *oz.py.PyObject, flags: ?i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(user_data)) |ptr| {
        c.io_uring_prep_cancel(sqe._sqe, ptr, flags orelse 0);
    } else return null;
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_cancel_fd(sqe: *SQE, fd: i32, flags: ?u32) void {
    c.io_uring_prep_cancel_fd(sqe._sqe, fd, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_link_timeout(sqe: *SQE, ts: Timespec, flags: u32) void {
    c.io_uring_prep_link_timeout(sqe._sqe, ts._timespec, flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_connect(sqe: *SQE, fd: i32, addr: *Sockaddr) void {
    c.io_uring_prep_connect(sqe._sqe, fd, @ptrFromInt(addr._sockaddr), addr._socklen);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_bind(sqe: *SQE, fd: i32, addr: *Sockaddr) void {
    c.io_uring_prep_bind(sqe._sqe, fd, @ptrFromInt(addr._sockaddr), addr._socklen);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_listen(sqe: *SQE, fd: i32, backlog: i32) void {
    c.io_uring_prep_listen(sqe._sqe, fd, backlog);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_epoll_wait(sqe: *SQE, fd: i32, events: *EpollEvent, maxevents: i32, flags: ?u32) void {
    c.io_uring_prep_epoll_wait(sqe._sqe, fd, events._epoll_event, maxevents, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_files_update(sqe: *SQE, fds: oz.ListView(i32), offset: ?i32) void {
    c.io_uring_prep_files_update(sqe._sqe, @ptrCast(fds.py_list), @intCast(fds.len()), offset orelse 0);
}

///Mode
///    FALLOC_FL_KEEP_SIZE       # default is extend size
///    FALLOC_FL_PUNCH_HOLE      # de-allocates range
///    FALLOC_FL_NO_HIDE_STALE   # reserved codepoint
///    FALLOC_FL_COLLAPSE_RANGE
///    FALLOC_FL_ZERO_RANGE
///    FALLOC_FL_INSERT_RANGE
///    FALLOC_FL_UNSHARE_RANGE
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fallocate(sqe: *SQE, fd: i32, mode: i32, offset: u64, len: u64) void {
    c.io_uring_prep_fallocate(sqe._sqe, fd, mode, offset, len);
}

///Open File
///
///Example
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> io_uring_prep_open(sqe, b'./file.ext')
///    >>> sqe.user_data = 123
///
///Note
///    - Function argument `dfd` has been moved to end from how it is in C function.
///    - `io_uring_prep_open` includes `io_uring_prep_openat` as well.
pub inline fn io_uring_prep_open(sqe: *SQE, path: oz.Path, flags: ?i32, mode: ?c.mode_t, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse 0;
    c.io_uring_prep_openat(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mode);
}

///Open Direct
///
///Example
///    >>> indexed = FileIndex([-1, -1, -1, -1])
///    >>> index = 3  # position of last ---^ `fds` registered
///    >>> io_uring_register_files(ring, fds)
///    >>> flags = liburing.O_TMPFILE | liburing.O_WRONLY
///    >>> sqe = liburing.io_uring_get_sqe(ring)
///    >>> io_uring_prep_open_direct(sqe, ".", flags, index)
///    ... ...
///    >>>.io_uring_prep_close_direct(sqe, index)
///    ... ...
///    >>> io_uring_unregister_files(ring)
///
///Note
///    - Open direct does not use `fd` but `index`
///    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///    Allocated descriptor is returned in the `cqe.res`.
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_open_direct` includes `io_uring_prep_openat_direct` as well.
pub inline fn io_uring_prep_open_direct(
    sqe: *SQE,
    path: oz.Path,
    flags: ?i32,
    file_index: ?u32,
    mode: ?c.mode_t,
    dfd: ?i32,
) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse c.O_RDONLY;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat_direct(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mode, _file_index);
}

///>>> io_uring_prep_close(sqe, fd)
pub inline fn io_uring_prep_close(sqe: *SQE, fd: i32) void {
    c.io_uring_prep_close(sqe._sqe, fd);
}

///>>> io_uring_prep_close_direct(sqe, file_index)
pub inline fn io_uring_prep_close_direct(sqe: *SQE, file_index: u32) void {
    c.io_uring_prep_close_direct(sqe._sqe, file_index);
}

///Example
///    >>> buf = bytearray(5)
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> io_uring_prep_read(sqe, fd, buf)
///    ... ...
///    >>> cqe[0].res
///    5
///    ... ...
///    >>> buf
///    bytearray(b'hi...')
pub inline fn io_uring_prep_read(sqe: *SQE, fd: i32, buf: oz.ByteArray, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    c.io_uring_prep_read(sqe._sqe, fd, @ptrCast(buf.data), @intCast(buf.data.len), _offset);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_read_multishot(sqe: *SQE, fd: i32, buf_group: i32, nbytes: ?u32, offset: ?u64) void {
    const _nbytes = nbytes orelse 0;
    const _offset = offset orelse 0;
    c.io_uring_prep_read_multishot(sqe._sqe, fd, _nbytes, _offset, buf_group);
}

///Example
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> io_uring_prep_write(sqe, fd, b"hi...")
///    ... ...
///    >>> cqe.res
///    5
pub inline fn io_uring_prep_write(sqe: *SQE, fd: i32, buf: oz.Bytes, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    c.io_uring_prep_write(sqe._sqe, fd, @ptrCast(buf.data), @intCast(buf.data.len), _offset);
}

///Statx
///
///Type
///    sqe:    SQE
///    stat:   Statx
///    path:   str
///    flags:  int
///    mask:   int
///    dfd:    int
///    return: None
///
///Example
///    >>> stat = Statx()
///    >>> if sqe := io_uring_get_sqe(ring)
///    ...     io_uring_prep_statx(sqe, stat, __file__)
///    ... ...
///    >>> stat.isfile
///    True
///    >>> stat.size
///    123
///
///Flag
///    AT_EMPTY_PATH
///    AT_NO_AUTOMOUNT
///    AT_SYMLINK_NOFOLLOW     # Do not follow symbolic links.
///    AT_STATX_SYNC_AS_STAT
///    AT_STATX_FORCE_SYNC
///    AT_STATX_DONT_SYNC
///
///Mask
///    STATX_TYPE          # Want|got `stx_mode & S_IFMT`
///    STATX_MODE          # Want|got `stx_mode & ~S_IFMT`
///    STATX_NLINK         # Want|got `stx_nlink`
///    STATX_UID           # Want|got `stx_uid`
///    STATX_GID           # Want|got `stx_gid`
///    STATX_ATIME         # Want|got `stx_atime`
///    STATX_MTIME         # Want|got `stx_mtime`
///    STATX_CTIME         # Want|got `stx_ctime`
///    STATX_INO           # Want|got `stx_ino`
///    STATX_SIZE          # Want|got `stx_size`
///    STATX_BLOCKS        # Want|got `stx_blocks`
///    STATX_BASIC_STATS   # [All of the above]
///    STATX_BTIME         # Want|got `stx_btime`
///    STATX_MNT_ID        # Got `stx_mnt_id`
///    # note: not supported
///    # STATX_DIOALIGN      # Want/got direct I/O alignment info
///
///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `STATX_ALL` is depreciated, use `STATX_BASIC_STATS | STATX_BTIME` which is set by default.
pub inline fn io_uring_prep_statx(sqe: *SQE, statxbuf: *Statx, path: oz.Path, flags: ?i32, mask: ?u32, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mask = mask orelse c.STATX_BASIC_STATS | c.STATX_BTIME; // replaces `STATX_ALL` as its depreciated!
    const _flags = flags orelse 0;
    c.io_uring_prep_statx(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mask, statxbuf._statx);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fadvise(sqe: *SQE, fd: i32, len: u32, advice: i32, offset: ?u64) void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise(sqe._sqe, fd, _offset, len, advice);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_madvise(sqe: *SQE, addr: *oz.py.PyObject, length: u32, advice: i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(addr)) |ptr| {
        c.io_uring_prep_madvise(sqe._sqe, ptr, length, advice);
    } else return null;
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fadvise64(sqe: *SQE, fd: i32, len: c.off_t, advice: i32, offset: ?u64) void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise64(sqe._sqe, fd, _offset, len, advice);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_madvise64(sqe: *SQE, addr: *oz.py.PyObject, length: c.off_t, advice: i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(addr)) |ptr| {
        c.io_uring_prep_madvise64(sqe._sqe, ptr, length, advice);
    } else return null;
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_send(sqe: *SQE, sockfd: i32, buf: oz.Bytes, flags: ?i32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_send(sqe._sqe, sockfd, @ptrCast(buf.data), buf.data.len, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_send_bundle(sqe: *SQE, sockfd: i32, len: ?usize, flags: ?i32) void {
    c.io_uring_prep_send_bundle(sqe._sqe, sockfd, len orelse 0, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_send_set_addr(sqe: *SQE, dest_addr: *Sockaddr) void {
    c.io_uring_prep_send_set_addr(sqe._sqe, @ptrFromInt(dest_addr._sockaddr), @intCast(dest_addr._socklen));
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_sendto(sqe: *SQE, sockfd: i32, buf: oz.Bytes, addr: *Sockaddr, flags: ?i32) void {
    c.io_uring_prep_sendto(
        sqe._sqe,
        sockfd,
        @ptrCast(buf.data),
        buf.data.len,
        flags orelse 0,
        @ptrFromInt(addr._sockaddr),
        addr._socklen,
    );
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_send_zc(sqe: *SQE, sockfd: i32, buf: oz.Bytes, flags: ?i32, zc_flags: ?u32) void {
    c.io_uring_prep_send_zc(sqe._sqe, sockfd, @ptrCast(buf.data), buf.data.len, flags orelse 0, zc_flags orelse 0);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_send_zc_fixed(
    sqe: *SQE,
    sockfd: i32,
    buf: oz.Bytes,
    buf_index: ?u32,
    flags: ?i32,
    zc_flags: ?u32,
) void {
    c.io_uring_prep_send_zc_fixed(
        sqe._sqe,
        sockfd,
        @ptrCast(buf.data),
        buf.data.len,
        flags orelse 0,
        zc_flags orelse 0,
        buf_index orelse 0,
    );
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_sendmsg_zc(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    c.io_uring_prep_sendmsg_zc(sqe._sqe, fd, msg._msghdr, flags orelse 0);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_sendmsg_zc_fixed(sqe: *SQE, fd: i32, msg: *Msghdr, buf_index: u32, flags: ?u32) void {
    c.io_uring_prep_sendmsg_zc_fixed(sqe._sqe, fd, msg._msghdr, flags orelse 0, buf_index);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_recv(sqe: *SQE, sockfd: i32, buf: ?oz.ByteArray, flags: ?i32) void {
    if (buf) |b| {
        c.io_uring_prep_recv(sqe._sqe, sockfd, @ptrCast(b.data), b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv(sqe._sqe, sockfd, null, 0, flags orelse 0);
    }
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_recv_multishot(sqe: *SQE, sockfd: i32, buf: ?oz.ByteArray, flags: ?i32) void {
    if (buf) |b| {
        c.io_uring_prep_recv_multishot(sqe._sqe, sockfd, @ptrCast(b.data), b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv_multishot(sqe._sqe, sockfd, null, 0, flags orelse 0);
    }
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_validate(buf: oz.ByteArray, msgh: *Msghdr) RecvmsgOut {
    return .{ ._recvmsg_out = c.io_uring_recvmsg_validate(@ptrCast(buf.data), @intCast(buf.data.len), msgh._msghdr) };
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_name(o: *RecvmsgOut) ?*anyopaque {
    return c.io_uring_recvmsg_name(o._recvmsg_out);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_cmsg_firsthdr(o: *RecvmsgOut, msgh: *Msghdr) Cmsghdr {
    return .{ ._cmsghdr = c.io_uring_recvmsg_cmsg_firsthdr(o._recvmsg_out, msgh._msghdr) };
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_cmsg_nexthdr(o: *RecvmsgOut, msgh: *Msghdr, cmsg: *Cmsghdr) Cmsghdr {
    return .{ ._cmsghdr = c.io_uring_recvmsg_cmsg_nexthdr(o._recvmsg_out, msgh._msghdr, cmsg._cmsghdr) };
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_payload(o: *RecvmsgOut, msgh: *Msghdr) ?*anyopaque {
    return c.io_uring_recvmsg_payload(o._recvmsg_out, msgh._msghdr);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_recvmsg_payload_length(o: *RecvmsgOut, buf_len: i32, msgh: *Msghdr) u32 {
    return c.io_uring_recvmsg_payload_length(o._recvmsg_out, buf_len, msgh._msghdr);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
pub inline fn io_uring_prep_openat2(sqe: *SQE, path: oz.Path, how: *OpenHow, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_openat2(sqe._sqe, _dfd, @ptrCast(path.path), how._open_how);
}

///Note
///    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///    Allocated descriptor is returned in the `cqe.res`.
pub inline fn io_uring_prep_openat2_direct(sqe: *SQE, path: oz.Path, how: *OpenHow, file_index: ?u32, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat2_direct(sqe._sqe, _dfd, @ptrCast(path.path), how._open_how, _file_index);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_epoll_ctl(sqe: *SQE, epfd: i32, fd: i32, op: i32, ev: *EpollEvent) void {
    c.io_uring_prep_epoll_ctl(sqe._sqe, epfd, fd, op, ev._epoll_event);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_provide_buffers(sqe: *SQE, addr: oz.ByteArray, nr: i32, bgid: i32, bid: i32) void {
    c.io_uring_prep_provide_buffers(sqe._sqe, @ptrCast(addr.data), @intCast(addr.data.len), nr, bgid, bid);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_remove_buffers(sqe: *SQE, nr: i32, bgid: i32) void {
    c.io_uring_prep_remove_buffers(sqe._sqe, nr, bgid);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_shutdown(sqe: *SQE, fd: i32, how: i32) void {
    c.io_uring_prep_shutdown(sqe._sqe, fd, how);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_unlink` includes `io_uring_prep_unlinkat` feature.
///
pub inline fn io_uring_prep_unlink(sqe: *SQE, path: oz.Path, flags: ?i32, dfd: ?i32) void {
    c.io_uring_prep_unlinkat(sqe._sqe, dfd orelse AT_FDCWD, @ptrCast(path.path), flags orelse 0);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_rename` includes `io_uring_prep_renameat` feature.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_rename(
    sqe: *SQE,
    oldpath: oz.Path,
    newpath: oz.Path,
    flags: ?u32,
    olddfd: ?i32,
    newdfd: ?i32,
) void {
    const _flags = flags orelse 0;
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    c.io_uring_prep_renameat(sqe._sqe, _olddfd, @ptrCast(oldpath.path), _newdfd, @ptrCast(newpath.path), _flags);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_sync_file_range(sqe: *SQE, fd: i32, len: u32, offset: ?u64, flags: ?i32) void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_sync_file_range(sqe._sqe, fd, len, _offset, _flags);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_mkdir` includes `io_uring_prep_mkdirat` feature.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_mkdir(sqe: *SQE, path: oz.Path, mode: c.mode_t, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_mkdirat(sqe._sqe, _dfd, @ptrCast(path.path), mode);
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_symlink` includes `io_uring_prep_symlinkat` feature.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_symlink(sqe: *SQE, target: oz.Path, linkpath: oz.Path, newdirfd: ?i32) void {
    const _newdirfd = newdirfd orelse AT_FDCWD;
    c.io_uring_prep_symlinkat(sqe._sqe, @ptrCast(target.path), _newdirfd, @ptrCast(linkpath.path));
}

///Note
///    - Function arguments position has changed for C origin for better usability.
///    - `io_uring_prep_link` includes `io_uring_prep_linkat` feature.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_link(
    sqe: *SQE,
    oldpath: oz.Path,
    newpath: oz.Path,
    flags: ?i32,
    olddfd: ?i32,
    newdfd: ?i32,
) void {
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    const _flags = flags orelse 0;
    c.io_uring_prep_linkat(sqe._sqe, _olddfd, @ptrCast(oldpath.path), _newdfd, @ptrCast(newpath.path), _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_msg_ring_cqe_flags(
    sqe: *SQE,
    fd: i32,
    len: u32,
    data: u64,
    flags: u32,
    cqe_flags: u32,
) void {
    c.io_uring_prep_msg_ring_cqe_flags(sqe._sqe, fd, len, data, flags, cqe_flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_msg_ring(sqe: *SQE, fd: i32, len: u32, data: u64, flags: ?u32) void {
    c.io_uring_prep_msg_ring(sqe._sqe, fd, len, data, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_msg_ring_fd(
    sqe: *SQE,
    fd: i32,
    source_fd: i32,
    target_fd: i32,
    data: u64,
    flags: ?u32,
) void {
    c.io_uring_prep_msg_ring_fd(sqe._sqe, fd, source_fd, target_fd, data, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_msg_ring_fd_alloc(sqe: *SQE, fd: i32, source_fd: i32, data: u64, flags: ?u32) void {
    c.io_uring_prep_msg_ring_fd_alloc(sqe._sqe, fd, source_fd, data, flags orelse 0);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_getxattr(sqe: *SQE, name: [*]const u8, value: [*]u8, path: oz.Path, len: u32) void {
    c.io_uring_prep_getxattr(sqe._sqe, name, value, @ptrCast(path.path), len);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_setxattr(
    sqe: *SQE,
    name: [*]const u8,
    value: [*]u8,
    path: oz.Path,
    flags: i32,
    len: u32,
) void {
    c.io_uring_prep_setxattr(
        sqe._sqe,
        name,
        value,
        @ptrCast(path.path),
        flags,
        len,
    );
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fgetxattr(sqe: *SQE, fd: i32, name: [*]const u8, value: [*]u8, len: u32) void {
    c.io_uring_prep_fgetxattr(sqe._sqe, fd, name, value, len);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fsetxattr(sqe: *SQE, fd: i32, name: [*]const u8, value: [*]u8, flags: i32, len: u32) void {
    c.io_uring_prep_fsetxattr(sqe._sqe, fd, name, value, flags, len);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_socket(sqe: *SQE, domain: i32, @"type": i32, protocol: ?i32, flags: ?u32) void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    c.io_uring_prep_socket(sqe._sqe, domain, @"type", _protocol, _flags);
}

///Note
///    - `io_uring_prep_socket_direct` includes `io_uring_prep_socket_direct_alloc` feature.
///
///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_socket_direct(
    sqe: *SQE,
    domain: i32,
    Type: i32,
    protocol: ?i32,
    file_index: ?u32,
    flags: ?u32,
) void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_socket_direct(sqe._sqe, domain, Type, _protocol, _file_index, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_uring_cmd(sqe: *SQE, cmd_op: i32, fd: i32) void {
    c.io_uring_prep_uring_cmd(sqe._sqe, cmd_op, fd);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_uring_cmd128(sqe: *SQE, cmd_op: i32, fd: i32) void {
    c.io_uring_prep_uring_cmd128(sqe._sqe, cmd_op, fd);
}

///Example
///    >>> buf = bytearray((1).to_bytes(4, "little"))
///    >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_KEEPALIVE, buf)
///    # or
///    >>> buf = bytearray(b'eth1')
///    >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, ..., buf)
///
///Opcode
///    io_uring_socket_op
///        SOCKET_URING_OP_SIOCINQ
///        SOCKET_URING_OP_SIOCOUTQ
///        SOCKET_URING_OP_GETSOCKOPT
///        SOCKET_URING_OP_SETSOCKOPT
///        SOCKET_URING_OP_TX_TIMESTAMP
///        SOCKET_URING_OP_GETSOCKNAME
///
///Note
///    - remember to hold on to `buf` as new result will be populated into it.
///    - `cqe.res` will return `len()` of populating data(`buf`).
///    - min length of `buf` must be `4`.
///    - watch out for "big" or "little" endian, keep it same or it will switch to systems default.
pub inline fn io_uring_prep_cmd_sock(
    sqe: *SQE,
    cmd_op: i32,
    fd: i32,
    level: i32,
    optname: i32,
    optval: oz.ByteArray,
) void {
    c.io_uring_prep_cmd_sock(sqe._sqe, cmd_op, fd, level, optname, optval.data.ptr, @intCast(optval.data.len));
}

///Example
///    >>> sockaddr = Sockaddr()
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> io_uring_prep_cmd_getsockname(sqe, sockfd, sockaddr)
pub inline fn io_uring_prep_cmd_getsockname(sqe: *SQE, fd: i32, sockaddr: *Sockaddr, peer: ?i32) ?void {
    c.io_uring_prep_cmd_getsockname(
        sqe._sqe,
        fd,
        @ptrFromInt(sockaddr._sockaddr),
        &sockaddr._socklen,
        peer orelse 0,
    );
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_waitid(
    sqe: *SQE,
    idtype: c.idtype_t,
    id: c.id_t,
    infop: *SigsetT,
    options: i32,
    flags: ?u32,
) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_waitid(sqe._sqe, idtype, id, @ptrCast(infop._sigset_t), options, _flags);
}

// TODO:
// ///Warning
// ///    - Coded but not tested!!!
// pub inline fn io_uring_prep_futex_wake(
//     sqe: *SQE,
//     futex: *const u32,
//     val: u64,
//     mask: u64,
//     futex_flags: ?u32,
//     flags: ?u32,
// ) void {
//     const _flags = flags orelse 0;
//     const _futex_flas = futex_flags orelse 0;
//     c.io_uring_prep_futex_wake(sqe._sqe, futex._futex, val, mask, _futex_flas, _flags);
// }

// TODO:
// ///Warning
// ///    - Coded but not tested!!!
// pub inline fn io_uring_prep_futex_wait(sqe: *SQE) void {
//     c.io_uring_prep_futex_wait(sqe._sqe);
// }

// TODO:
// ///Warning
// ///    - Coded but not tested!!!
// pub inline fn io_uring_prep_futex_waitv(sqe: *SQE) void {
//     c.io_uring_prep_futex_waitv(sqe._sqe);
// }

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_fixed_fd_install(sqe: *SQE, fd: i32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_fixed_fd_install(sqe._sqe, fd, _flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_ftruncate(sqe: *SQE, fd: i32, len: ?c.loff_t) void {
    const _len = len orelse 0;
    c.io_uring_prep_ftruncate(sqe._sqe, fd, _len);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_cmd_discard(sqe: *SQE, fd: i32, offset: u64, nbytes: u64) void {
    c.io_uring_prep_cmd_discard(sqe._sqe, fd, offset, nbytes);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_pipe(sqe: *SQE, fds: i32, pipe_flags: i32) void {
    c.io_uring_prep_pipe(sqe._sqe, fds, pipe_flags);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_prep_pipe_direct(sqe: *SQE, fds: i32, pipe_flags: i32, file_index: u32) void {
    c.io_uring_prep_pipe_direct(sqe._sqe, fds, pipe_flags, file_index);
}

///Warning
///    - Coded but not tested!!!
pub inline fn io_uring_load_sq_head(ring: *Ring) u32 {
    return c.io_uring_load_sq_head(ring._io_uring);
}

pub inline fn io_uring_sq_ready(ring: *Ring) u32 {
    return c.io_uring_sq_ready(ring._io_uring);
}

pub inline fn io_uring_sq_space_left(ring: *Ring) u32 {
    return c.io_uring_sq_space_left(ring._io_uring);
}

pub inline fn io_uring_sqe_shift_from_flags(flags: u32) u32 {
    return c.io_uring_sqe_shift_from_flags(flags);
}

pub inline fn io_uring_sqe_shift(ring: *Ring) u32 {
    return c.io_uring_sqe_shift(ring._io_uring);
}

pub inline fn io_uring_sqring_wait(ring: *Ring) i32 {
    return c.io_uring_sqring_wait(ring._io_uring);
}

pub inline fn io_uring_cq_ready(ring: *Ring) u32 {
    return c.io_uring_cq_ready(ring._io_uring);
}

pub inline fn io_uring_cq_has_overflow(ring: *Ring) bool {
    return c.io_uring_cq_has_overflow(ring._io_uring);
}

pub inline fn io_uring_cq_eventfd_enabled(ring: *Ring) bool {
    return c.io_uring_cq_eventfd_enabled(ring._io_uring);
}

pub inline fn io_uring_cq_eventfd_toggle(ring: *Ring, enabled: bool) ?i32 {
    return e.trap_error(c.io_uring_cq_eventfd_toggle(ring._io_uring, enabled));
}

pub inline fn io_uring_wait_cqe_nr(ring: *Ring, cqe: *Cqe, wait_nr: u32) ?i32 {
    return e.trap_error(c.io_uring_wait_cqe_nr(ring._io_uring, &cqe._io_uring_cqe, wait_nr));
}

///>>> io_uring_peek_cqe(ring, cqe)
pub inline fn io_uring_peek_cqe(ring: *Ring, cqe_ptr: *Cqe) ?i32 {
    return e.trap_error(c.io_uring_peek_cqe(ring._io_uring, &cqe_ptr._io_uring_cqe));
}

pub inline fn io_uring_wait_cqe(ring: *Ring, cqe: *Cqe) ?i32 {
    return e.trap_error(c.io_uring_wait_cqe(ring._io_uring, &cqe._io_uring_cqe));
}

pub inline fn io_uring_buf_ring_mask(ring_entries: u32) i32 {
    return c.io_uring_buf_ring_mask(ring_entries);
}

pub inline fn io_uring_buf_ring_init(br: *BufRing) void {
    c.io_uring_buf_ring_init(br._io_uring_buf_ring);
}

pub inline fn io_uring_buf_ring_add(br: *BufRing, addr: oz.Bytes, bid: u16, mask: i32, buf_offset: ?i32) void {
    const _buf_offset = buf_offset orelse 0;
    c.io_uring_buf_ring_add(
        br._io_uring_buf_ring,
        @ptrCast(@constCast(addr.data)),
        @intCast(addr.data.len),
        bid,
        mask,
        _buf_offset,
    );
}

pub inline fn io_uring_buf_ring_advance(br: *BufRing, count: i32) void {
    c.io_uring_buf_ring_advance(br._io_uring_buf_ring, count);
}

pub inline fn io_uring_buf_ring_cq_advance(ring: *Ring, br: BufRing, count: i32) void {
    c.io_uring_buf_ring_cq_advance(ring._io_uring, br._io_uring_buf_ring, count);
}

pub inline fn io_uring_buf_ring_available(ring: *Ring, br: BufRing, bgid: u16) i32 {
    return c.io_uring_buf_ring_available(ring._io_uring, br._io_uring_buf_ring, bgid);
}

///Example
///    >>> if sqe := io_uring_get_sqe(ring):
///    ...   # do stuff...
pub inline fn io_uring_get_sqe(ring: *Ring) ?Sqe {
    if (c.io_uring_get_sqe(ring._io_uring)) |sqe| {
        return .{ ._parent = .{ ._sqe = @ptrCast(&sqe[0]) }, ._len = 0, ._io_uring_sqe = sqe };
    }
    return null; // None
}

// TODO: ???
// const getSqe128Doc =
//     \\>>> if sqe := io_uring_get_sqe128(ring):
//     \\...   # do stuff...
// pub fn io_uring_get_sqe128(ring: *Ring) ?Sqe {
//     if (c.io_uring_get_sqe128(ring._io_uring)) |sqe| {
//         // std.debug.print("\nio_uring_get_sqe: {any}\n\n", .{sqe});
//         return .{ ._parent = .{ ._sqe = @ptrCast(&sqe[0]) }, ._len = 1, ._io_uring_sqe = sqe };
//     }
//     return null; // None
// }

///Liburing Version Major
///
///Note
///    - `io_uring_major_version` has been renamed to `liburing_version_major`
pub inline fn liburing_version_major() i32 {
    return c.io_uring_major_version();
}

///Liburing Version Minor
///
///Note
///    - `io_uring_minor_version` has been renamed to `liburing_version_minor`
pub inline fn liburing_version_minor() i32 {
    return c.io_uring_minor_version();
}

///Liburing Version Check
///
///Note
///    - `io_uring_check_version` has been renamed to `liburing_version_check`
pub inline fn liburing_version_check(major: u16, minor: u16) bool {
    return c.io_uring_check_version(major, minor);
}
