//! Liburing - message headers and epoll events
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const writableView = @import("class.zig").writableView;
const keep = @import("class.zig").keep;
const Ring = @import("ring.zig").Ring;

const linux = std.os.linux;
const py = setu.py;
const Object = setu.c.Object;
pub const MsghdrType = setu.Class(Msghdr, @embedFile("msghdr.zig"));
pub const CmsghdrType = setu.Class(Cmsghdr, @embedFile("msghdr.zig"));
pub const RecvmsgOutType = setu.Class(RecvmsgOut, @embedFile("msghdr.zig"));
pub const EpollEventType = setu.Class(EpollEvent, @embedFile("msghdr.zig"));

/// Message header for `io_uring_prep_sendmsg` / `io_uring_prep_recvmsg`: an address, a vector of buffers and
/// ancillary data.
///
/// Example
///     >>> msg = Msghdr(Sockaddr(AF_INET, "127.0.0.1", 9000), [b"hello"], flags=0)
///     >>> io_uring_prep_sendmsg(sqe, sockfd, msg)
///     True
///
///     # receive: the kernel fills `name`, the `iov` buffers and `control`
///     >>> name, buf, control = Sockaddr(), bytearray(1024), bytearray(64)
///     >>> msg = Msghdr(name, [buf], control)
///     >>> io_uring_prep_recvmsg(sqe, sockfd, msg)
///     True
///
///     # multishot receive with provided buffers: only the lengths are given
///     >>> msg = Msghdr(namelen=16, controllen=0)
///     >>> io_uring_prep_recvmsg_multishot(sqe, sockfd, msg)
///     True
///
/// Note
///     - A request holds `msg` (and so what it was made from) until its completion: io_uring reads it when
///     submitting and writes `namelen`, `controllen` and `flags` back when done.
///     - `iov` is a list of buffers (`bytes`, `bytearray`, `memoryview`, ...); `io_uring_prep_recvmsg*` needs
///     them and `control` writable (`TypeError`).
///     - `name`, `iov` and `control` are kept alive and locked (no resize) by the `Msghdr`; `namelen` /
///     `controllen` start as the size of the `Sockaddr` / `control` given and can be set (e.g. for a multishot
///     receive, where the kernel puts both, with the data, into a provided buffer).
pub const Msghdr = struct {
    _msghdr: c.msghdr = std.mem.zeroes(c.msghdr), // lives inside the Python object
    _name: ?*Object = null, // the `Sockaddr` `msg_name` points into
    _vec: ?*Ring.Vec = null, // the `iov` buffers `msg_iov` points into
    _control: ?setu.c.Buffer = null, // a locked view of the buffer `msg_control` points into
    _control_len: usize = 0, // the size of that buffer
    _readonly: bool = false, // `iov` or `control` is read-only: no `recvmsg` with it

    const Self = @This();

    /// All arguments are optional; `name` must be a `Sockaddr`, `iov` a list of buffers, `control` a buffer.
    ///
    /// Type
    ///     name:       Sockaddr | None
    ///     iov:        list[Buffer] | None
    ///     control:    Buffer | None
    ///     flags:      int | None
    ///     namelen:    int | None
    ///     controllen: int | None
    pub fn __new__(
        self: *Self,
        name: ?*Object,
        iov: ?py.Sequence(*Object),
        control: ?*Object,
        flags: ?i32,
        namelen: ?u32,
        controllen: ?usize,
    ) py.Error!void {
        if (name) |o| {
            const SockaddrType = @import("socket.zig").SockaddrType;
            if (!SockaddrType.check(o)) return py.raiseTypeError("`Msghdr(name)` must be a `Sockaddr`", .{});
            const sock = SockaddrType.data(o);
            self._msghdr.msg_name = sock.addrPtr();
            self._msghdr.msg_namelen = sock._socklen;
            self._name = keep(o);
        }
        if (iov) |list| {
            const vec = try Ring.Vec.fromObjects(list.items, "Msghdr(iov)");
            self._msghdr.msg_iov = vec.iov.ptr;
            self._msghdr.msg_iovlen = vec.iov.len;
            self._vec = vec;
            self._readonly = vec.readonly;
        }
        if (control) |o| {
            var view: setu.c.Buffer = undefined;
            const writable = try writableView(o, &view);
            const len: usize = @intCast(view.len); // cast: a size
            self._msghdr.msg_control = view.buf;
            self._msghdr.msg_controllen = len;
            self._control_len = len;
            self._control = view;
            self._readonly = self._readonly or !writable;
        }
        if (flags) |f| self._msghdr.msg_flags = f;
        if (namelen) |n| self._msghdr.msg_namelen = n;
        if (controllen) |n| {
            if (self._control != null and n > self._control_len)
                return py.raiseValueError("`Msghdr(controllen)` is longer than `control`", .{});
            self._msghdr.msg_controllen = n;
        }
    }

    /// The `msg_flags`: set by the kernel at a receive's completion (`MSG_TRUNC`: the data did not fit the `iov`
    /// buffers, `MSG_CTRUNC`: the ancillary data did not fit `control`, `MSG_EOR`, `MSG_OOB`). A send's flags
    /// are the prep's `flags` argument, not this field.
    pub fn get_flags(self: *const Self) i32 {
        return self._msghdr.msg_flags;
    }

    pub fn set_flags(self: *Self, value: i32) void {
        self._msghdr.msg_flags = value;
    }

    /// The size of `name`: the kernel writes back the real length of the address (`ValueError` when set longer
    /// than a `Sockaddr`).
    pub fn get_namelen(self: *const Self) u32 {
        return self._msghdr.msg_namelen;
    }

    pub fn set_namelen(self: *Self, value: u32) py.Error!void {
        if (self._name != null and value > @sizeOf(c.sockaddr_storage))
            return py.raiseValueError("`namelen` is longer than a `Sockaddr`", .{});
        self._msghdr.msg_namelen = value;
    }

    /// The size of `control`: the kernel writes back the length of the ancillary data (`ValueError` when set
    /// longer than `control`).
    pub fn get_controllen(self: *const Self) usize {
        return self._msghdr.msg_controllen;
    }

    pub fn set_controllen(self: *Self, value: usize) py.Error!void {
        if (self._control != null and value > self._control_len)
            return py.raiseValueError("`controllen` is longer than `control`", .{});
        self._msghdr.msg_controllen = value;
    }

    /// The number of `iov` buffers.
    pub fn get_iovlen(self: *const Self) usize {
        return self._msghdr.msg_iovlen;
    }

    /// GC: the `iov` buffers and `control`, so a cycle through one can be collected. No `__clear__`: a request
    /// in flight may hold the `Msghdr` (the kernel writes into its buffers), so the cycle breaks elsewhere (the
    /// buffer's `__dict__`, or the `Ring`, which drains first).
    pub fn __traverse__(self: *const Self, v: *setu.Visit) setu.Visit.Error!void {
        if (self._vec) |vec| try vec.traverse(v);
        if (self._control) |view| try v.add(view.obj);
    }

    pub fn __del__(self: *Self) void {
        if (self._vec) |v| v.destroy();
        if (self._control) |*view| setu.c.PyBuffer_Release(view);
    }

    /// `TypeError` when `iov` or `control` is read-only: a receive would write into it.
    pub fn checkWritable(self: *const Self, comptime what: []const u8) py.Error!void {
        if (self._readonly) return py.raiseTypeError(
            "`" ++ what ++ "(msg)` - `msg`'s `iov` / `control` must be writable (not `bytes`)",
            .{},
        );
    }
};

/// One control message (`struct cmsghdr`) of a received `Msghdr`, from `io_uring_recvmsg_cmsg_firsthdr` /
/// `io_uring_recvmsg_cmsg_nexthdr`.
///
/// Example
///     # `out = io_uring_recvmsg_validate(buf, msg)` of a message that came with one `SCM_RIGHTS` fd
///     >>> cmsg = io_uring_recvmsg_cmsg_firsthdr(out, msg)
///     >>> while cmsg:
///     ...     cmsg.level, cmsg.type, cmsg.data
///     ...     cmsg = io_uring_recvmsg_cmsg_nexthdr(out, msg, cmsg)
///     ...
///     (1, 1, b'\x07\x00\x00\x00')
pub const Cmsghdr = struct {
    _cmsghdr: ?*c.cmsghdr = null,
    _owner: ?*Object = null, // the `RecvmsgOut` (and so the buffer) `_cmsghdr` points into

    pub const instantiable = false;

    const Self = @This();

    /// The protocol level (`cmsg_level`, e.g. `SOL_SOCKET`).
    pub fn get_level(self: *const Self) i32 {
        return self._cmsghdr.?.cmsg_level;
    }

    /// The protocol specific type (`cmsg_type`).
    pub fn get_type(self: *const Self) i32 {
        return self._cmsghdr.?.cmsg_type;
    }

    /// `cmsg_len`: the header and the data.
    pub fn get_len(self: *const Self) usize {
        return self._cmsghdr.?.cmsg_len;
    }

    /// The data after the header (a copy).
    pub fn get_data(self: *const Self) py.Bytes {
        const hdr = self._cmsghdr.?;
        const header: usize = @sizeOf(c.cmsghdr); // CMSG_LEN(0): the header is already aligned
        const len = if (hdr.cmsg_len > header) hdr.cmsg_len - header else 0;
        const base: [*]const u8 = @ptrCast(hdr);
        return .{ .data = (base + header)[0..len] };
    }

    /// `True` while it points at a control message.
    pub fn __bool__(self: *const Self) bool {
        return self._cmsghdr != null;
    }
};

/// The result of `io_uring_recvmsg_validate`: the header the kernel put in front of a message received with
/// `io_uring_prep_recvmsg_multishot` into a provided buffer: `[header][name][control][payload]`. The header is
/// 16 bytes (four `u32`), then `msg.namelen` bytes of address and `msg.controllen` bytes of control data (the
/// sizes given in the `Msghdr`, whatever the message had), then the payload; `io_uring_recvmsg_name`,
/// `io_uring_recvmsg_cmsg_firsthdr` / `_nexthdr` and `io_uring_recvmsg_payload` find each part.
///
/// Example
///     # `buf`: the provided buffer a multishot receive (`msg = Msghdr(namelen=16, controllen=0)`) filled
///     >>> out = io_uring_recvmsg_validate(buf, msg)
///     >>> out.namelen, out.controllen, out.payloadlen, out.flags
///     (16, 0, 5, 0)
///     >>> io_uring_recvmsg_payload(out, msg)
///     b'hello'
pub const RecvmsgOut = struct {
    _recvmsg_out: ?*c.io_uring_recvmsg_out = null,
    _len: usize = 0, // the size of the buffer it points into
    _view: ?py.WritableBuffer = null, // locks the buffer (can not be resized) while this lives

    pub const instantiable = false;

    const Self = @This();

    /// The length of the sender's address, as `recvmsg` would report it in `msg_namelen` (the buffer holds at
    /// most `msg.namelen` bytes of it).
    pub fn get_namelen(self: *const Self) u32 {
        return self._recvmsg_out.?.namelen;
    }

    /// The length of the control (ancillary) data, as `recvmsg` would report it in `msg_controllen` (at most
    /// `msg.controllen` bytes are in the buffer).
    pub fn get_controllen(self: *const Self) u32 {
        return self._recvmsg_out.?.controllen;
    }

    /// The length of the message data, as `recvmsg` would return it: it can be more than fit in the buffer
    /// (`flags` then has `MSG_TRUNC`); `io_uring_recvmsg_payload_length` is what is really there.
    pub fn get_payloadlen(self: *const Self) u32 {
        return self._recvmsg_out.?.payloadlen;
    }

    /// The `msg_flags` of the received message (`MSG_TRUNC`, `MSG_CTRUNC`, `MSG_EOR`, `MSG_OOB`), as `recvmsg`
    /// would set them.
    pub fn get_flags(self: *const Self) u32 {
        return self._recvmsg_out.?.flags;
    }

    pub fn __del__(self: *Self) void {
        if (self._view) |v| v.deinit();
    }
};

/// Event for `io_uring_prep_epoll_ctl` (one, the events and the user data to get back) and
/// `io_uring_prep_epoll_wait` (`EpollEvent(no=n)`: room for `n` events, read with `events[i]`).
///
/// Example
///     >>> EPOLL_CTL_ADD = 1  # <sys/epoll.h>
///     >>> ev = EpollEvent(events=select.EPOLLIN, data=123)
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_epoll_ctl(sqe, epfd, fd, EPOLL_CTL_ADD, ev)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///
///     >>> ready = EpollEvent(no=8)
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_epoll_wait(sqe, epfd, ready, 8)
///     True
///     >>> io_uring_submit_and_wait(ring, 2)
///     1
///     >>> ready[0].events, ready[0].data  # after the completion: `fd` is readable
///     (1, 123)
pub const EpollEvent = struct {
    _events: ?[*]linux.epoll_event = null,
    _len: usize = 0,
    _index: usize = 0, // the event `events` / `data` are about
    _owner: ?*Object = null, // the `EpollEvent` that owns the array, for `events[i]`
    _owns: bool = false, // frees the array (not a `events[i]` view); `_owner` is already dropped when `__del__` runs

    const Self = @This();

    /// `EpollEvent(events=..., data=...)` is one event, `EpollEvent(no=n)` is room for `n`.
    pub fn __new__(self: *Self, no: ?u32, events: ?u32, data: ?u64) py.Error!void {
        const count: usize = no orelse 1;
        if (count == 0) return py.raiseValueError("`EpollEvent(no)` must be at least 1", .{});
        if (no != null and (events != null or data != null))
            return py.raiseValueError("`EpollEvent`: give `no`, or `events` and `data`", .{});
        const all = std.heap.c_allocator.alloc(linux.epoll_event, count) catch return e.raiseMemoryError(
            "Out of Memory!",
        );
        @memset(all, std.mem.zeroes(linux.epoll_event));
        all[0].events = events orelse 0;
        all[0].data.u64 = data orelse 0;
        self._events = all.ptr;
        self._len = count;
        self._owns = true;
    }

    pub fn __del__(self: *Self) void {
        if (self._owns) if (self._events) |ptr| std.heap.c_allocator.free(ptr[0..self._len]);
    }

    /// The number of events (`1` for an `events[i]` item).
    pub fn __len__(self: *const Self) usize {
        return if (self._owner == null) self._len else 1;
    }

    /// The event `index` as an `EpollEvent` sharing the array (`IndexError` out of range, or on an item itself).
    pub fn __getitem__(self: *Self, index: isize) py.Error!*Object {
        if (self._owner != null or index < 0 or index >= self._len) return py.raiseIndexError(
            "Index out of range",
            .{},
        );
        const root = EpollEventType.object(self);
        return EpollEventType.new(.{
            ._events = self._events,
            ._len = self._len,
            ._index = @intCast(index), // cast: checked
            ._owner = keep(root),
        });
    }

    /// The event mask (`EPOLLIN`, ...) of the event.
    pub fn get_events(self: *const Self) u32 {
        return self._events.?[self._index].events;
    }

    pub fn set_events(self: *Self, value: u32) void {
        self._events.?[self._index].events = value;
    }

    /// The user data of the event.
    pub fn get_data(self: *const Self) u64 {
        return self._events.?[self._index].data.u64;
    }

    pub fn set_data(self: *Self, value: u64) void {
        self._events.?[self._index].data.u64 = value;
    }
};
