//! Liburing - Helper functions
const c = @import("c.zig").c;
const n = @import("enum.zig");
const oz = @import("PyOZ");
const std = @import("std");

const Timespec = @import("class.zig").Timespec;

///File Index
///
///Example
///    >>> ids = FileIndex([-1, -1, 3])
///    >>> ids[1]
///    -1
///    >>> ids.update([4, 5, 6])
///    >>> ids[1]
///    5
///    >>> list(ids)
///    [4, 5, 6]
///    >>> for id in ids:
///    ...     # do something e.g.`if id != -1: os.close(id)`
///
///Note
///    - Makes copy of the list provided & shares it with `io_uring`,
///    so modifying python list will not effect `FileIndex` already submitting.
pub const FileIndex = extern struct {
    _fds: [*]i32,
    _len: usize,
    _index: usize,

    const Self = @This();

    pub fn __new__(list: oz.ListView(i32)) !Self {
        const _len = list.len();
        var fds = try std.heap.c_allocator.alloc(i32, _len);
        for (0.._len) |i| {
            if (list.get(i)) |fd| {
                fds[i] = fd;
            } else return error.TypeError;
        }
        return .{ ._fds = @ptrCast(fds), ._len = _len, ._index = 0 };
    }

    pub fn __del__(self: *Self) void {
        std.heap.c_allocator.free(self._fds[0..self._len]);
    }

    pub fn __iter__(self: *Self) *Self {
        self._index = 0;
        return self;
    }

    pub fn __next__(self: *Self) ?i32 {
        if (self._index >= self._len) return null; // None
        defer self._index += 1;
        return self._fds[self._index];
    }

    pub fn __getitem__(self: *const Self, index: usize) !i32 {
        if (index < self._len) return self._fds[index];
        return error.IndexError;
    }

    pub fn update(self: *Self, list: oz.ListView(i32)) !void {
        const _len = list.len();
        if (self._len != _len) return error.ValueError;

        for (0.._len) |i| {
            if (list.get(i)) |fd| {
                self._fds[i] = fd;
            } else return error.ValueError;
        }
    }
};

///Probe your system to find out which `io_uring` operations are available.
///
///Example
///    >>> probe()
///    {'IORING_OP_NOP': True, ...}
///
///    # or
///
///    >>> for op, supported in probe().items():
///    ...     op, supported
///    IORING_OP_NOP True
///
pub fn probe() ?oz.Dict([]const u8, bool) {
    const last: usize = @intFromEnum(n.io_uring_op.IORING_OP_LAST);
    const items = std.meta.fields(n.io_uring_op);
    var entries: [last]oz.Dict([]const u8, bool).Entry = undefined;

    if (c.io_uring_get_probe()) |p| {
        defer c.io_uring_free_probe(p);

        inline for (0..last) |i| {
            entries[i] = .{ .key = items[i].name, .value = (c.io_uring_opcode_supported(p, items[i].value) == 1) };
        }
        return .{ .entries = &entries };
    }
    return oz.raiseRuntimeError("Linux kernel version does not support `probe()`");
}

///Kernel Timespec
///
///Example
///    >>> ts = timespec(1)        # int
///    >>> ts = timespec(1.5)      # float
///    >>> io_uring_prep_timeout(sqe, ts, ...)
///
pub fn timespec(second: f64) ?Timespec {
    var ts = std.heap.c_allocator.create(c.__kernel_timespec) catch {
        return oz.raiseMemoryError("`timespec()` - Out of Memory!");
    };
    // split float to second & nano second
    if (second != 0.0) {
        ts.tv_sec = @intFromFloat(second);
        const x: f64 = @floatFromInt(ts.tv_sec);
        ts.tv_nsec = @intFromFloat((second - x) * 1_000_000_000);
    } else {
        ts.* = std.mem.zeroes(c.__kernel_timespec); // set default value to `0`
    }
    return .{ ._timespec = ts };
}
