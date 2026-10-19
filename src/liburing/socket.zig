//! Liburing - Extra socket related class, functions, ...
const c = @import("c.zig").c;
const h = @import("helper.zig");
const setu = @import("setu");
const std = @import("std");
const SQE = @import("class.zig").SQE;

const py = setu.py;
const Object = setu.c.Object;
const net = std.Io.net;

pub const SockaddrType = setu.Class(Sockaddr, @embedFile("socket.zig"));

/// libc: an interface name (`eth0`) to its index, `0` if unknown.
extern fn if_nametoindex(name: [*:0]const u8) c_uint;

///Generic Socket Address.
///
///Example
///    >>> addr = Sockaddr(AF_UNIX, './path')
///    >>> addr = Sockaddr(AF_INET, '0.0.0.0', 12345)
///    >>> addr = Sockaddr(AF_INET6, '::1', 12345)
///    >>> bind(sockfd, addr)
///
///Note
///    - IPv6 `scope_id` can be added like so `"ff01::fb%123"`
///    - `Sockaddr()` is low level setup, letting you serve/connect directly using path/ip.
///    If you need higher level features you can use `getaddrinfo()` this lets you connect
///    using domain names, ...
pub const Sockaddr = struct {
    _family: c.sa_family_t = AF_UNSPEC,
    _socklen: c.socklen_t = @sizeOf(c.sockaddr_storage),
    _storage: c.sockaddr_storage = std.mem.zeroes(c.sockaddr_storage), // any family's address fits

    const Self = @This();

    pub fn __new__(self: *Self, family: ?c.sa_family_t, addr: ?*Object, port: ?usize) py.Error!void {
        const _family: c.sa_family_t = family orelse AF_UNSPEC;
        var _port: u16 = 0;
        if (port) |p| {
            if (p > 65_535) return py.raiseOverflowError("`Sockaddr` - `port` out of range, max `65_535`", .{});
            _port = @intCast(p); // cast: checked above
        }

        switch (_family) {
            AF_UNIX => {
                const _addr = try h.toPath(addr orelse return py.raiseValueError("`Sockaddr` - `addr` not provided.", .{}));
                defer _addr.deinit();
                if (_addr.path.len > 108) return py.raiseValueError("`Sockaddr` - length of `addr` can not be `> 108`", .{});
                if (_addr.path.len == 0) return py.raiseValueError("`Sockaddr` - `addr` can not be empty.", .{});

                const sock = self.as(c.sockaddr_un);
                sock.sun_family = _family;
                @memcpy(sock.sun_path[0.._addr.path.len], _addr.path);
                self._socklen = @sizeOf(c.sockaddr_un);
            },
            AF_INET => {
                const _addr = try ipText(addr);
                const ip = net.Ip4Address.parse(_addr, _port) catch {
                    return py.raiseValueError("`Sockaddr` - `addr` or `port` not valid IPv4", .{});
                };
                const sock = self.as(c.sockaddr_in);
                sock.sin_family = _family;
                sock.sin_port = std.mem.nativeToBig(u16, ip.port);
                sock.sin_addr.s_addr = @bitCast(ip.bytes); // network order, as stored
                self._socklen = @sizeOf(c.sockaddr_in);
            },
            AF_INET6 => {
                const _addr = try ipText(addr);
                // `std.Io.net` leaves a `%scope` unresolved, so it is read here: a number or an interface name.
                const pct = std.mem.indexOfScalar(u8, _addr, '%');
                const ip = net.Ip6Address.parse(_addr[0 .. pct orelse _addr.len], _port) catch {
                    return py.raiseValueError("`Sockaddr` - `addr` or `port` not valid IPv6", .{});
                };
                const scope_id: u32 = if (pct) |i| try scopeId(_addr[i + 1 ..]) else 0;
                const sock = self.as(c.sockaddr_in6);
                sock.sin6_family = _family;
                sock.sin6_port = std.mem.nativeToBig(u16, ip.port);
                sock.sin6_addr.__in6_u.__u6_addr8 = ip.bytes;
                sock.sin6_scope_id = scope_id;
                sock.sin6_flowinfo = ip.flow;
                self._socklen = @sizeOf(c.sockaddr_in6);
            },
            AF_UNSPEC => {},
            else => return py.raiseNotImplementedError("`Sockaddr` - `family={d}` not supported!", .{_family}),
        }
        self._family = _family;
    }

    /// The address as `*T` (`sockaddr_un`, `sockaddr_in`, ...), inside `_storage`.
    fn as(self: *Self, comptime T: type) *T {
        return @ptrCast(&self._storage);
    }

    /// The `sockaddr *` to hand to C (Zig side).
    pub fn addrPtr(self: *Self) *c.sockaddr {
        return @ptrCast(&self._storage);
    }

    /// The family: the one given, or for `Sockaddr()` the one the kernel filled in.
    fn currentFamily(self: *const Self) c.sa_family_t {
        return if (self._family == AF_UNSPEC) self._storage.ss_family else self._family;
    }

    ///>>> sock.path
    ///"./path"
    pub fn get_path(self: *Self) py.Error![]const u8 {
        const _family = self.currentFamily();
        if (_family == AF_UNIX) return std.mem.sliceTo(&self.as(c.sockaddr_un).sun_path, 0);
        return py.raiseNotImplementedError("`Sockaddr` - `path` is not implemented for {}", .{_family});
    }

    ///>>> sock.ip
    ///"1.2.3.4"
    pub fn get_ip(self: *Self) py.Error!*Object {
        const _family = self.currentFamily();
        switch (_family) {
            AF_INET => {
                const bytes: *const [4]u8 = @ptrCast(&self.as(c.sockaddr_in).sin_addr.s_addr);
                var buf: [16]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "{d}.{d}.{d}.{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3] }) catch unreachable; // fits
                return py.new(text);
            },
            // TODO: AF_INET6
            else => return py.raiseNotImplementedError("`Sockaddr` - `ip` is not implemented for {}", .{_family}),
        }
    }

    ///>>> sock.port
    ///1234
    pub fn get_port(self: *Self) py.Error!u16 {
        const _family = self.currentFamily();
        switch (_family) {
            AF_INET => return std.mem.bigToNative(u16, self.as(c.sockaddr_in).sin_port),
            AF_INET6 => return std.mem.bigToNative(u16, self.as(c.sockaddr_in6).sin6_port),
            else => return py.raiseNotImplementedError("`Sockaddr` - `port` does not support family: {}", .{_family}),
        }
    }

    ///>>> sock.family
    ///1
    pub fn get_family(self: *const Self) i32 {
        return self.currentFamily();
    }
};

/// The text of an IP `addr` argument (a `str`, borrowed from it): `ValueError` if missing or empty.
fn ipText(addr: ?*Object) py.Error![]const u8 {
    const a = addr orelse return py.raiseValueError("`Sockaddr` - `addr` not provided.", .{});
    const text = try py.fromPython([]const u8, a);
    if (text.len == 0) return py.raiseValueError("`Sockaddr` - `addr` can not be empty.", .{});
    return text;
}

/// An IPv6 `%scope`: an interface index, or an interface name.
fn scopeId(text: []const u8) py.Error!u32 {
    if (std.fmt.parseInt(u32, text, 10)) |n| return n else |_| {}
    var name: [16:0]u8 = @splat(0); // IF_NAMESIZE
    if (text.len == 0 or text.len >= name.len) return py.raiseValueError("`Sockaddr` - invalid IPv6 scope `{s}`", .{text});
    @memcpy(name[0..text.len], text);
    const index = if_nametoindex(&name);
    if (index == 0) return py.raiseValueError("`Sockaddr` - unknown IPv6 scope `{s}`", .{text});
    return index;
}

///Example
///    >>> val = (1).to_bytes(4, "big")
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> setsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, val)
///
///    >>> val = (0).to_bytes(4, "big")
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> setsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, val)
///
///    >>> val = b"eth1"
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> setsockopt(sqe, sockfd, SOL_SOCKET, SO_BINDTODEVICE, val)
///
///Note
///    - remember to hold on to `val` reference till `sqe` has been submitted.
///    - min length of `val` must be `4`.
///    - watch out for "big" or "little" endian, keep it same or it will switch to systems default.
pub fn setsockopt(sqe: *SQE, sockfd: i32, level: i32, optname: i32, optval: py.Buffer) py.Error!void {
    c.io_uring_prep_cmd_sock(
        try sqe.sqePtr(),
        c.SOCKET_URING_OP_SETSOCKOPT,
        sockfd,
        level,
        optname,
        @constCast(optval.data.ptr),
        try py.narrow(c_int, optval.data.len, "`setsockopt(optval)` length"), // cast: a buffer the size of a socket option
    );
}

///Example
///    # assuming `SO_KEEPALIVE` was previous set to `1`
///    >>> buf = bytearray(4)
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> getsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, buf)
///    ... # after submit and wait
///    >>> int.from_bytes(buf)
///    1
///
///Note
///    - remember to hold on to `buf` as new result will be populated into it.
///    - `cqe.res` will return `len()` of populating data(`buf`).
///    - min length of `buf` must be `4`.
///    - watch out for "big" or "little" endian, keep it same or it will switch to systems default.
pub fn getsockopt(sqe: *SQE, sockfd: i32, level: i32, optname: i32, optval: py.WritableBuffer) py.Error!void {
    c.io_uring_prep_cmd_sock(
        try sqe.sqePtr(),
        c.SOCKET_URING_OP_GETSOCKOPT,
        sockfd,
        level,
        optname,
        optval.data.ptr,
        try py.narrow(c_int, optval.data.len, "`getsockopt(optval)` length"), // cast: a buffer the size of a socket option
    );
}

///Example
///    >>> sockaddr = Sockaddr()
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> getsockname(sqe, sockfd, sockaddr)
///
///Note
///    - This function is an alias of `io_uring_prep_cmd_getsockname`
pub fn getsockname(sqe: *SQE, fd: i32, sockaddr: *Sockaddr, peer: ?i32) py.Error!void {
    c.io_uring_prep_cmd_getsockname(
        try sqe.sqePtr(),
        fd,
        sockaddr.addrPtr(),
        &sockaddr._socklen,
        peer orelse 0,
    );
}

// Socket Family
const AF_UNSPEC = c.AF_UNSPEC; // locally used.
pub const AF_UNIX = c.AF_UNIX;
pub const AF_INET = c.AF_INET;
pub const AF_INET6 = c.AF_INET6;

// Socket Type
pub const SOCK_STREAM = c.SOCK_STREAM;
pub const SOCK_DGRAM = c.SOCK_DGRAM;
pub const SOCK_RAW = c.SOCK_RAW;
pub const SOCK_RDM = c.SOCK_RDM;
pub const SOCK_SEQPACKET = c.SOCK_SEQPACKET;
pub const SOCK_DCCP = c.SOCK_DCCP;
pub const SOCK_PACKET = c.SOCK_PACKET;
pub const SOCK_CLOEXEC = c.SOCK_CLOEXEC;
pub const SOCK_NONBLOCK = c.SOCK_NONBLOCK;

// Shutdown How
pub const SHUT_RD = c.SHUT_RD;
pub const SHUT_WR = c.SHUT_WR;
pub const SHUT_RDWR = c.SHUT_RDWR;

// Socket Proto
pub const IPPROTO_IP = c.IPPROTO_IP;
pub const IPPROTO_ICMP = c.IPPROTO_ICMP;
pub const IPPROTO_IGMP = c.IPPROTO_IGMP;
pub const IPPROTO_IPIP = c.IPPROTO_IPIP;
pub const IPPROTO_TCP = c.IPPROTO_TCP;
pub const IPPROTO_EGP = c.IPPROTO_EGP;
pub const IPPROTO_PUP = c.IPPROTO_PUP;
pub const IPPROTO_UDP = c.IPPROTO_UDP;
pub const IPPROTO_IDP = c.IPPROTO_IDP;
pub const IPPROTO_TP = c.IPPROTO_TP;
pub const IPPROTO_DCCP = c.IPPROTO_DCCP;
pub const IPPROTO_IPV6 = c.IPPROTO_IPV6;
pub const IPPROTO_RSVP = c.IPPROTO_RSVP;
pub const IPPROTO_GRE = c.IPPROTO_GRE;
pub const IPPROTO_ESP = c.IPPROTO_ESP;
pub const IPPROTO_AH = c.IPPROTO_AH;
pub const IPPROTO_MTP = c.IPPROTO_MTP;
pub const IPPROTO_BEETPH = c.IPPROTO_BEETPH;
pub const IPPROTO_ENCAP = c.IPPROTO_ENCAP;
pub const IPPROTO_PIM = c.IPPROTO_PIM;
pub const IPPROTO_COMP = c.IPPROTO_COMP;
// # note: not supported
// pub const IPPROTO_L2TP = IPPROTO_L2TP;
pub const IPPROTO_SCTP = c.IPPROTO_SCTP;
pub const IPPROTO_UDPLITE = c.IPPROTO_UDPLITE;
pub const IPPROTO_MPLS = c.IPPROTO_MPLS;
pub const IPPROTO_ETHERNET = c.IPPROTO_ETHERNET;
pub const IPPROTO_RAW = c.IPPROTO_RAW;
pub const IPPROTO_MPTCP = c.IPPROTO_MPTCP;

// Setsockopt & Getsockopt start >>>
pub const SOL_SOCKET = c.SOL_SOCKET;
pub const SO_DEBUG = c.SO_DEBUG;
pub const SO_REUSEADDR = c.SO_REUSEADDR;
pub const SO_TYPE = c.SO_TYPE;
pub const SO_ERROR = c.SO_ERROR;
pub const SO_DONTROUTE = c.SO_DONTROUTE;
pub const SO_BROADCAST = c.SO_BROADCAST;
pub const SO_SNDBUF = c.SO_SNDBUF;
pub const SO_RCVBUF = c.SO_RCVBUF;
pub const SO_SNDBUFFORCE = c.SO_SNDBUFFORCE;
pub const SO_RCVBUFFORCE = c.SO_RCVBUFFORCE;
pub const SO_KEEPALIVE = c.SO_KEEPALIVE;
pub const SO_OOBINLINE = c.SO_OOBINLINE;
pub const SO_NO_CHECK = c.SO_NO_CHECK;
pub const SO_PRIORITY = c.SO_PRIORITY;
pub const SO_LINGER = c.SO_LINGER;
pub const SO_BSDCOMPAT = c.SO_BSDCOMPAT;
pub const SO_REUSEPORT = c.SO_REUSEPORT;
pub const SO_PASSCRED = c.SO_PASSCRED;
pub const SO_PEERCRED = c.SO_PEERCRED;
pub const SO_RCVLOWAT = c.SO_RCVLOWAT;
pub const SO_SNDLOWAT = c.SO_SNDLOWAT;
pub const SO_BINDTODEVICE = c.SO_BINDTODEVICE;

// Socket Filtering
pub const SO_ATTACH_FILTER = c.SO_ATTACH_FILTER;
pub const SO_DETACH_FILTER = c.SO_DETACH_FILTER;
pub const SO_GET_FILTER = c.SO_GET_FILTER;
pub const SO_PEERNAME = c.SO_PEERNAME;
pub const SO_ACCEPTCONN = c.SO_ACCEPTCONN;
pub const SO_PEERSEC = c.SO_PEERSEC;
pub const SO_PASSSEC = c.SO_PASSSEC;
pub const SO_MARK = c.SO_MARK;
pub const SO_PROTOCOL = c.SO_PROTOCOL;
pub const SO_DOMAIN = c.SO_DOMAIN;
pub const SO_RXQ_OVFL = c.SO_RXQ_OVFL;
pub const SO_WIFI_STATUS = c.SO_WIFI_STATUS;
pub const SCM_WIFI_STATUS = c.SCM_WIFI_STATUS;
pub const SO_PEEK_OFF = c.SO_PEEK_OFF;

// not tested
pub const SO_TIMESTAMP = c.SO_TIMESTAMP;
pub const SO_TIMESTAMPNS = c.SO_TIMESTAMPNS;
pub const SO_TIMESTAMPING = c.SO_TIMESTAMPING;
pub const SO_RCVTIMEO = c.SO_RCVTIMEO;
pub const SO_SNDTIMEO = c.SO_SNDTIMEO;
