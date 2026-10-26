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

/// Sets the `user_data` of `sqe` to the address-sized int `data`; the completion reports it as `cqe.user_data`.
///
/// Example
///     >>> io_uring_sqe_set_data(sqe, 98)
///
/// Note
///     - Set it on every `sqe` you rely on: one left unset may carry the value of the entry's previous use.
pub fn io_uring_sqe_set_data(sqe: *SQE, data: usize) py.Error!void {
    c.io_uring_sqe_set_data(try sqe.sqePtr(), @ptrFromInt(data)); // `data`: an address, as `PyLong_AsVoidPtr` read it
}

/// Sets the `user_data` of `sqe` to the 64-bit `data`; the completion reports it as `cqe.user_data`.
///
/// Example
///     >>> io_uring_sqe_set_data64(sqe, 123)
///
/// Note
///     - Set it on every `sqe` you rely on: one left unset may carry the value of the entry's previous use.
pub fn io_uring_sqe_set_data64(sqe: *SQE, data: u64) py.Error!void {
    c.io_uring_sqe_set_data64(try sqe.sqePtr(), data);
}

/// Sets the `IOSQE_*` flags of `sqe`.
///
/// Example
///     >>> io_uring_sqe_set_flags(sqe, IOSQE_IO_HARDLINK)
///
/// Flags
///     IOSQE_FIXED_FILE        # fd is a registered (direct) descriptor's index.
///     IOSQE_IO_LINK           # Chain: the next SQE starts after this one completes; an error breaks the chain.
///     IOSQE_IO_HARDLINK       # IOSQE_IO_LINK that survives an error or unexpected result.
///     IOSQE_IO_DRAIN          # Starts after all earlier SQEs complete; later ones wait for it.
///     IOSQE_ASYNC             # Skip the non-blocking attempt, go straight to an async worker.
///     IOSQE_BUFFER_SELECT     # Take a buffer from io_uring_sqe_set_buf_group's group (read / receive).
///     IOSQE_CQE_SKIP_SUCCESS  # No completion if the request succeeds.
///
/// Note
///     - A chain ends at the first SQE without `IOSQE_IO_LINK` / `IOSQE_IO_HARDLINK` and at the end of a submit.
pub fn io_uring_sqe_set_flags(sqe: *SQE, flags: u32) py.Error!void {
    c.io_uring_sqe_set_flags(try sqe.sqePtr(), flags);
}

/// Sets the provided buffer group `bgid` of `sqe`: the group a request with `IOSQE_BUFFER_SELECT` takes its buffer
/// from.
///
/// Example
///     >>> io_uring_sqe_set_buf_group(sqe, 123)
pub fn io_uring_sqe_set_buf_group(sqe: *SQE, bgid: i32) py.Error!void {
    c.io_uring_sqe_set_buf_group(try sqe.sqePtr(), bgid);
}

/// Polls `fd` once for the `poll_mask` events (`POLLIN`, `POLLOUT`, ...); the ready events are returned in `cqe.res`.
///
/// Note
///     - Level triggered: an event pending at the submit completes it at once. One completion, then the poll is
///       gone; poll again for the next event.
///     - `cqe.res` raises `OSError: ECANCELED` after `io_uring_prep_poll_remove` or a cancel.
pub fn io_uring_prep_poll_add(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_add(s, fd, poll_mask);
    return true;
}

/// `io_uring_prep_poll_add` that stays armed: it posts a completion on every event, until removed.
///
/// Note
///     - Linux 5.13+.
///     - Each completion has `IORING_CQE_F_MORE` in `cqe.flags`. One without it is the last (an error, a remove or
///       a cancel: `cqe.res` raises `OSError: ECANCELED`): submit a new poll to keep watching `fd`.
///     - The first completion is level triggered, the following ones edge triggered: consume the event (read all
///       the data) before the next one, or expect spurious completions.
pub fn io_uring_prep_poll_multishot(sqe: *SQE, fd: i32, poll_mask: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_multishot(s, fd, poll_mask);
    return true;
}

/// Removes the poll request with `user_data` (the value you gave it).
///
/// Note
///     - `io_uring_prep_cancel64` that matches poll requests only. `cqe.res`: `0` when removed (the poll's own
///       `cqe.res` raises `OSError: ECANCELED`); `OSError: ENOENT` when not found (it completed already),
///       `OSError: EALREADY` when it is completing, too late to remove.
pub fn io_uring_prep_poll_remove(sqe: *SQE, user_data: u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_poll_remove(s, user_data);
    return true;
}

/// Updates the poll request `old_user_data`: its `user_data` to `new_user_data` and / or its events to `poll_mask`,
/// whichever `flags` (default `0`: nothing) select.
///
/// Flags
///     IORING_POLL_UPDATE_EVENTS     # Wait for poll_mask instead.
///     IORING_POLL_UPDATE_USER_DATA  # user_data becomes new_user_data.
///     IORING_POLL_ADD_MULTI         # Become multishot; needs IORING_POLL_UPDATE_EVENTS too.
///
/// Note
///     - Linux 5.13+.
///     - Only the low 16 bits of the events (`POLLIN`, `POLLOUT`, ...) can change; `EPOLLONESHOT`, `EPOLLEXCLUSIVE`
///       and `EPOLLET` can not: remove the poll and arm a new one.
///     - `cqe.res`: `0` when done; `OSError: ENOENT` when not found (it completed already), `OSError: EALREADY`
///       when it is completing, too late, `OSError: ECANCELED` when re-arming with `poll_mask` failed: the poll
///       ends, its own completion says why.
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

/// Does nothing and completes, `cqe.res` `0`.
///
/// Example
///     >>> io_uring_prep_nop(sqe)
///     True
pub fn io_uring_prep_nop(sqe: *SQE) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_nop(s);
    return true;
}

/// `io_uring_prep_nop` in a 128-byte entry (the ring needs `IORING_SETUP_SQE128` or `IORING_SETUP_SQE_MIXED`).
///
/// Example
///     >>> io_uring_prep_nop128(sqe)
///     True
pub fn io_uring_prep_nop128(sqe: *SQE) py.Error!bool {
    const s = try sqe.prepSlot(true) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_nop128(s);
    return true;
}

/// Completes after the time `ts` (`Timespec`, held until the completion) or after `count` other completions,
/// whichever comes first; `flags` (default `0`) are `IORING_TIMEOUT_*`.
///
/// Flags
///     IORING_TIMEOUT_ABS            # ts is a point in time, not a duration.
///     IORING_TIMEOUT_BOOTTIME       # CLOCK_BOOTTIME (counts suspend); Linux 5.15+.
///     IORING_TIMEOUT_REALTIME       # CLOCK_REALTIME; Linux 5.15+.
///     IORING_TIMEOUT_ETIME_SUCCESS  # Expiry is a success: a linked chain goes on (cqe.res still ETIME); Linux 5.16+.
///     IORING_TIMEOUT_MULTISHOT      # count completions, 0: until removed; IORING_CQE_F_MORE set; Linux 6.4+.
///
/// Note
///     - Linux 5.4+.
///     - `count` `0`: a plain timer, other completions are not counted. `cqe.res`: `0` when `count` completions
///       came first; `OSError: ETIME` when the time passed, `OSError: ECANCELED` when removed
///       (`io_uring_prep_timeout_remove`, a cancel).
///     - Relative to `CLOCK_MONOTONIC` unless a clock flag says otherwise. `IORING_TIMEOUT_MULTISHOT` can not be
///       combined with `IORING_TIMEOUT_ABS`.
///     - `IORING_TIMEOUT_IMMEDIATE_ARG` (Linux 7.1+) is not usable here: `ts` is always a `Timespec`.
pub fn io_uring_prep_timeout(sqe: *SQE, ts: *Timespec, count: u32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout(s, ts._timespec, count, _flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

/// Removes the timeout request with `user_data` (the value you gave it); `flags` (default `0`): the kernel accepts
/// none yet.
///
/// Note
///     - Linux 5.5+.
///     - `cqe.res`: `0` when removed (the timeout's own `cqe.res` raises `OSError: ECANCELED`); `OSError: ENOENT`
///       when not found (it fired already), `OSError: EALREADY` when it is firing, too late to remove.
pub fn io_uring_prep_timeout_remove(sqe: *SQE, user_data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_remove(s, user_data, _flags);
    return true;
}

/// Updates the time of the timeout request with `user_data` (the value you gave it) to `ts` (held until the
/// completion); `flags` (default `0`): `IORING_TIMEOUT_ABS` for a point in time, the only one accepted.
///
/// Note
///     - Linux 5.11+.
///     - `cqe.res`: `0` when updated; `OSError: ENOENT` when not found (it fired already), `OSError: EALREADY` when
///       it is firing, too late to update.
pub fn io_uring_prep_timeout_update(sqe: *SQE, ts: *Timespec, user_data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_update(s, ts._timespec, user_data, _flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

/// Cancels the in-flight request with `user_data` (the value you gave it); `flags` (default `0`) are
/// `IORING_ASYNC_CANCEL_*`.
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cancel64(sqe, 123)
///     True
///
/// Flags
///     IORING_ASYNC_CANCEL_ALL       # Every matching request, not only the first; Linux 5.19+.
///     IORING_ASYNC_CANCEL_ANY       # Match every request of the ring, user_data ignored; Linux 5.19+.
///     IORING_ASYNC_CANCEL_FD        # Match by fd instead (io_uring_prep_cancel_fd); Linux 5.19+.
///     IORING_ASYNC_CANCEL_FD_FIXED  # With IORING_ASYNC_CANCEL_FD: fd is a direct descriptor; Linux 6.0+.
///     IORING_ASYNC_CANCEL_USERDATA  # Match by user_data, the default; Linux 6.6+.
///
/// Note
///     - Linux 5.5+.
///     - `user_data` names the first in-flight request with that value, also with `IORING_ASYNC_CANCEL_ALL`
///       (each request has its own entry in the ring's table). To cancel a group, use
///       `io_uring_prep_cancel_fd(sqe, fd, IORING_ASYNC_CANCEL_ALL)`, or one cancel per request.
///     - `cqe.res`: `0` when cancelled (with `IORING_ASYNC_CANCEL_ALL` / `_ANY`: how many); `OSError: ENOENT` when
///       none was found (it completed already), `OSError: EALREADY` when it is running and past cancelling: wait
///       for its own completion. The cancelled request's `cqe.res` raises `OSError: ECANCELED` (`OSError: EINTR` if
///       it was running); either completion may come first.
///     - Interruptible requests (sockets, poll, timeouts) cancel; disk I/O that has started does not.
///     - `IORING_ASYNC_CANCEL_OP` (Linux 6.6+) needs the opcode in the entry's `len`, which `SQE` does not expose.
pub fn io_uring_prep_cancel64(sqe: *SQE, user_data: u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel64(s, user_data, flags orelse 0);
    return true;
}

/// Cancels the in-flight request with the address-sized `user_data` (the value you gave it); `flags` (default `0`)
/// are `IORING_ASYNC_CANCEL_*`. `io_uring_prep_cancel64` takes any 64-bit value and lists the flags and results.
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cancel(sqe, 123)
///     True
///
/// Note
///     - Linux 5.5+.
///     - `user_data` names the first in-flight request with that value, also with `IORING_ASYNC_CANCEL_ALL`
///       (each request has its own entry in the ring's table). To cancel a group, use
///       `io_uring_prep_cancel_fd(sqe, fd, IORING_ASYNC_CANCEL_ALL)`, or one cancel per request.
///     - `cqe.res`: `0` when cancelled (with `IORING_ASYNC_CANCEL_ALL` / `_ANY`: how many); `OSError: ENOENT` when
///       none was found, `OSError: EALREADY` when past cancelling: wait for its own completion. The cancelled
///       request's `cqe.res` raises `OSError: ECANCELED` (`OSError: EINTR` if it was running); either completion
///       may come first.
pub fn io_uring_prep_cancel(sqe: *SQE, user_data: usize, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel(s, @ptrFromInt(user_data), flags orelse 0);
    return true;
}

/// Cancels the in-flight requests of `fd`; `flags` (default `0`) are `IORING_ASYNC_CANCEL_*`
/// (`IORING_ASYNC_CANCEL_ALL` for all of them, not only the first; `IORING_ASYNC_CANCEL_FD_FIXED`, Linux 6.0+,
/// when `fd` is a direct descriptor). `IORING_ASYNC_CANCEL_FD` is set already.
///
/// Note
///     - Linux 5.19+.
///     - `cqe.res`: `0` when cancelled (with `IORING_ASYNC_CANCEL_ALL`: how many); `OSError: ENOENT` when none was
///       found, `OSError: EALREADY` when past cancelling: wait for its own completion. Each cancelled request's
///       `cqe.res` raises `OSError: ECANCELED` (`OSError: EINTR` if it was running); the completions come in no
///       fixed order.
pub fn io_uring_prep_cancel_fd(sqe: *SQE, fd: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cancel_fd(s, fd, flags orelse 0);
    return true;
}

/// Limits the time of the previous request, linked to it with `IOSQE_IO_LINK`, to `ts` (`Timespec`, held until
/// the completion); `flags` are `IORING_TIMEOUT_ABS`, `IORING_TIMEOUT_BOOTTIME`, `IORING_TIMEOUT_REALTIME`,
/// `IORING_TIMEOUT_ETIME_SUCCESS` (as in `io_uring_prep_timeout`), or `0`.
///
/// Note
///     - Linux 5.5+.
///     - Must directly follow the request it limits, and applies to that one only: to limit a whole chain, link it
///       after the chain's last request. A chain of only a link timeout is invalid.
///     - `cqe.res` raises `OSError: ETIME` when it expired: the linked request's `cqe.res` raises
///       `OSError: ECANCELED` (`OSError: EINTR` if it was running), and so does the rest of its chain;
///       `OSError: ECANCELED` when the linked request completed first; `OSError: ENOENT` when it was gone as the
///       timer expired.
pub fn io_uring_prep_link_timeout(sqe: *SQE, ts: *Timespec, flags: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_link_timeout(s, ts._timespec, flags);
    try h.holdUntilCompletion(sqe, null, &.{class.TimespecType.object(ts)});
    return true;
}

/// Waits for events of the epoll `fd`, into `events` (held until the completion); `maxevents` is `1` to the size
/// of `EpollEvent(no=...)`, else `ValueError`. `events` must be one made with `no=`, not a single item.
///
/// Note
///     - Linux 6.15+.
///     - `cqe.res` is the number of events filled in, like `epoll_wait(2)`; its errors raise `OSError`.
///     - For event loops that still have epoll users: they can wait through the ring instead of adding the ring's
///       `fd` to the epoll set.
pub fn io_uring_prep_epoll_wait(sqe: *SQE, fd: i32, events: *EpollEvent, maxevents: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    if (events._owner != null or maxevents < 1 or maxevents > events._len)
        return py.raiseValueError("`maxevents` must be 1..{d}, the size of `EpollEvent(no=...)`", .{events._len});
    c.io_uring_prep_epoll_wait(s, fd, @ptrCast(events._events.?), maxevents, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{EpollEventType.object(events)});
    return true;
}

/// `epoll_ctl(2)` on the epoll `epfd`: `op` (`EPOLL_CTL_ADD`, `EPOLL_CTL_MOD`, `EPOLL_CTL_DEL`) for `fd` with the
/// event `ev` (held until the completion; ignored by `EPOLL_CTL_DEL`).
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res` is `0`; the errors of `epoll_ctl(2)` raise `OSError`.
pub fn io_uring_prep_epoll_ctl(sqe: *SQE, epfd: i32, fd: i32, op: i32, ev: *EpollEvent) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_epoll_ctl(s, epfd, fd, op, @ptrCast(&ev._events.?[ev._index]));
    try h.holdUntilCompletion(sqe, null, &.{EpollEventType.object(ev)});
    return true;
}

/// `io_uring_prep_msg_ring` that also sets the `cqe.flags` of the posted completion to `cqe_flags`
/// (`IORING_MSG_RING_FLAGS_PASS` is set; `flags` adds to it).
///
/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
///     - The kernel may set further bits in the target's `cqe.flags`.
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

/// Posts a completion on another ring (`fd`, its `ring_fd`): `user_data` `data`, `res` `len`; `flags` (default `0`)
/// are `IORING_MSG_RING_*`.
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
///     - Linux 5.18+. Any ring you have access to is a target, this one included: a wake-up for whoever waits on
///       it, or a 32 + 64 bit message (`len`, `data`).
///     - This ring's `cqe.res`: `0` when posted; `OSError: EBADFD` when `fd` is not a ring or a disabled one,
///       `OSError: EOVERFLOW` when the target's completion queue is full and overflowing.
pub fn io_uring_prep_msg_ring(sqe: *SQE, fd: i32, len: u32, data: u64, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_msg_ring(s, fd, len, try messageData(data), flags orelse 0);
    return true;
}

/// Sends the registered file `source_fd` of this ring to the slot `target_fd` of the ring `fd`; the target ring gets a
/// completion with `user_data` `data`; `flags` (default `0`) are `IORING_MSG_RING_*`.
///
/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
///     - Linux 6.0+. The target must be another ring (`OSError: EINVAL` for this one).
///     - This ring's `cqe.res`: `0` when sent; `OSError: EBADFD` when `fd` is not a ring or a disabled one,
///       `OSError: ENFILE` when the target's table is full, `OSError: EOVERFLOW` when the target's completion queue
///       is full and overflowing.
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

/// `io_uring_prep_msg_ring_fd`, but the target ring picks a free slot, returned in its `cqe.res`.
///
/// Note
///     - `data` is the target's `cqe.user_data`, below `2**63` (`ValueError`): Liburing sends it with bit 63 set,
///       which tells the target ring the completion is a message, not one of its own requests.
///     - Linux 6.0+. This ring's `cqe.res`: `0` when sent; `OSError: ENFILE` when the target's table has no free
///       slot (the other errors as in `io_uring_prep_msg_ring_fd`).
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

/// Sends the file-specific command `cmd_op` to `fd` (`IORING_OP_URING_CMD`, an async `ioctl(2)`).
///
/// Note
///     - Linux 5.19+.
///     - Only `cmd_op` and `fd` are set (the reserved fields zeroed); a command's own operands live in the entry's
///       command bytes, which `SQE` does not expose. `cqe.res` is whatever the driver returns.
pub fn io_uring_prep_uring_cmd(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_uring_cmd(s, cmd_op, fd);
    return true;
}

/// `io_uring_prep_uring_cmd` in a 128-byte entry (the ring needs `IORING_SETUP_SQE128` or `IORING_SETUP_SQE_MIXED`).
///
/// Note
///     - Only `cmd_op` and `fd` are set (the reserved fields zeroed); the 80 command bytes, which `SQE` does not
///       expose, carry the command's own operands. `cqe.res` is whatever the driver returns.
pub fn io_uring_prep_uring_cmd128(sqe: *SQE, cmd_op: i32, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(true) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_uring_cmd128(s, cmd_op, fd);
    return true;
}

/// Waits for a child process's state change, like `os.waitid`: the kernel fills `infop` at the completion; `idtype`
/// (`os.P_PID`, `os.P_PGID`, `os.P_ALL`, ...) and `id` pick the children, `options` (`os.WEXITED`, ...) the changes;
/// `flags` (default `0`) has no values yet.
///
/// Example
///     >>> pid = os.posix_spawn('/bin/sh', ['sh', '-c', 'exit 7'], os.environ)
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
///     - Linux 6.7+.
///     - The request holds `infop` until its completion.
///     - `cqe.res` is `0` (`infop` says which child and how: `si_pid`, `si_code`, `si_status`); the errors of
///       `waitid(2)` raise `OSError` (`OSError: ECHILD`: no such child).
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

/// Wakes up to `val` waiters of `futex` whose wait mask matches `mask`; the number woken is returned in `cqe.res`.
/// `futex_flags` are `FUTEX2_*` (default `0`); `futex` is held until the completion.
///
/// Note
///     - Linux 6.7+.
///     - Like `FUTEX_WAKE_BITSET`: a waiter is woken when its `mask` and this one share a bit;
///       `FUTEX_BITSET_MATCH_ANY` wakes any waiter. `flags` (default `0`) has no values yet.
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

/// Waits on `futex` while its value is `val` (matched with `mask`); `futex_flags` are `FUTEX2_*` (default `0`);
/// `futex` is held until the completion.
///
/// Note
///     - Linux 6.7+.
///     - Like `FUTEX_WAIT_BITSET`: a wake reaches it when the waker's mask shares a bit with `mask`
///       (`FUTEX_BITSET_MATCH_ANY`: any wake). `futex_flags` are `futex2(2)` flags (`FUTEX2_SIZE_U32`,
///       `FUTEX2_PRIVATE`, ...), not `futex(2)` ones. `flags` (default `0`) has no values yet.
///     - `cqe.res`: `0` when woken; `OSError: EAGAIN` when the value was not `val`, `OSError: ECANCELED` when
///       cancelled. No timeout parameter: link an `io_uring_prep_link_timeout` after it.
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

/// Waits on several futexes at once: `Futex` made with a vector (else `ValueError`), held until the completion;
/// `flags` (default `0`) has no values yet.
///
/// Note
///     - Linux 6.7+.
///     - Each entry of the vector carries its own value and mask (`futex_waitv(2)`); at most `FUTEX_WAITV_MAX`
///       (128) entries.
///     - `cqe.res` is the index of the entry that was woken; `OSError: ECANCELED` when cancelled. No timeout
///       parameter: link an `io_uring_prep_link_timeout` after it.
pub fn io_uring_prep_futex_waitv(sqe: *SQE, futex: *Futex, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    if (futex._futex_waitv) |v| {
        c.io_uring_prep_futex_waitv(s, v, futex._len, flags orelse 0);
    } else return py.raiseValueError("`io_uring_prep_futex_waitv` - `vector` is not enabled in `Futex`", .{});
    try h.holdUntilCompletion(sqe, null, &.{FutexType.object(futex)});
    return true;
}

/// Discards `nbytes` of the block device `fd` from `offset` (`BLOCK_URING_CMD_DISCARD`).
///
/// Note
///     - Linux 6.12+.
///     - `cqe.res` is `0`, or the negated `errno`.
///     - Unlike the `ioctl`, several discards may run at once and reads / writes of the range are not held off:
///       keep your own I/O off the range, or the data and the page cache (invalidated best-effort) may go stale.
pub fn io_uring_prep_cmd_discard(sqe: *SQE, fd: i32, offset: u64, nbytes: u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cmd_discard(s, fd, offset, nbytes);
    return true;
}
