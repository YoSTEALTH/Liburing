//! Liburing - network preps
const c = @import("c");
const h = @import("helper.zig");
const setu = @import("setu");
const class = @import("class.zig");
const releaseFailed = @import("helper.zig").releaseFailed;
const RecvmsgOut = @import("msghdr.zig").RecvmsgOut;
const Cmsghdr = @import("msghdr.zig").Cmsghdr;
const Msghdr = @import("msghdr.zig").Msghdr;
const CmsghdrType = @import("msghdr.zig").CmsghdrType;
const MsghdrType = @import("msghdr.zig").MsghdrType;
const RecvmsgOutType = @import("msghdr.zig").RecvmsgOutType;
const RingType = @import("ring.zig").RingType;
const Sockaddr = @import("socket.zig").Sockaddr;
const SockaddrType = @import("socket.zig").SockaddrType;
const SQE = @import("sqe.zig").SQE;

const py = setu.py;
const Object = setu.c.Object;

/// Receives a message into `msg` (`recvmsg`); `cqe.res` is the number of bytes received.
///
/// Note
///     - Linux 5.3+.
///     - `TypeError` if the `iov` or `control` of `msg` is read-only. `msg` is held until the completion.
///     - `cqe.flags` has `IORING_CQE_F_SOCK_NONEMPTY` (Linux 5.19+) when the socket still had data after the receive.
pub fn io_uring_prep_recvmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    try msg.checkWritable("io_uring_prep_recvmsg");
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Receives messages into the provided buffer group (`IOSQE_BUFFER_SELECT`), one completion per message; parse each
/// buffer with `io_uring_recvmsg_validate`.
///
/// Note
///     - Linux 6.0+.
///     - Needs `IOSQE_BUFFER_SELECT` and a buffer group (`io_uring_sqe_set_buf_group`), and no `MSG_WAITALL`; each
///       completion takes one buffer: `IORING_CQE_F_BUFFER` in `cqe.flags`, the id in
///       `cqe.flags >> IORING_CQE_BUFFER_SHIFT`.
///     - Each buffer starts with an `io_uring_recvmsg_out` header, then the name (`namelen` bytes), the control data
///       (`controllen` bytes) and the payload: `cqe.res` counts all of it.
///     - Check `cqe.flags` of every completion, whatever `cqe.res`: one without `IORING_CQE_F_MORE` (an `OSError`,
///       `OSError: ENOBUFS` when the group runs out, a cancel) ends the request; submit a new one to keep receiving.
///     - `msg` only gives `namelen` and `controllen` (`Msghdr(namelen=16, controllen=0)`).
///     - `TypeError` if the `iov` or `control` of `msg` is read-only. `msg` is held until the completion.
pub fn io_uring_prep_recvmsg_multishot(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    try msg.checkWritable("io_uring_prep_recvmsg_multishot");
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg_multishot(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Sends the message `msg` (`sendmsg`); `cqe.res` is the number of bytes sent.
///
/// Note
///     - Linux 5.3+.
///     - `msg` is held until the completion.
///     - With `IOSQE_IO_LINK` set `MSG_WAITALL` in `flags`: a short send does not fail the link otherwise.
pub fn io_uring_prep_sendmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_sendmsg(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Accepts a connection on the listening socket `fd` (`accept4`); `cqe.res` is the new fd. `addr` (optional) gets
/// the peer address at the completion and is held until then.
///
/// Example
///     >>> addr = Sockaddr()
///     >>> io_uring_prep_accept(sqe, fd, addr)
///     True
///
/// Note
///     - Linux 5.5+.
///     - `flags` are the `accept4` flags (`SOCK_NONBLOCK`, `SOCK_CLOEXEC`).
pub fn io_uring_prep_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // written at the completion
    try h.holdUntilCompletion(sqe, null, if (addr) |a| &.{SockaddrType.object(a)} else &.{});
    const _flags = flags orelse 0;
    c.io_uring_prep_accept(s, fd, if (addr) |a| a.addrPtr() else null, if (addr) |a| &a._socklen else null, _flags);
    return true;
}

/// Like `io_uring_prep_accept`, but the connection goes into a direct (registered) descriptor.
///
/// Note
///     - Function argument `file_index` position has changed for C origin for better usability.
///     - If `file_index` is `None` (or `IORING_FILE_INDEX_ALLOC`) a free direct descriptor will be auto assigned.
///       The allocated descriptor is returned in the `cqe.res`; `OSError: ENFILE` when the table has no free slot.
///     - With an explicit `file_index` `cqe.res` is `0`: remember the slot. A slot already holding a file has it
///       closed and replaced.
///     - Needs a registered file table first (`io_uring_register_files`, `io_uring_register_files_sparse`); use
///       the descriptor with `IOSQE_FIXED_FILE`. `io_uring_register_file_alloc_range` keeps allocated slots apart
///       from explicit ones.
///     - `SOCK_CLOEXEC` in `flags` gives `OSError: EINVAL`.
pub fn io_uring_prep_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, file_index: ?u32, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // written at the completion
    try h.holdUntilCompletion(sqe, null, if (addr) |a| &.{SockaddrType.object(a)} else &.{});
    const _flags = flags orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_accept_direct(
        s,
        fd,
        if (addr) |a| a.addrPtr() else null,
        if (addr) |a| &a._socklen else null,
        _flags,
        _file_index,
    );
    return true;
}

/// Accepts connections repeatedly, one completion per connection (`cqe.res` is the new fd); `addr` (optional) gets
/// the peer address.
///
/// Note
///     - Linux 5.19+.
///     - Same as `io_uring_prep_accept`, but keeps going while `IORING_CQE_F_MORE` is set; a completion without it
///       (an error, a cancel) ends the request, submit a new one to keep accepting.
///     - Every connection overwrites `addr`, possibly before the last one was read: usually leave it `None`.
pub fn io_uring_prep_multishot_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // written at the completion
    try h.holdUntilCompletion(sqe, null, if (addr) |a| &.{SockaddrType.object(a)} else &.{});
    const _flags = flags orelse 0;
    c.io_uring_prep_multishot_accept(
        s,
        fd,
        if (addr) |a| a.addrPtr() else null,
        if (addr) |a| &a._socklen else null,
        _flags,
    );
    return true;
}

/// Like `io_uring_prep_multishot_accept`, but each connection goes into a free direct (registered) descriptor,
/// returned in `cqe.res`.
///
/// Note
///     - Linux 5.19+.
///     - Needs a registered file table first (`io_uring_register_files_sparse`); `OSError: ENFILE` ends the request
///       when it has no free slot. `SOCK_CLOEXEC` in `flags` gives `OSError: EINVAL`.
pub fn io_uring_prep_multishot_accept_direct(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // written at the completion
    try h.holdUntilCompletion(sqe, null, if (addr) |a| &.{SockaddrType.object(a)} else &.{});
    const _flags = flags orelse 0;
    c.io_uring_prep_multishot_accept_direct(
        s,
        fd,
        if (addr) |a| a.addrPtr() else null,
        if (addr) |a| &a._socklen else null,
        _flags,
    );
    return true;
}

/// Connects `fd` to the address `addr` (`connect`); `cqe.res` is `0`. `addr` is held until the completion.
///
/// Note
///     - Linux 5.5+.
pub fn io_uring_prep_connect(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_connect(s, fd, addr.addrPtr(), addr._socklen);
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(addr)});
    return true;
}

/// Binds `fd` to the address `addr` (`bind`); `cqe.res` is `0`. `addr` is held until the completion.
///
/// Note
///     - Linux 6.11+.
pub fn io_uring_prep_bind(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_bind(s, fd, addr.addrPtr(), addr._socklen);
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(addr)});
    return true;
}

/// Marks `fd` as a listening socket with the given `backlog` (`listen`); `cqe.res` is `0`.
///
/// Note
///     - Linux 6.11+.
pub fn io_uring_prep_listen(sqe: *SQE, fd: i32, backlog: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_listen(s, fd, backlog);
    return true;
}

/// Sends `buf` on the socket `sockfd` (`send`); `cqe.res` is the number of bytes sent.
///
/// Note
///     - Linux 5.6+.
///     - `buf` is held (locked: no resize) until the completion.
///     - With `IOSQE_IO_LINK` set `MSG_WAITALL` in `flags`: a short send does not fail the link otherwise.
pub fn io_uring_prep_send(sqe: *SQE, sockfd: i32, buf: py.OwnedBuffer, flags: ?i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _flags = flags orelse 0;
    c.io_uring_prep_send(s, sockfd, buf.data.ptr, buf.data.len, _flags);
    return true;
}

/// Sends a bundle of provided buffers (`IOSQE_BUFFER_SELECT`) in one request, `len` at most bytes (`None`/`0`: all
/// that fit).
///
/// Note
///     - Linux 6.10+ (`IORING_FEAT_RECVSEND_BUNDLE`). The man page says `len` must be `0`, else `OSError: EINVAL`.
///     - Needs `IOSQE_BUFFER_SELECT` and the group of a buffer ring (`io_uring_sqe_set_buf_group`): sends from it
///       until it runs out of buffers, which also serializes sends in flight on one socket.
///     - One completion: `cqe.res` is the total number of bytes sent, `cqe.flags >> IORING_CQE_BUFFER_SHIFT` the
///       first buffer id; the rest follow it in ring order until `cqe.res` bytes are covered.
pub fn io_uring_prep_send_bundle(sqe: *SQE, sockfd: i32, len: ?usize, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_send_bundle(s, sockfd, len orelse 0, flags orelse 0);
    return true;
}

/// Sets the destination address of a send already prepared on this `sqe` (UDP); `dest_addr` is held until the
/// completion.
///
/// Note
///     - Call it after `io_uring_prep_send` or `io_uring_prep_send_zc` on the same `sqe`: like `sendto(2)` for
///       an unconnected socket.
pub fn io_uring_prep_send_set_addr(sqe: *SQE, dest_addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_send_set_addr(s, dest_addr.addrPtr(), @intCast(dest_addr._socklen));
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(dest_addr)});
    return true;
}

/// Sends `buf` to the address `addr` (`sendto`, UDP); `cqe.res` is the number of bytes sent. `addr` and `buf` are
/// held until the completion.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `addr` must suit the socket's family.
pub fn io_uring_prep_sendto(sqe: *SQE, sockfd: i32, buf: py.OwnedBuffer, addr: *Sockaddr, flags: ?i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    // first: owns the buffer from here, on every path
    try h.holdUntilCompletion(sqe, &buf, &.{SockaddrType.object(addr)});
    c.io_uring_prep_sendto(
        s,
        sockfd,
        buf.data.ptr,
        buf.data.len,
        flags orelse 0,
        addr.addrPtr(),
        addr._socklen,
    );
    return true;
}

/// Zero-copy send of `buf`; `zc_flags` are `IORING_RECVSEND_*` flags. Completes twice: the result, then a
/// notification (`IORING_CQE_F_NOTIF`) once `buf` can be reused.
///
/// Note
///     - Linux 6.0+.
///     - The first completion is the usual one: `cqe.res` is the number of bytes sent (`OSError` on failure), and
///       `IORING_CQE_F_MORE` in `cqe.flags` says the notification follows (also after a failure: check the flag
///       first). The notification has the same `user_data`, `cqe.res` `0` and `IORING_CQE_F_NOTIF`.
///     - Do not change `buf` before the notification; the ring holds it (locked: no resize) until then. A
///       notification says nothing about the data having been sent or received.
///     - Zero copy is not guaranteed; `OSError: EOPNOTSUPP` means the protocol has none, use `io_uring_prep_send`.
///     - `IORING_SEND_ZC_REPORT_USAGE` in `zc_flags`: the notification's `cqe.res` is `IORING_NOTIF_USAGE_ZC_COPIED`
///       if the data was copied after all, else `0`.
///     - `OSError: ENOMEM` can mean a too low locked memory limit (`ulimit -l`).
///     - With `IOSQE_IO_LINK` set `MSG_WAITALL` in `flags`: a short send does not fail the link otherwise.
pub fn io_uring_prep_send_zc(sqe: *SQE, sockfd: i32, buf: py.OwnedBuffer, flags: ?i32, zc_flags: ?u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_send_zc(s, sockfd, buf.data.ptr, buf.data.len, flags orelse 0, zc_flags orelse 0);
    return true;
}

/// Zero-copy send of `buf`, which must lie in the registered buffer `buf_index` (`None`: `0`).
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - Linux 6.0+. Completes like `io_uring_prep_send_zc`: the result, then the notification (`IORING_CQE_F_NOTIF`)
///       that frees `buf`.
///     - `buf` is a part of a buffer registered with `io_uring_register_buffers`; it need not start at its start.
pub fn io_uring_prep_send_zc_fixed(
    sqe: *SQE,
    sockfd: i32,
    buf: py.OwnedBuffer,
    buf_index: ?u32,
    flags: ?i32,
    zc_flags: ?u32,
) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_send_zc_fixed(
        s,
        sockfd,
        buf.data.ptr,
        buf.data.len,
        flags orelse 0,
        zc_flags orelse 0,
        buf_index orelse 0,
    );
    return true;
}

/// Zero-copy `io_uring_prep_sendmsg`: completes twice, the result then a notification (`IORING_CQE_F_NOTIF`) once
/// the buffers can be reused. `msg` is held until the completion.
///
/// Note
///     - Linux 6.1+.
///     - The completions are those of `io_uring_prep_send_zc`: `IORING_CQE_F_MORE` on the first means the
///       notification follows; do not change the `iov` buffers of `msg` before it.
///     - `OSError: ENOMEM` can mean a too low locked memory limit (`ulimit -l`).
pub fn io_uring_prep_sendmsg_zc(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_sendmsg_zc(s, fd, &msg._msghdr, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Zero-copy `io_uring_prep_sendmsg` whose `iov` buffers lie in the registered buffer `buf_index`.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - Completes like `io_uring_prep_send_zc`: `cqe.res` is the number of bytes sent, then the notification
///       (`IORING_CQE_F_NOTIF`); do not change the buffers before it.
///     - The buffers must be registered with `io_uring_register_buffers`.
pub fn io_uring_prep_sendmsg_zc_fixed(sqe: *SQE, fd: i32, msg: *Msghdr, buf_index: u32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_sendmsg_zc_fixed(s, fd, &msg._msghdr, flags orelse 0, buf_index);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Receives into `buf` from the socket `sockfd` (`recv`); `cqe.res` is the number of bytes received.
///
/// Note
///     - Linux 5.6+.
///     - `buf` may be `None` when the buffer comes from a provided buffer group (`IOSQE_BUFFER_SELECT`): then
///       `cqe.flags` has `IORING_CQE_F_BUFFER` and the buffer id in `cqe.flags >> IORING_CQE_BUFFER_SHIFT`.
///     - `buf` is held (locked: no resize) until the completion.
///     - `cqe.flags` has `IORING_CQE_F_SOCK_NONEMPTY` (Linux 5.19+) when the socket still had data after the receive.
pub fn io_uring_prep_recv(sqe: *SQE, sockfd: i32, buf: ?py.OwnedWritableBuffer, flags: ?i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    if (buf) |b| {
        c.io_uring_prep_recv(s, sockfd, b.data.ptr, b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv(s, sockfd, null, 0, flags orelse 0);
    }
    return true;
}

/// Like `io_uring_prep_recv`, but keeps receiving, one completion per message, while `IORING_CQE_F_MORE` is set.
///
/// Note
///     - Linux 6.0+.
///     - `buf` is normally `None`: the buffers come from a provided buffer group (`IOSQE_BUFFER_SELECT` and
///       `io_uring_sqe_set_buf_group`, required), one per completion (`IORING_CQE_F_BUFFER`, the id in
///       `cqe.flags >> IORING_CQE_BUFFER_SHIFT`). A `buf` only caps each receive at `len(buf)` bytes (fairness
///       between many sockets). `MSG_WAITALL` is not allowed.
///     - Check `cqe.flags` of every completion, whatever `cqe.res`: one without `IORING_CQE_F_MORE` (an `OSError`,
///       the peer closing, `OSError: ENOBUFS` when the group runs out, a cancel) ends the request; submit a new one
///       to keep receiving. Return used buffers to the ring promptly.
pub fn io_uring_prep_recv_multishot(sqe: *SQE, sockfd: i32, buf: ?py.OwnedWritableBuffer, flags: ?i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    if (buf) |b| {
        c.io_uring_prep_recv_multishot(s, sockfd, b.data.ptr, b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv_multishot(s, sockfd, null, 0, flags orelse 0);
    }
    return true;
}

/// Checks that `buf` holds a message received by `io_uring_prep_recvmsg_multishot` (`ValueError` if it is too
/// short for the `namelen` and `controllen` of `msgh`) and gives its parts.
///
/// Type
///     return: RecvmsgOut
///
/// Note
///     - The result's `namelen`, `controllen`, `payloadlen` and `flags` are what `recvmsg` would have reported for
///       the message; `msgh` is the `Msghdr` the request was submitted with.
pub fn io_uring_recvmsg_validate(buf: *Object, msgh: *Msghdr) py.Error!*Object {
    const view = try py.WritableBuffer.from(buf);
    errdefer view.deinit();
    const len = try py.narrow(c_int, view.data.len, "`io_uring_recvmsg_validate(buf)` length");
    const out = c.io_uring_recvmsg_validate(view.data.ptr, len, &msgh._msghdr) orelse
        return py.raiseValueError(
            "`io_uring_recvmsg_validate(buf)` - `buf` is too short for the header, name and control data",
            .{},
        );
    // the view moves into the result, so the buffer stays locked (can not be resized) while it lives
    return RecvmsgOutType.new(
        .{ ._recvmsg_out = out, ._len = view.data.len, ._view = .{ .data = view.data, .view = view.view } },
    );
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
    return try CmsghdrType.new(.{ ._cmsghdr = hdr, ._owner = class.keep(RecvmsgOutType.object(o)) });
}

/// The control message after `cmsg`, or `None`.
///
/// Type
///     return: Cmsghdr | None
pub fn io_uring_recvmsg_cmsg_nexthdr(o: *RecvmsgOut, msgh: *Msghdr, cmsg: *Cmsghdr) py.Error!?*Object {
    const hdr = c.io_uring_recvmsg_cmsg_nexthdr(o._recvmsg_out.?, &msgh._msghdr, cmsg._cmsghdr.?) orelse return null;
    return try CmsghdrType.new(.{ ._cmsghdr = hdr, ._owner = class.keep(RecvmsgOutType.object(o)) });
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

/// Provides `nr` buffers of `len(addr) // nr` bytes each, laid out one after the other in `addr`.
///
/// Example
///     >>> area = bytearray(64)
///     >>> io_uring_prep_provide_buffers(sqe, area, 4, 1, 0)  # 4 buffers of 16 bytes: group 1, ids 0..3
///     True
///
/// Note
///     - Linux 5.7+. `cqe.res` is `0` on success.
///     - The buffer ids are `bid` to `bid + nr - 1`, all at most `65535` (`OSError: E2BIG` or `OSError: EINVAL`
///       otherwise). A request uses the group with `IOSQE_BUFFER_SELECT` and `io_uring_sqe_set_buf_group` (reads
///       and socket receives only, `OSError: EINVAL` otherwise; a vectored one with a single `iov`); its completion has
///       `IORING_CQE_F_BUFFER` and the id in `cqe.flags >> IORING_CQE_BUFFER_SHIFT`.
///     - A consumed buffer is forgotten by the kernel: provide it again to reuse it.
///     - The kernel uses the buffers until they are consumed or removed, so the ring holds `addr` (locked: no
///       resize) until its exit; giving a part of an area it already holds again takes nothing more.
///     - `sqe` must come from `io_uring_get_sqe` or be an `Sqe(ring)` (`TypeError` for an `Sqe` template: no ring
///       to hold `addr`).
///     - `ValueError` if `nr` is less than 1 or `addr` is shorter than `nr` bytes.
///     - Legacy: prefer a buffer ring (`io_uring_setup_buf_ring`), which needs no request per buffer.
pub fn io_uring_prep_provide_buffers(
    sqe: *SQE,
    addr: py.OwnedWritableBuffer,
    nr: i32,
    bgid: i32,
    bid: i32,
) py.Error!bool {
    const ring_obj = if (sqe._owner) |o| (if (RingType.check(o)) o else null) else null;
    const ring = RingType.data(ring_obj orelse return releaseFailed(addr, py.raiseTypeError(
        "`io_uring_prep_provide_buffers(sqe)` is from `io_uring_get_sqe` or an `Sqe(ring)`: the ring holds `addr`",
        .{},
    )));
    if (nr <= 0) return releaseFailed(
        addr,
        py.raiseValueError("`io_uring_prep_provide_buffers(nr)` must be at least 1", .{}),
    );
    const each = addr.data.len / @as(usize, @intCast(nr)); // cast: nr > 0
    if (each == 0) return releaseFailed(
        addr,
        py.raiseValueError("`io_uring_prep_provide_buffers(addr)` is shorter than `nr` buffers", .{}),
    );
    const len = py.narrow(c_int, each, "`io_uring_prep_provide_buffers(addr)` buffer length") catch |err| {
        return releaseFailed(addr, err);
    };
    const s = try h.prepSlot(sqe, &addr) orelse return false;
    errdefer sqe.undoSlot();
    try ring.keepProvided(addr.view); // owns the view from here (released if it fails)
    c.io_uring_prep_provide_buffers(s, addr.data.ptr, len, nr, bgid, bid);
    return true;
}

/// Removes up to `nr` buffers of the group `bgid` that `io_uring_prep_provide_buffers` gave; `cqe.res` is the
/// number removed.
///
/// Note
///     - Linux 5.7+. `OSError: ENOENT` when the group `bgid` has no buffers.
///     - Legacy: prefer a buffer ring (`io_uring_setup_buf_ring`, `io_uring_free_buf_ring`).
pub fn io_uring_prep_remove_buffers(sqe: *SQE, nr: i32, bgid: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_remove_buffers(s, nr, bgid);
    return true;
}

/// Shuts down part of a full-duplex connection (`shutdown`); `how` is `SHUT_RD`, `SHUT_WR` or `SHUT_RDWR`.
/// `cqe.res` is `0`.
///
/// Note
///     - Linux 5.11+.
pub fn io_uring_prep_shutdown(sqe: *SQE, fd: i32, how: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_shutdown(s, fd, how);
    return true;
}

/// Creates a socket (`socket`); `cqe.res` is the new fd. `protocol` and `flags` default to `0`.
///
/// Note
///     - Linux 5.19+.
///     - `flags` is unused by the kernel so far (the `SOCK_*` type flags go into `type`).
pub fn io_uring_prep_socket(sqe: *SQE, domain: i32, @"type": i32, protocol: ?i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    c.io_uring_prep_socket(s, domain, @"type", _protocol, _flags);
    return true;
}

/// Creates a socket into a direct (registered) descriptor. `protocol` and `flags` default to `0`.
///
/// Note
///     - Linux 5.19+.
///     - `io_uring_prep_socket_direct` includes `io_uring_prep_socket_direct_alloc` feature: `file_index=None`
///       (or `IORING_FILE_INDEX_ALLOC`) assigns a free direct descriptor, returned in `cqe.res`; `OSError: ENFILE`
///       when the table has no free slot.
///     - With an explicit `file_index` `cqe.res` is `0`. A slot already holding a file has it closed and replaced.
///     - Needs a registered file table first (`io_uring_register_files`, `io_uring_register_files_sparse`); use
///       the descriptor with `IOSQE_FIXED_FILE`.
pub fn io_uring_prep_socket_direct(
    sqe: *SQE,
    domain: i32,
    @"type": i32,
    protocol: ?i32,
    file_index: ?u32,
    flags: ?u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_socket_direct(s, domain, @"type", _protocol, _file_index, _flags);
    return true;
}

/// Runs a socket command (`io_uring_socket_op`) on `fd`; `optval` is the data going in or out.
///
/// Example
///     >>> buf = bytearray((1).to_bytes(4, "little"))
///     >>> io_uring_prep_cmd_sock(
///     ...     sqe, io_uring_socket_op.SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_KEEPALIVE, buf,
///     ... )
///     True
///
/// Example
///     # or: a bytes option
///     >>> buf = bytearray(b'eth1')
///     >>> io_uring_prep_cmd_sock(
///     ...     sqe, io_uring_socket_op.SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_BINDTODEVICE, buf,
///     ... )
///     True
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
///     - Linux 6.7+ (`SOCKET_URING_OP_SIOCINQ`, `SOCKET_URING_OP_SIOCOUTQ`, `SOCKET_URING_OP_GETSOCKOPT`,
///       `SOCKET_URING_OP_SETSOCKOPT`); `SOCKET_URING_OP_TX_TIMESTAMP` 6.17+; `SOCKET_URING_OP_GETSOCKNAME` 6.19+.
///     - `optval` is held (locked: no resize) until the completion.
///     - `SOCKET_URING_OP_SIOCINQ` / `SOCKET_URING_OP_SIOCOUTQ`: `cqe.res` is the number of unread / unsent bytes
///       queued (`OSError: EINVAL` on a listening socket); `level`, `optname` and `optval` are ignored.
///     - `SOCKET_URING_OP_GETSOCKOPT`: `SOL_SOCKET` options only; the option is written into `optval` and
///       `cqe.res` is its size. `SOCKET_URING_OP_SETSOCKOPT`: `cqe.res` is `0`.
///     - `SOCKET_URING_OP_GETSOCKNAME`: the bound address is written into `optval` (truncated if too short) and
///       `cqe.res` is its full size; see `io_uring_prep_cmd_getsockname`.
///     - `SOCKET_URING_OP_TX_TIMESTAMP`: multishot (`IORING_CQE_F_MORE`), one completion per transmit timestamp of
///       a socket set up with `SO_TIMESTAMPING`; the ring needs `IORING_SETUP_CQE32` or `IORING_SETUP_CQE_MIXED`
///       (the timestamp is in `cqe.big_cqe`), `cqe.res` is the timestamp key (TCP: byte offset, UDP: packet count)
///       and the upper bits of `cqe.flags` the type; the last completion (no `IORING_CQE_F_MORE`) has `cqe.res` `0`
///       or raises the `OSError`.
///     - The kernel checks `len(optval)` for the option (an `int` option needs 4 bytes, else `OSError: EINVAL`).
///     - `optval` is raw bytes in the host's byte order: `int.to_bytes(4, sys.byteorder)` for an `int` option.
pub fn io_uring_prep_cmd_sock(
    sqe: *SQE,
    cmd_op: i32,
    fd: i32,
    level: i32,
    optname: i32,
    optval: py.OwnedWritableBuffer,
) py.Error!bool {
    const s = try h.prepSlot(sqe, &optval) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &optval, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_cmd_sock(
        s,
        cmd_op,
        fd,
        level,
        optname,
        optval.data.ptr,
        try py.narrow(c_int, optval.data.len, "`io_uring_prep_cmd_sock(optval)` length"),
    );
    return true;
}

/// Gets the local address of `fd` (`peer=0`, the default) or of its peer (`peer=1`) into `sockaddr`, written at the
/// completion (`getsockname` / `getpeername`); `sockaddr` is held until then.
///
/// Example
///     >>> sockaddr = Sockaddr()
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cmd_getsockname(sqe, sockfd, sockaddr)
///     True
///
/// Note
///     - Linux 6.19+.
///     - `cqe.res` is `0`; `sockaddr` gets the address and its length. A non-socket `fd` gives `OSError: ENOTSUP`
///       (not `ENOTSOCK` like the system calls).
pub fn io_uring_prep_cmd_getsockname(sqe: *SQE, fd: i32, sockaddr: *Sockaddr, peer: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_cmd_getsockname(
        s,
        fd,
        sockaddr.addrPtr(),
        &sockaddr._socklen,
        peer orelse 0,
    );
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(sockaddr)});
    return true;
}
