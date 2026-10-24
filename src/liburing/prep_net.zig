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

pub fn io_uring_prep_recvmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    try msg.checkWritable("io_uring_prep_recvmsg");
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

pub fn io_uring_prep_recvmsg_multishot(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    try msg.checkWritable("io_uring_prep_recvmsg_multishot");
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg_multishot(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

pub fn io_uring_prep_sendmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    c.io_uring_prep_sendmsg(s, fd, &msg._msghdr, _flags);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Example
///     >>> addr = Sockaddr(AF_INET, "127.0.0.1", 12345)
///     ... ...
///     >>> io_uring_prep_accept(sqe, fd, addr)
///     True
pub fn io_uring_prep_accept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // written at the completion
    try h.holdUntilCompletion(sqe, null, if (addr) |a| &.{SockaddrType.object(a)} else &.{});
    const _flags = flags orelse 0;
    c.io_uring_prep_accept(s, fd, if (addr) |a| a.addrPtr() else null, if (addr) |a| &a._socklen else null, _flags);
    return true;
}

/// Note
///     - Function argument `file_index` position has changed for C origin for better usability.
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
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

pub fn io_uring_prep_connect(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_connect(s, fd, addr.addrPtr(), addr._socklen);
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(addr)});
    return true;
}

pub fn io_uring_prep_bind(sqe: *SQE, fd: i32, addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_bind(s, fd, addr.addrPtr(), addr._socklen);
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(addr)});
    return true;
}

pub fn io_uring_prep_listen(sqe: *SQE, fd: i32, backlog: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_listen(s, fd, backlog);
    return true;
}

pub fn io_uring_prep_send(sqe: *SQE, sockfd: i32, buf: py.OwnedBuffer, flags: ?i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _flags = flags orelse 0;
    c.io_uring_prep_send(s, sockfd, buf.data.ptr, buf.data.len, _flags);
    return true;
}

pub fn io_uring_prep_send_bundle(sqe: *SQE, sockfd: i32, len: ?usize, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_send_bundle(s, sockfd, len orelse 0, flags orelse 0);
    return true;
}

pub fn io_uring_prep_send_set_addr(sqe: *SQE, dest_addr: *Sockaddr) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_send_set_addr(s, dest_addr.addrPtr(), @intCast(dest_addr._socklen));
    try h.holdUntilCompletion(sqe, null, &.{SockaddrType.object(dest_addr)});
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
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

pub fn io_uring_prep_send_zc(sqe: *SQE, sockfd: i32, buf: py.OwnedBuffer, flags: ?i32, zc_flags: ?u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_send_zc(s, sockfd, buf.data.ptr, buf.data.len, flags orelse 0, zc_flags orelse 0);
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
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

pub fn io_uring_prep_sendmsg_zc(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_sendmsg_zc(s, fd, &msg._msghdr, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///
/// Warning
///     - Coded but not tested!!!
pub fn io_uring_prep_sendmsg_zc_fixed(sqe: *SQE, fd: i32, msg: *Msghdr, buf_index: u32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_sendmsg_zc_fixed(s, fd, &msg._msghdr, flags orelse 0, buf_index);
    try h.holdUntilCompletion(sqe, null, &.{MsghdrType.object(msg)});
    return true;
}

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
///     - The kernel uses the buffers until they are consumed or removed, so the ring holds `addr` (locked: no
///       resize) until its exit; giving a part of an area it already holds again takes nothing more.
///     - `sqe` must come from `io_uring_get_sqe` or be an `Sqe(ring)` (`TypeError` for an `Sqe` template: no ring
///       to hold `addr`).
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

pub fn io_uring_prep_remove_buffers(sqe: *SQE, nr: i32, bgid: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_remove_buffers(s, nr, bgid);
    return true;
}

pub fn io_uring_prep_shutdown(sqe: *SQE, fd: i32, how: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_shutdown(s, fd, how);
    return true;
}

pub fn io_uring_prep_socket(sqe: *SQE, domain: i32, @"type": i32, protocol: ?i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    c.io_uring_prep_socket(s, domain, @"type", _protocol, _flags);
    return true;
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
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_socket_direct(s, domain, Type, _protocol, _file_index, _flags);
    return true;
}

/// Example
///     >>> buf = bytearray((1).to_bytes(4, "little"))
///     >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_KEEPALIVE, buf)
///     True
///     # or
///     >>> buf = bytearray(b'eth1')
///     >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, ..., buf)
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
///     - `cqe.res` will return `len()` of populating data(`buf`).
///     - min length of `buf` must be `4`.
///     - watch out for "big" or "little" endian, keep it same or it will switch to systems default.
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

/// Example
///     >>> sockaddr = Sockaddr()
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_cmd_getsockname(sqe, sockfd, sockaddr)
///     True
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
