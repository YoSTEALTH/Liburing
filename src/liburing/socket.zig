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
