//! Submit/complete micro benchmark on `std.os.linux.IoUring`: the same cases, counts and output as
//! `loop_bench.py`, without Python, for a native floor under Liburing's numbers.
//!
//!     zig build-exe -OReleaseFast -femit-bin=zig-out/bin/loop_bench example/bench/loop_bench.zig
//!     zig-out/bin/loop_bench

const std = @import("std");
const linux = std.os.linux;
const IoUring = linux.IoUring;

const ROUNDS = 5;
const BATCH = 1024;

/// One NOP, submitted and reaped `n` times back to back (per-round-trip overhead).
fn nopSerial(ring: *IoUring, n: u64) !void {
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        _ = try ring.nop(i);
        _ = try ring.submit_and_wait(1);
        const cqe = try ring.copy_cqe();
        std.mem.doNotOptimizeAway(cqe.user_data);
    }
}

/// `BATCH` NOPs per submit, `n` in total, completions reaped without reading them (per-op overhead).
fn nopBatch(ring: *IoUring, n: u64) !void {
    var round: u64 = 0;
    while (round < n / BATCH) : (round += 1) {
        for (0..BATCH) |i| _ = try ring.nop(i);
        _ = try ring.submit_and_wait(BATCH);
        ring.cq_advance(ring.cq_ready());
    }
}

/// `nopBatch`, plus reading every completion's `user_data` and `res` (what a server does).
fn nopBatchRead(ring: *IoUring, n: u64) !void {
    var cqes: [BATCH]linux.io_uring_cqe = undefined;
    var sum: u64 = 0;
    var round: u64 = 0;
    while (round < n / BATCH) : (round += 1) {
        for (0..BATCH) |i| _ = try ring.nop(i);
        _ = try ring.submit(); // `copy_cqes` below waits
        var got: u32 = 0;
        while (got < BATCH) {
            const c = try ring.copy_cqes(cqes[got..], BATCH - got);
            for (cqes[got..][0..c]) |cqe| sum +%= cqe.user_data +% @as(u64, @bitCast(@as(i64, cqe.res)));
            got += c;
        }
    }
    std.mem.doNotOptimizeAway(sum);
}

/// `BATCH` NOPs prepared once in an array and copied into the ring per submit (what `put_sqe` does).
fn putBatch(ring: *IoUring, n: u64) !void {
    var sqes: [BATCH]linux.io_uring_sqe = undefined;
    for (&sqes, 0..) |*sqe, i| {
        sqe.* = std.mem.zeroes(linux.io_uring_sqe);
        sqe.opcode = .NOP;
        sqe.user_data = i;
    }
    var round: u64 = 0;
    while (round < n / BATCH) : (round += 1) {
        for (&sqes) |*src| (try ring.get_sqe()).* = src.*;
        _ = try ring.submit_and_wait(BATCH);
        ring.cq_advance(ring.cq_ready());
    }
}

const Case = struct { name: []const u8, n: u64, run: *const fn (*IoUring, u64) anyerror!void };

const cases = [_]Case{
    .{ .name = "nop serial", .n = 100_000, .run = nopSerial },
    .{ .name = std.fmt.comptimePrint("nop batch x{d}", .{BATCH}), .n = 1_024_000, .run = nopBatch },
    .{ .name = std.fmt.comptimePrint("nop batch x{d} + read", .{BATCH}), .n = 1_024_000, .run = nopBatchRead },
    .{ .name = std.fmt.comptimePrint("put_sqe batch x{d}", .{BATCH}), .n = 1_024_000, .run = putBatch },
};

/// Monotonic clock in nanoseconds.
fn now() i128 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

/// One run of `case` on a fresh ring of `2 * BATCH` entries (as `loop_bench.py`); nanoseconds.
fn time(case: Case) !i128 {
    var ring = try IoUring.init(BATCH * 2, 0);
    defer ring.deinit();
    const start = now();
    try case.run(&ring, case.n);
    return now() - start;
}

pub fn main() !void {
    std.debug.print(
        "std.os.linux.IoUring (Zig {s}), best of {d}\n\n",
        .{ @import("builtin").zig_version_string, ROUNDS },
    );
    std.debug.print("{s:<26}{s:>10}{s:>11}{s:>9}\n", .{ "case", "ops", "total ms", "ns/op" });
    for (cases) |case| {
        var best: i128 = std.math.maxInt(i128);
        for (0..ROUNDS) |_| best = @min(best, try time(case));
        const ns: f64 = @floatFromInt(best);
        const ops: f64 = @floatFromInt(case.n);
        std.debug.print("{s:<26}{d:>10}{d:>11.1}{d:>9.0}\n", .{ case.name, case.n, ns / 1e6, ns / ops });
    }
}
