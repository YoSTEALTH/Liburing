//! Liburing - control preps: nop, timeouts, cancels, poll, messages, futex, commands
const c = @import("c");
const h = @import("helper.zig");
const setu = @import("setu");
const class = @import("class.zig");
const Futex = @import("futex.zig").Futex;
const FutexType = @import("futex.zig").FutexType;
const EpollEvent = @import("msghdr.zig").EpollEvent;
const EpollEventType = @import("msghdr.zig").EpollEventType;
const Ring = @import("ring.zig").Ring;
const SQE = @import("sqe.zig").SQE;

const py = setu.py;
const Timespec = class.Timespec;
const SiginfoT = class.SiginfoT;

/// >>> io_uring_sqe_set_data(sqe, python_object)
///
/// Warning
///     - Not tested!!!
pub fn io_uring_sqe_set_data(sqe: *SQE, data: usize) py.Error!void {
    c.io_uring_sqe_set_data(try sqe.sqePtr(), @ptrFromInt(data)); // `data`: an address, as `PyLong_AsVoidPtr` read it
}

/// >>> io_uring_sqe_set_data64(sqe, 123)
pub fn io_uring_sqe_set_data64(sqe: *SQE, data: u64) py.Error!void {
    c.io_uring_sqe_set_data64(try sqe.sqePtr(), data);
}

/// >>> io_uring_sqe_set_flags(sqe, IOSQE_IO_HARDLINK)
pub fn io_uring_sqe_set_flags(sqe: *SQE, flags: u32) py.Error!void {
    c.io_uring_sqe_set_flags(try sqe.sqePtr(), flags);
}

/// >>> io_uring_sqe_set_buf_group(sqe, 123)
pub fn io_uring_sqe_set_buf_group(sqe: *SQE, bgid: i32) py.Error!void {
    c.io_uring_sqe_set_buf_group(try sqe.sqePtr(), bgid);
}

pub fn io_uring_prep_poll_add(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_add(s, fd, poll_mask);
    return true;
}

pub fn io_uring_prep_poll_multishot(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_multishot(s, fd, poll_mask);
    return true;
}

pub fn io_uring_prep_poll_remove(sqe: *SQE, user_data: u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_remove(s, user_data);
    return true;
}

pub fn io_uring_prep_poll_update(
    sqe: *SQE,
    old_user_data: u64,
    new_user_data: u64,
    poll_mask: u32,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_poll_update(s, old_user_data, new_user_data, poll_mask, _flags);
    return true;
}

/// >>> io_uring_prep_nop(sqe)
/// True
pub fn io_uring_prep_nop(sqe: *SQE) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_nop(s);
    return true;
}

/// >>> io_uring_prep_nop128(sqe)
/// True
pub fn io_uring_prep_nop128(sqe: *SQE) py.Error!bool {
    const s = try sqe.prepSlot(true) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_nop128(s);
    return true;
}

pub fn io_uring_prep_timeout(sqe: *SQE, ts: *Timespec, count: u32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout(s, ts._timespec, count, _flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

pub fn io_uring_prep_timeout_remove(sqe: *SQE, user_data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_remove(s, user_data, _flags);
    return true;
}

pub fn io_uring_prep_timeout_update(sqe: *SQE, ts: *Timespec, user_data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_update(s, ts._timespec, user_data, _flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

/// Cancels the in-flight request with `user_data` (the value you gave it).
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cancel64(sqe, 123)
///     True
///
/// Note
///     - `user_data` names the first in-flight request with that value, also with `IORING_ASYNC_CANCEL_ALL`
///       (each request has its own entry in the ring's table). To cancel a group, use
///       `io_uring_prep_cancel_fd(sqe, fd, IORING_ASYNC_CANCEL_ALL)`, or one cancel per request.
pub fn io_uring_prep_cancel64(sqe: *SQE, user_data: u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel64(s, user_data, flags orelse 0);
    return true;
}

/// Cancels the in-flight request with `user_data` (the value you gave it).
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cancel(sqe, 123)
///     True
///
/// Note
///     - `user_data` names the first in-flight request with that value, also with `IORING_ASYNC_CANCEL_ALL`
///       (each request has its own entry in the ring's table). To cancel a group, use
///       `io_uring_prep_cancel_fd(sqe, fd, IORING_ASYNC_CANCEL_ALL)`, or one cancel per request.
pub fn io_uring_prep_cancel(sqe: *SQE, user_data: usize, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel(s, @ptrFromInt(user_data), flags orelse 0);
    return true;
}

pub fn io_uring_prep_cancel_fd(sqe: *SQE, fd: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel_fd(s, fd, flags orelse 0);
    return true;
}

pub fn io_uring_prep_link_timeout(sqe: *SQE, ts: *Timespec, flags: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_link_timeout(s, ts._timespec, flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

pub fn io_uring_prep_epoll_wait(sqe: *SQE, fd: i32, events: *EpollEvent, maxevents: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    if (events._owner != null or maxevents < 1 or maxevents > events._len)
        return py.raiseValueError("`maxevents` must be 1..{d}, the size of `EpollEvent(no=...)`", .{events._len});
    c.io_uring_prep_epoll_wait(s, fd, @ptrCast(events._events.?), maxevents, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{EpollEventType.object(events)});
    return true;
}

pub fn io_uring_prep_epoll_ctl(sqe: *SQE, epfd: i32, fd: i32, op: i32, ev: *EpollEvent) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_epoll_ctl(s, epfd, fd, op, @ptrCast(&ev._events.?[ev._index]));
    try h.holdUntilCompletion(sqe, null, &.{EpollEventType.object(ev)});
    return true;
}

/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
pub fn io_uring_prep_msg_ring_cqe_flags(
    sqe: *SQE,
    fd: i32,
    len: u32,
    data: u64,
    flags: u32,
    cqe_flags: u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_msg_ring_cqe_flags(s, fd, len, try messageData(data), flags, cqe_flags);
    return true;
}

/// Posts a completion on another ring (`fd`, its `ring_fd`): `user_data` `data`, `res` `len`.
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_msg_ring(sqe, other.ring_fd, 7, 1234)
///     True
///     >>> io_uring_submit(ring)
///     1
///     >>> io_uring_wait_cqe(other, cqe)
///     0
///     >>> cqe[0].user_data, cqe[0].res
///     (1234, 7)
///
/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
pub fn io_uring_prep_msg_ring(sqe: *SQE, fd: i32, len: u32, data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_msg_ring(s, fd, len, try messageData(data), flags orelse 0);
    return true;
}

/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
pub fn io_uring_prep_msg_ring_fd(
    sqe: *SQE,
    fd: i32,
    source_fd: i32,
    target_fd: i32,
    data: u64,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_msg_ring_fd(s, fd, source_fd, target_fd, try messageData(data), flags orelse 0);
    return true;
}

/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
pub fn io_uring_prep_msg_ring_fd_alloc(sqe: *SQE, fd: i32, source_fd: i32, data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_msg_ring_fd_alloc(s, fd, source_fd, try messageData(data), flags orelse 0);
    return true;
}

/// A message's `data` as the kernel sends it: with `Ring.message_bit` (`ValueError` if `data` has it).
inline fn messageData(data: u64) py.Error!u64 {
    if (data & Ring.message_bit != 0) return raiseMessageData(data);
    return data | Ring.message_bit;
}

noinline fn raiseMessageData(data: u64) py.Error {
    return py.raiseValueError(
        "`io_uring_prep_msg_ring*(data)` must be below 2**63 (bit 63 marks a message): {d}",
        .{data},
    );
}

pub fn io_uring_prep_uring_cmd(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_uring_cmd(s, cmd_op, fd);
    return true;
}

pub fn io_uring_prep_uring_cmd128(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(true) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_uring_cmd128(s, cmd_op, fd);
    return true;
}

/// Waits for a child process's state change, like `os.waitid`: the kernel fills `infop` at the completion.
///
/// Example
///     >>> info = SiginfoT()
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_waitid(sqe, os.P_PID, pid, info, os.WEXITED)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> info.si_pid == pid, info.si_status
///     (True, 7)
///
/// Note
///     - The request holds `infop` until its completion.
pub fn io_uring_prep_waitid(
    sqe: *SQE,
    idtype: c.idtype_t,
    id: c.id_t,
    infop: *SiginfoT,
    options: i32,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_waitid(s, idtype, id, &infop._siginfo_t, options, _flags);
    try h.holdUntilCompletion(sqe, null, &.{class.SiginfoTType.object(infop)});
    return true;
}

pub fn io_uring_prep_futex_wake(
    sqe: *SQE,
    futex: *Futex,
    val: u64,
    mask: u64,
    futex_flags: ?u32,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_futex_wake(s, @ptrFromInt(futex._futex), val, mask, futex_flags orelse 0, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{FutexType.object(futex)});
    return true;
}

pub fn io_uring_prep_futex_wait(
    sqe: *SQE,
    futex: *Futex,
    val: u64,
    mask: u64,
    futex_flags: ?u32,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_futex_wait(s, @ptrFromInt(futex._futex), val, mask, futex_flags orelse 0, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{FutexType.object(futex)});
    return true;
}

pub fn io_uring_prep_futex_waitv(sqe: *SQE, futex: *Futex, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    if (futex._futex_waitv) |v| {
        c.io_uring_prep_futex_waitv(s, v, futex._len, flags orelse 0);
    } else return py.raiseValueError("`io_uring_prep_futex_waitv` - `vector` is not enabled in `Futex`", .{});
    try h.holdUntilCompletion(sqe, null, &.{FutexType.object(futex)});
    return true;
}

pub fn io_uring_prep_cmd_discard(sqe: *SQE, fd: i32, offset: u64, nbytes: u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cmd_discard(s, fd, offset, nbytes);
    return true;
}
