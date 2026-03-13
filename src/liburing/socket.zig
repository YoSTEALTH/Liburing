//! Liburing - Extra socket related class, functions, ...
const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");
const SQE = @import("class.zig").SQE;

///Generic Socket Address.
///
///Example
///    >>> addr = Sockaddr(AF_UNIX, b'./path')
///    >>> addr = Sockaddr(AF_INET, b'0.0.0.0', 12345)
///    >>> addr = Sockaddr(AF_INET6, b'::1', 12345)
///    >>> bind(sockfd, addr)
///
///Note
///    - IPv6 `scope_id` can be added like so `"ff01::fb%123"`
///    - `Sockaddr()` is low level setup, letting you serve/connect directly using path/ip.
///    If you need higher level features you can use `getaddrinfo()` this lets you connect
///    using domain names, ...
pub const Sockaddr = extern struct {
    _family: c.sa_family_t,
    _socklen: c.socklen_t,
    _sockaddr: usize, // *c.sockaddr pointer as int

    const Self = @This();

    pub fn __new__(family: ?c.sa_family_t, addr: ?[]const u8, port: ?usize) ?Self {
        const _family: c.sa_family_t = family orelse 0;
        var _port: u16 = 0;
        if (port) |p| {
            if (p > 65_535) return oz.raiseOverflowError("`Sockaddr` - `port` out of range, max `65_535`");
            _port = @intCast(p);
        }

        var socklen: c.socklen_t = undefined;
        var sockaddr: usize = undefined;

        switch (_family) {
            AF_UNIX => {
                const _addr = addr orelse return oz.raiseValueError("`Sockaddr` - `addr` not provided.");
                if (_addr.len > 108) return oz.raiseValueError("`Sockaddr` - length of `addr` can not be `> 108`");
                if (_addr.len == 0) return oz.raiseValueError("`Sockaddr` - `addr` can not be empty.");

                socklen = @sizeOf(c.sockaddr_un);
                const _sock: *c.sockaddr_un = std.heap.c_allocator.create(c.sockaddr_un) catch {
                    return oz.raiseMemoryError("`Sockaddr` - Out of Memory!");
                };
                _sock.sun_family = _family;
                @memset(&_sock.sun_path, 0);
                @memcpy(_sock.sun_path[0.._addr.len], _addr);
                sockaddr = @intFromPtr(_sock);
            },
            AF_INET => {
                const _addr = addr orelse return oz.raiseValueError("`Sockaddr` - `addr` not provided.");
                if (_addr.len == 0) return oz.raiseValueError("`Sockaddr` - `addr` can not be empty.");

                socklen = @sizeOf(c.sockaddr_in);
                const _sock: *c.sockaddr_in = std.heap.c_allocator.create(c.sockaddr_in) catch {
                    return oz.raiseMemoryError("`Sockaddr` - Out of Memory!");
                };
                const _result = std.net.Ip4Address.parse(_addr, _port) catch {
                    return oz.raiseValueError("`Sockaddr` - `addr` or `port` not valid IPv4");
                };
                _sock.sin_family = _family;
                _sock.sin_port = _result.sa.port;
                _sock.sin_addr.s_addr = _result.sa.addr;
                sockaddr = @intFromPtr(_sock);
            },
            AF_INET6 => {
                const _addr = addr orelse return oz.raiseValueError("`Sockaddr` - `addr` not provided.");
                if (_addr.len == 0) return oz.raiseValueError("`Sockaddr` - `addr` can not be empty.");

                socklen = @sizeOf(c.sockaddr_in6);
                const _sock: *c.sockaddr_in6 = std.heap.c_allocator.create(c.sockaddr_in6) catch {
                    return oz.raiseMemoryError("`Sockaddr` - Out of Memory!");
                };
                const _result = std.net.Ip6Address.parse(_addr, _port) catch {
                    return oz.raiseValueError("`Sockaddr` - `addr` or `port` not valid IPv6");
                };
                _sock.sin6_family = _family;
                _sock.sin6_port = _result.sa.port;
                _sock.sin6_addr.__in6_u.__u6_addr8 = _result.sa.addr;
                _sock.sin6_scope_id = _result.sa.scope_id;
                _sock.sin6_flowinfo = _result.sa.flowinfo;
                sockaddr = @intFromPtr(_sock);
            },
            AF_UNSPEC => {
                socklen = @sizeOf(c.sockaddr_storage);
                const _sock: *c.sockaddr_storage = std.heap.c_allocator.create(c.sockaddr_storage) catch {
                    return oz.raiseMemoryError("`Sockaddr` - Out of Memory!");
                };
                _sock.* = std.mem.zeroes(c.sockaddr_storage); // set default value to `0`
                sockaddr = @intFromPtr(_sock);
            },
            else => return oz.raiseNotImplementedError(oz.fmt("`Sockaddr` - `family={d}` not supported!", .{_family})),
        }
        return .{ ._sockaddr = sockaddr, ._socklen = socklen, ._family = _family };
    }

    pub fn __del__(self: *Self) void {
        switch (self._family) {
            AF_UNIX => {
                const ptr: *c.sockaddr_un = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            AF_INET => {
                const ptr: *c.sockaddr_in = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            AF_INET6 => {
                const ptr: *c.sockaddr_in6 = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            AF_UNSPEC => {
                const ptr: *c.sockaddr_storage = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            else => {},
        }
    }

    ///>>> sock.path
    ///"./path"
    pub fn get_path(self: *const Self) ?[*:0]const u8 {
        var _family: c.sa_family_t = undefined;

        if (self._family == AF_UNSPEC) {
            const ptr: *c.sockaddr_storage = @ptrFromInt(self._sockaddr);
            _family = ptr.ss_family;
        } else {
            _family = self._family;
        }

        if (_family == AF_UNIX) {
            const ptr: *c.sockaddr_un = @ptrFromInt(self._sockaddr);
            return @ptrCast(ptr.sun_path[0..]);
        }
        return oz.raiseNotImplementedError(oz.fmt("`Sockaddr` - `path` is not implemented for {}", .{_family}));
    }

    ///>>> sock.ip
    ///"1.2.3.4"
    pub fn get_ip(self: *const Self) ?[*:0]const u8 {
        var _family: c.sa_family_t = undefined;

        if (self._family == AF_UNSPEC) {
            const ptr: *c.sockaddr_storage = @ptrFromInt(self._sockaddr);
            _family = ptr.ss_family;
        } else {
            _family = self._family;
        }

        switch (_family) {
            AF_INET => {
                const ptr: *c.sockaddr_in = @ptrFromInt(self._sockaddr);
                const bytes: *const [4]u8 = @ptrCast(&ptr.sin_addr.s_addr);
                return oz.fmt("{d}.{d}.{d}.{d}", .{ bytes[0], bytes[1], bytes[2], bytes[3] });
            },
            // TODO:
            // AF_INET6 => {
            //     const ptr: *c.sockaddr_in6 = @ptrFromInt(self._sockaddr);
            //     // const addr: [16]u8 = ptr.sin6_addr.__in6_u.__u6_addr8;
            // },
            else => return oz.raiseNotImplementedError(oz.fmt("`Sockaddr` - `ip` is not implemented for {}", .{_family})),
        }
    }

    ///>>> sock.port
    ///1234
    pub fn get_port(self: *const Self) ?u16 {
        var _family: c.sa_family_t = undefined;

        if (self._family == AF_UNSPEC) {
            const ptr: *c.sockaddr_storage = @ptrFromInt(self._sockaddr);
            _family = ptr.ss_family;
        } else {
            _family = self._family;
        }

        switch (_family) {
            AF_INET => {
                const ptr: *c.sockaddr_in = @ptrFromInt(self._sockaddr);
                return std.mem.bigToNative(u16, ptr.sin_port);
            },
            AF_INET6 => {
                const ptr: *c.sockaddr_in6 = @ptrFromInt(self._sockaddr);
                return std.mem.bigToNative(u16, ptr.sin6_port);
            },
            else => return oz.raiseNotImplementedError(
                oz.fmt("`Sockaddr` - `port` does not support family: {}", .{_family}),
            ),
        }
    }

    ///>>> sock.family
    ///1
    pub fn get_family(self: *const Self) i32 {
        if (self._family == AF_UNSPEC) {
            const ptr: *c.sockaddr_storage = @ptrFromInt(self._sockaddr);
            return ptr.ss_family;
        } else return self._family;
    }
};

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
pub inline fn setsockopt(sqe: *SQE, sockfd: i32, level: i32, optname: i32, optval: oz.Bytes) void {
    c.io_uring_prep_cmd_sock(
        sqe._sqe,
        c.SOCKET_URING_OP_SETSOCKOPT,
        sockfd,
        level,
        optname,
        @constCast(optval.data.ptr),
        @intCast(optval.data.len),
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
pub inline fn getsockopt(sqe: *SQE, sockfd: i32, level: i32, optname: i32, optval: oz.ByteArray) void {
    c.io_uring_prep_cmd_sock(
        sqe._sqe,
        c.SOCKET_URING_OP_GETSOCKOPT,
        sockfd,
        level,
        optname,
        optval.data.ptr,
        @intCast(optval.data.len),
    );
}

///Example
///    >>> sockaddr = Sockaddr()
///    >>> sqe = io_uring_get_sqe(ring)
///    >>> getsockname(sqe, sockfd, sockaddr)
///
///Note
///    - This function is an alias of `io_uring_prep_cmd_getsockname`
pub inline fn getsockname(sqe: *SQE, fd: i32, sockaddr: *Sockaddr, peer: ?i32) void {
    c.io_uring_prep_cmd_getsockname(
        sqe._sqe,
        fd,
        @ptrFromInt(sockaddr._sockaddr),
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
