//! HTTP keep-alive echo server on `std.Io` with the `std.Io.Threaded` backend, the same response and
//! connection handling as `std_io_uring_bench.zig` and `liburing_bench.py` (and Shakti's `example/bench`,
//! where this file comes from).
//!
//!     zig build-exe -OReleaseFast -femit-bin=zig-out/bin/std_io_bench example/bench/std_io_bench.zig
//!     zig-out/bin/std_io_bench 12345
//!
//! `std.Io.Uring` (io_uring) does not compile on Zig 0.17.0, so this uses the thread backend: one
//! thread per connection, blocking syscalls. Each connection: read, write the response, read again.
//! Closes the connection when a read returns 0 or an error.

const std = @import("std");
const linux = std.os.linux;
const Io = std.Io;
const net = std.Io.net;

const LISTEN = 1024;
const BUFSIZE = 1024;

const RESPONSE = "HTTP/1.1 200 OK\r\n" ++
    "Content-Type: text/html\r\n" ++
    "Content-Length: 131\r\n" ++
    "Connection:close\r\n\r\n" ++
    "<!DOCTYPE html><html><head><title>Hello</title></head>" ++
    "<body style=\"background-color:#151515;color:#ccc;\">" ++
    "Hello world!</body></html>";

fn handle(io: Io, stream: net.Stream) void {
    defer stream.close(io);
    var rbuf: [BUFSIZE]u8 = undefined;
    var wbuf: [RESPONSE.len]u8 = undefined;
    var reader = stream.reader(io, &rbuf);
    var writer = stream.writer(io, &wbuf);
    while (true) {
        // peekGreedy returns whatever one read gave (readSliceShort would wait for a full buffer).
        const got = reader.interface.peekGreedy(1) catch return;
        reader.interface.toss(got.len);
        writer.interface.writeAll(RESPONSE) catch return;
        writer.interface.flush() catch return;
    }
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

    var threaded: Io.Threaded = .init(std.heap.smp_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var server = try (net.IpAddress{ .ip4 = .loopback(port) }).listen(io, .{
        .kernel_backlog = LISTEN,
        .reuse_address = true,
    });
    defer server.deinit(io);

    std.debug.print("Starting std.Io (Io.Threaded) server on 127.0.0.1:{d}\n", .{port});

    var group: Io.Group = .init;
    defer group.cancel(io);
    while (true) {
        const stream = server.accept(io) catch continue;
        group.concurrent(io, handle, .{ io, stream }) catch {
            stream.close(io);
        };
    }
}
