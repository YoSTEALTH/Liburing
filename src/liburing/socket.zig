//! Liburing - Extra socket related class, functions, ...
const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

const AF = std.os.linux.AF;

///Generic Socket Address.
///
///Example
///    >>> addr = Sockaddr(AF_UNIX, b'./path')
///    >>> addr = Sockaddr(AF_INET, b'0.0.0.0', 12345)
///    >>> addr = Sockaddr(AF_INET6, b'::1', 12345)
///    >>> bind(sockfd, addr)
///
///Note
///    - IPv6 `scope_id` can be added like so `b"ff01::fb%123"`
///    - `Sockaddr()` is low level setup, letting you serve/connect directly using path/ip.
///    If you need higher level features you can use `getaddrinfo()` this lets you connect
///    using domain names, ...
pub const Sockaddr = extern struct {
    _family: c.sa_family_t,
    _socklen: c.socklen_t,
    _sockaddr: usize, // *c.sockaddr pointer as int

    const Self = @This();

    pub fn __new__(family: c.sa_family_t, addr: []const u8, port: ?u16) ?Self {
        var socklen: c.socklen_t = undefined;
        var sockaddr: usize = undefined;

        if (addr.len == 0) return oz.raiseValueError("`sockaddr` - `addr` can not be empty!");

        switch (family) {
            AF.UNIX => {
                if (addr.len > 108) return oz.raiseValueError("`sockaddr` - length of `addr` can not be `> 108`");

                socklen = @sizeOf(c.sockaddr_un);
                const _sock: *c.sockaddr_un = std.heap.c_allocator.create(c.sockaddr_un) catch {
                    return oz.raiseMemoryError("`sockaddr()` - Out of Memory!");
                };
                _sock.sun_family = family;
                @memset(&_sock.sun_path, 0);
                @memcpy(_sock.sun_path[0..addr.len], addr);
                sockaddr = @intFromPtr(_sock);
            },
            AF.INET => {
                socklen = @sizeOf(c.sockaddr_in);
                const _sock: *c.sockaddr_in = std.heap.c_allocator.create(c.sockaddr_in) catch {
                    return oz.raiseMemoryError("`sockaddr()` - Out of Memory!");
                };

                const _result = std.net.Ip4Address.parse(addr, port orelse 0) catch {
                    return oz.raiseValueError("`sockaddr()` - `addr` or `port` not valid IPv4");
                };
                _sock.sin_family = family;
                _sock.sin_port = _result.sa.port;
                _sock.sin_addr.s_addr = _result.sa.addr;
                sockaddr = @intFromPtr(_sock);
            },
            AF.INET6 => {
                socklen = @sizeOf(c.sockaddr_in6);
                const _sock: *c.sockaddr_in6 = std.heap.c_allocator.create(c.sockaddr_in6) catch {
                    return oz.raiseMemoryError("`sockaddr()` - Out of Memory!");
                };

                const _result = std.net.Ip6Address.parse(addr, port orelse 0) catch {
                    return oz.raiseValueError("`sockaddr()` - `addr` or `port` not valid IPv6");
                };
                _sock.sin6_family = family;
                _sock.sin6_port = _result.sa.port;
                _sock.sin6_addr.__in6_u.__u6_addr8 = _result.sa.addr;
                _sock.sin6_scope_id = _result.sa.scope_id;
                _sock.sin6_flowinfo = _result.sa.flowinfo;
                sockaddr = @intFromPtr(_sock);
            },
            else => return oz.raiseNotImplementedError(oz.fmt("`sockaddr()` - `family={d}` not supported!", .{family})),
        }
        return .{ ._sockaddr = sockaddr, ._socklen = socklen, ._family = family };
    }

    pub fn __del__(self: *Self) void {
        switch (self._family) {
            AF.UNIX => {
                const ptr: *c.sockaddr_un = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            AF.INET => {
                const ptr: *c.sockaddr_in = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            AF.INET6 => {
                const ptr: *c.sockaddr_in6 = @ptrFromInt(self._sockaddr);
                std.heap.c_allocator.destroy(ptr);
            },
            else => {},
        }
    }
};

// Socket Family
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
pub const IPPROTO_IP = IPPROTO_IP;
pub const IPPROTO_ICMP = IPPROTO_ICMP;
pub const IPPROTO_IGMP = IPPROTO_IGMP;
pub const IPPROTO_IPIP = IPPROTO_IPIP;
pub const IPPROTO_TCP = IPPROTO_TCP;
pub const IPPROTO_EGP = IPPROTO_EGP;
pub const IPPROTO_PUP = IPPROTO_PUP;
pub const IPPROTO_UDP = IPPROTO_UDP;
pub const IPPROTO_IDP = IPPROTO_IDP;
pub const IPPROTO_TP = IPPROTO_TP;
pub const IPPROTO_DCCP = IPPROTO_DCCP;
pub const IPPROTO_IPV6 = IPPROTO_IPV6;
pub const IPPROTO_RSVP = IPPROTO_RSVP;
pub const IPPROTO_GRE = IPPROTO_GRE;
pub const IPPROTO_ESP = IPPROTO_ESP;
pub const IPPROTO_AH = IPPROTO_AH;
pub const IPPROTO_MTP = IPPROTO_MTP;
pub const IPPROTO_BEETPH = IPPROTO_BEETPH;
pub const IPPROTO_ENCAP = IPPROTO_ENCAP;
pub const IPPROTO_PIM = IPPROTO_PIM;
pub const IPPROTO_COMP = IPPROTO_COMP;
// # note: not supported
// pub const IPPROTO_L2TP = IPPROTO_L2TP;
pub const IPPROTO_SCTP = IPPROTO_SCTP;
pub const IPPROTO_UDPLITE = IPPROTO_UDPLITE;
pub const IPPROTO_MPLS = IPPROTO_MPLS;
pub const IPPROTO_ETHERNET = IPPROTO_ETHERNET;
pub const IPPROTO_RAW = IPPROTO_RAW;
pub const IPPROTO_MPTCP = IPPROTO_MPTCP;

// Setsockopt & Getsockopt start >>>
pub const SOL_SOCKET = SOL_SOCKET;
pub const SO_DEBUG = SO_DEBUG;
pub const SO_REUSEADDR = SO_REUSEADDR;
pub const SO_TYPE = SO_TYPE;
pub const SO_ERROR = SO_ERROR;
pub const SO_DONTROUTE = SO_DONTROUTE;
pub const SO_BROADCAST = SO_BROADCAST;
pub const SO_SNDBUF = SO_SNDBUF;
pub const SO_RCVBUF = SO_RCVBUF;
pub const SO_SNDBUFFORCE = SO_SNDBUFFORCE;
pub const SO_RCVBUFFORCE = SO_RCVBUFFORCE;
pub const SO_KEEPALIVE = SO_KEEPALIVE;
pub const SO_OOBINLINE = SO_OOBINLINE;
pub const SO_NO_CHECK = SO_NO_CHECK;
pub const SO_PRIORITY = SO_PRIORITY;
pub const SO_LINGER = SO_LINGER;
pub const SO_BSDCOMPAT = SO_BSDCOMPAT;
pub const SO_REUSEPORT = SO_REUSEPORT;
pub const SO_PASSCRED = SO_PASSCRED;
pub const SO_PEERCRED = SO_PEERCRED;
pub const SO_RCVLOWAT = SO_RCVLOWAT;
pub const SO_SNDLOWAT = SO_SNDLOWAT;
pub const SO_BINDTODEVICE = SO_BINDTODEVICE;

// Socket Filtering
pub const SO_ATTACH_FILTER = SO_ATTACH_FILTER;
pub const SO_DETACH_FILTER = SO_DETACH_FILTER;
pub const SO_GET_FILTER = SO_GET_FILTER;
pub const SO_PEERNAME = SO_PEERNAME;
pub const SO_ACCEPTCONN = SO_ACCEPTCONN;
pub const SO_PEERSEC = SO_PEERSEC;
pub const SO_PASSSEC = SO_PASSSEC;
pub const SO_MARK = SO_MARK;
pub const SO_PROTOCOL = SO_PROTOCOL;
pub const SO_DOMAIN = SO_DOMAIN;
pub const SO_RXQ_OVFL = SO_RXQ_OVFL;
pub const SO_WIFI_STATUS = SO_WIFI_STATUS;
pub const SCM_WIFI_STATUS = SCM_WIFI_STATUS;
pub const SO_PEEK_OFF = SO_PEEK_OFF;

// not tested
pub const SO_TIMESTAMP = SO_TIMESTAMP;
pub const SO_TIMESTAMPNS = SO_TIMESTAMPNS;
pub const SO_TIMESTAMPING = SO_TIMESTAMPING;
pub const SO_RCVTIMEO = SO_RCVTIMEO;
pub const SO_SNDTIMEO = SO_SNDTIMEO;
