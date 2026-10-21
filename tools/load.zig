//! Tiny HTTP load generator for `example/bench/liburing_bench.{py,c}` (no siege/wrk needed; from Shakti).
//!
//!     zig build load
//!     zig-out/bin/load [port=12345] [connections=64] [seconds=5] [requests_per_connection=1]
//!
//! Each thread loops: connect, then `requests_per_connection` times send a GET
//! and read the whole response (by `Content-Length`), then close. With 1 this
//! is what `siege -b` does (the servers say `Connection: close`) and mostly
//! measures kernel connect/accept cost; larger values measure the server's
//! per-request work (the servers keep reading until the client closes).
//! Uses raw Linux syscalls only.

const std = @import("std");
const linux = std.os.linux;

const request = "GET / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n";

const Shared = struct {
    port: u16,
    per_conn: u64,
    deadline_ns: i128,
    ok: std.atomic.Value(u64) = .init(0),
    failed: std.atomic.Value(u64) = .init(0),
};

/// Monotonic clock in nanoseconds.
fn now() i128 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

/// Did a raw Linux syscall succeed (no errno in `rc`)?
fn ok(rc: usize) bool {
    return linux.errno(rc) == .SUCCESS;
}

/// One connection carrying `count` requests. Returns how many succeeded.
fn connection(port: u16, count: u64) u64 {
    const rc = linux.socket(linux.AF.INET, linux.SOCK.STREAM, 0);
    if (!ok(rc)) return 0;
    const fd: i32 = @intCast(rc);
    defer _ = linux.close(fd);

    var addr: linux.sockaddr.in = .{
        .port = std.mem.nativeToBig(u16, port),
        .addr = std.mem.nativeToBig(u32, 0x7f000001),
    };
    if (!ok(linux.connect(fd, @ptrCast(&addr), @sizeOf(@TypeOf(addr))))) return 0;
    var done: u64 = 0;
    while (done < count and once(fd)) done += 1;
    return done;
}

/// One request/response on an open connection.
fn once(fd: i32) bool {
    var sent: usize = 0;
    while (sent < request.len) {
        const n = linux.write(fd, request[sent..].ptr, request.len - sent);
        if (!ok(n)) return false;
        sent += n;
    }

    var buf: [4096]u8 = undefined;
    var have: usize = 0;
    var want: ?usize = null;
    while (want == null or have < want.?) {
        const n = linux.read(fd, buf[have..].ptr, buf.len - have);
        if (!ok(n) or n == 0) return false;
        have += n;
        if (want == null) {
            const end = std.mem.indexOf(u8, buf[0..have], "\r\n\r\n") orelse continue;
            const key = "Content-Length:";
            const at = std.mem.indexOf(u8, buf[0..end], key) orelse return false;
            const line_end = std.mem.indexOfPos(u8, buf[0..end], at, "\r\n") orelse end;
            const text = std.mem.trim(u8, buf[at + key.len .. line_end], " ");
            want = end + 4 + (std.fmt.parseInt(usize, text, 10) catch return false);
            if (want.? > buf.len) return false;
        }
    }
    return true;
}

/// One load thread: opens connections and runs requests on them until the deadline,
/// counting successes and failures.
fn worker(shared: *Shared) void {
    while (now() < shared.deadline_ns) {
        const done = connection(shared.port, shared.per_conn);
        _ = shared.ok.fetchAdd(done, .monotonic);
        _ = shared.failed.fetchAdd(shared.per_conn - done, .monotonic);
    }
}

/// Command-line argument `i` as an integer, or `default` if missing or invalid.
///
/// Example
///     >>> arg(args, 2, 64) // zig-out/bin/load 12345 64 5 100
///     64
fn arg(args: []const [:0]const u8, i: usize, default: u64) u64 {
    if (i >= args.len) return default;
    return std.fmt.parseInt(u64, args[i], 10) catch default;
}

/// `load [port=12345] [connections=64] [seconds=5] [requests_per_connection=1]`:
/// runs the threads and prints requests, failures and req/s.
pub fn main(init: std.process.Init.Minimal) !void {
    const args = try init.args.toSlice(std.heap.page_allocator);
    const port: u16 = @intCast(arg(args, 1, 12345));
    const connections = arg(args, 2, 64);
    const seconds = arg(args, 3, 5);
    const per_conn = @max(arg(args, 4, 1), 1);

    var shared: Shared = .{ .port = port, .per_conn = per_conn, .deadline_ns = now() + seconds * std.time.ns_per_s };
    const start = now();
    var threads: [1024]std.Thread = undefined;
    const n = @min(connections, threads.len);
    for (threads[0..n]) |*t| t.* = try std.Thread.spawn(.{}, worker, .{&shared});
    for (threads[0..n]) |t| t.join();
    const elapsed = @as(f64, @floatFromInt(now() - start)) / std.time.ns_per_s;

    const done = shared.ok.load(.monotonic);
    std.debug.print("{d} requests, {d} failed, {d:.2}s, {d:.0} req/s ({d} connections, {d} req/conn)\n", .{
        done, shared.failed.load(.monotonic), elapsed, @as(f64, @floatFromInt(done)) / elapsed, n, per_conn,
    });
}
