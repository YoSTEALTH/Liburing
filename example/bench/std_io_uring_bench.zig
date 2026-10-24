//! HTTP keep-alive echo server on `std.os.linux.IoUring`, the same response and
//! connection handling as `liburing_bench.py`.
//!
//!     zig build-exe -OReleaseFast -femit-bin=zig-out/bin/std_io_uring_bench example/bench/std_io_uring_bench.zig
//!     zig-out/bin/std_io_uring_bench 12345
//!
//! One thread, one ring, default flags. Each connection: recv, send the response, recv again.
//! Closes the connection when recv or send returns 0 or an error.

const std = @import("std");
const linux = std.os.linux;

const LISTEN = 1024;
const ENTRIES = 4096;
const BUFSIZE = 1024;

const RESPONSE = "HTTP/1.1 200 OK\r\n" ++
    "Content-Type: text/html\r\n" ++
    "Content-Length: 131\r\n" ++
    "Connection:close\r\n\r\n" ++
    "<!DOCTYPE html><html><head><title>Hello</title></head>" ++
    "<body style=\"background-color:#151515;color:#ccc;\">" ++
    "Hello world!</body></html>";

/// user_data tags, in the low 3 bits (connections are 8-byte aligned).
const Op = enum(u3) { accept = 0, recv = 1, send = 2 };

const Conn = struct {
    fd: linux.fd_t,
    sent: usize = 0,
    buf: [BUFSIZE]u8 = undefined,
};

const Server = struct {
    ring: linux.IoUring,
    gpa: std.mem.Allocator,
    listen_fd: linux.fd_t,

    fn flush(s: *Server) void {
        _ = s.ring.submit() catch unreachable;
    }

    fn armAccept(s: *Server) void {
        _ = s.ring.accept(@backingInt(Op.accept), s.listen_fd, null, null, linux.SOCK.CLOEXEC) catch {
            s.flush();
            _ = s.ring.accept(@backingInt(Op.accept), s.listen_fd, null, null, linux.SOCK.CLOEXEC) catch unreachable;
        };
    }

    fn armRecv(s: *Server, conn: *Conn) void {
        const data = @intFromPtr(conn) | @backingInt(Op.recv);
        _ = s.ring.recv(data, conn.fd, .{ .buffer = conn.buf[0..] }, 0) catch {
            s.flush();
            _ = s.ring.recv(data, conn.fd, .{ .buffer = conn.buf[0..] }, 0) catch unreachable;
        };
    }

    fn armSend(s: *Server, conn: *Conn) void {
        const data = @intFromPtr(conn) | @backingInt(Op.send);
        _ = s.ring.send(data, conn.fd, RESPONSE[conn.sent..], 0) catch {
            s.flush();
            _ = s.ring.send(data, conn.fd, RESPONSE[conn.sent..], 0) catch unreachable;
        };
    }

    fn closeConn(s: *Server, conn: *Conn) void {
        _ = linux.close(conn.fd);
        s.gpa.destroy(conn);
    }

    fn handle(s: *Server, cqe: linux.io_uring_cqe) void {
        const op: Op = @fromBackingInt(@intCast(@as(u3, @truncate(cqe.user_data))));
        if (op == .accept) {
            if (cqe.res >= 0) {
                const conn = s.gpa.create(Conn) catch unreachable;
                conn.* = .{ .fd = cqe.res };
                s.armRecv(conn);
            }
            s.armAccept();
            return;
        }

        const conn: *Conn = @ptrFromInt(cqe.user_data & ~@as(u64, 7));
        switch (op) {
            .accept => unreachable,
            .recv => {
                if (cqe.res <= 0) {
                    s.closeConn(conn);
                } else {
                    conn.sent = 0;
                    s.armSend(conn);
                }
            },
            .send => {
                if (cqe.res <= 0) {
                    s.closeConn(conn);
                    return;
                }
                conn.sent += @intCast(cqe.res);
                if (conn.sent < RESPONSE.len) {
                    s.armSend(conn);
                } else {
                    s.armRecv(conn);
                }
            },
        }
    }
};

fn listenOn(port: u16) !linux.fd_t {
    const rc = linux.socket(linux.AF.INET, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
    if (@as(isize, @bitCast(rc)) < 0) return error.Socket;
    const fd: linux.fd_t = @intCast(rc);

    const one: c_int = 1;
    _ = linux.setsockopt(fd, linux.SOL.SOCKET, linux.SO.REUSEADDR, @ptrCast(&one), @sizeOf(c_int));

    var addr = linux.sockaddr.in{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001), // 127.0.0.1
    };
    if (@as(isize, @bitCast(linux.bind(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.in)))) < 0)
        return error.Bind;
    if (@as(isize, @bitCast(linux.listen(fd, LISTEN))) < 0) return error.Listen;
    return fd;
}

pub fn main(init: std.process.Init.Minimal) !void {
    const argv = init.args.vector;
    const port: u16 = if (argv.len > 1)
        try std.fmt.parseInt(u16, std.mem.span(argv[1]), 10)
    else
        12345;

    _ = linux.sigaction(linux.SIG.PIPE, &.{
        .handler = .{ .handler = linux.SIG.IGN },
        .mask = linux.sigemptyset(),
        .flags = 0,
    }, null);

    var s: Server = .{
        .ring = try linux.IoUring.init(ENTRIES, 0),
        .gpa = std.heap.smp_allocator,
        .listen_fd = try listenOn(port),
    };
    defer s.ring.deinit();

    std.debug.print("Starting std.os.linux.IoUring server on 127.0.0.1:{d}\n", .{port});
    s.armAccept();

    var cqes: [256]linux.io_uring_cqe = undefined;
    while (true) {
        _ = try s.ring.submit_and_wait(1);
        const n = try s.ring.copy_cqes(&cqes, 0);
        for (cqes[0..n]) |cqe| s.handle(cqe);
    }
}
