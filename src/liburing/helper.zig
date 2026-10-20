//! Liburing - Helper functions
const c = @import("c.zig").c;
const e = @import("error.zig");
const n = @import("enum.zig");
const setu = @import("setu");
const std = @import("std");
const class = @import("class.zig");

const py = setu.py;
const sc = setu.c;
const Object = sc.Object;
const Ring = class.Ring;
const Sqe = class.Sqe;
const Timespec = class.Timespec;

pub const FileIndexType = setu.Class(FileIndex, @embedFile("helper.zig"));

/// File Index
///
/// Example
///     >>> ids = FileIndex([-1, -1, 3])
///     >>> ids[1]
///     -1
///     >>> ids.update([4, 5, 6])
///     >>> ids[1]
///     5
///     >>> list(ids)
///     [4, 5, 6]
///     >>> for id in ids:
///     ...     # do something e.g.`if id != -1: os.close(id)`
///
/// Note
///     - Makes copy of the list provided & shares it with `io_uring`,
///     so modifying python list will not effect `FileIndex` already submitting.
pub const FileIndex = struct {
    _fds: ?[*]i32 = null,
    _len: usize = 0,
    _index: usize = 0,

    const Self = @This();

    pub fn __new__(self: *Self, list: py.Sequence(i32)) py.Error!void {
        const fds = std.heap.c_allocator.dupe(i32, list.items) catch return e.raiseMemoryError("Out of Memory!");
        self._fds = fds.ptr;
        self._len = fds.len;
    }

    pub fn __del__(self: *Self) void {
        if (self._fds) |fds| std.heap.c_allocator.free(fds[0..self._len]);
    }

    /// Type
    ///     return: Self
    pub fn __iter__(self: *Object) *Object {
        FileIndexType.data(self)._index = 0;
        return class.keep(self);
    }

    pub fn __next__(self: *Self) ?i32 {
        if (self._index >= self._len) return null; // StopIteration
        defer self._index += 1;
        return self._fds.?[self._index];
    }

    pub fn __getitem__(self: *const Self, index: isize) py.Error!i32 {
        if (index >= 0 and index < self._len) return self._fds.?[@intCast(index)]; // cast: checked
        return py.raiseIndexError("`FileIndex` - index out of range", .{});
    }

    pub fn update(self: *Self, list: py.Sequence(i32)) py.Error!void {
        if (self._len != list.items.len) return py.raiseValueError(
            "`FileIndex.update(list)` - length of {d} does not match {d}",
            .{ list.items.len, self._len },
        );
        if (self._fds) |fds| @memcpy(fds[0..self._len], list.items);
    }

    /// The registered file descriptors (Zig side).
    pub fn fdSlice(self: *const Self) []i32 {
        return if (self._fds) |fds| fds[0..self._len] else &.{};
    }
};

/// Probe your system to find out which `io_uring` operations are available.
///
/// Example
///     >>> probe()
///     {'IORING_OP_NOP': True, ...}
///
///     # or
///
///     >>> for op, supported in probe().items():
///     ...     op, supported
///     IORING_OP_NOP True
///
///
/// Type
///     return: dict[str, bool]
pub fn probe() py.Error!*Object {
    const last: usize = @backingInt(n.io_uring_op.IORING_OP_LAST);
    const items = @typeInfo(n.io_uring_op).@"enum".field_names;

    const p = c.io_uring_get_probe() orelse
        return py.raiseRuntimeError("Linux kernel version does not support `probe()`", .{});
    defer c.io_uring_free_probe(p);

    const dict = sc.PyDict_New() orelse return error.PythonError;
    errdefer py.decref(dict);
    inline for (items[0..last]) |name| {
        const op = @backingInt(@field(n.io_uring_op, name));
        const value = if (c.io_uring_opcode_supported(p, op) == 1) py.trueObj() else py.falseObj();
        const key = try py.new(name);
        defer py.decref(key);
        if (sc.PyDict_SetItem(dict, key, value) < 0) return error.PythonError;
    }
    return dict;
}

/// Kernel Timespec
///
/// Example
///     >>> ts = timespec(1)        # int
///     >>> ts = timespec(1.5)      # float
///     >>> io_uring_prep_timeout(sqe, ts, ...)
///
///
/// Type
///     return: Timespec
pub fn timespec(second: f64) py.Error!*Object {
    if (!std.math.isFinite(second) or second < 0) {
        return py.raiseValueError("`timespec(second)` must be a finite number >= 0, got {d}", .{second});
    }
    if (second >= 0x1p63) return py.raiseOverflowError("`timespec(second)` = {d} is out of range", .{second});
    var ts = std.heap.c_allocator.create(c.__kernel_timespec) catch {
        return e.raiseMemoryError("`timespec()` - Out of Memory!");
    };
    errdefer std.heap.c_allocator.destroy(ts);
    // split float to second & nano second
    if (second != 0.0) {
        ts.tv_sec = @intFromFloat(second);
        const x: f64 = @floatFromInt(ts.tv_sec);
        ts.tv_nsec = @intFromFloat((second - x) * 1_000_000_000);
    } else {
        ts.* = std.mem.zeroes(c.__kernel_timespec); // set default value to `0`
    }
    return class.TimespecType.new(.{ ._timespec = ts });
}

/// Put `io_uring_sqe` into `io_uring` ring's memory.
///
/// Type
///     ring:   Ring
///     sqe:    Sqe
///     return: bool
///
/// Example
///     # single
///     >>> sqe = Sqe()
///     >>> io_uring_prep_read(sqe, ...)
///
///     # multiple
///     >>> sqe = Sqe(2)
///     >>> io_uring_prep_read(sqe[0], ...)
///     >>> io_uring_prep_write(sqe[1], ...)
///
///     # back-end single | multiple
///     >>> if put_sqe(self.ring, sqe):
///     ...     # do stuff
///
///     # failed: `ring` was full, submit and try to again.
///     >>> if put_sqe(self.ring, sqe):
///     ...     io_uring_submit(self.ring)
///     ...     if put_sqe(self.ring, sqe):
///     ...         # do stuff
///
/// Note
///     - Returns `False` if queue is full. Will need to `io_uring_submit()` and try again.
///     - Returns `False` if `entries` < `len(sqe)`
pub fn put_sqe(ring: *Ring, sqe: *Sqe) py.Error!bool {
    const io_uring = try ring.checkedPtr();
    if (sqe._keep) |list| try keepAll(&ring._keep, list); // paths its entries point to, until submit
    //note:
    //    - its ok to submit `0` sqe thus `True`
    //    - this also accounts for `ptr` gotten from `io_uring_get_sqe`
    //    as its `len == 0` thus not try to replace memory by mistake!
    if (sqe._len == 0) return true;

    if (sqe._io_uring_sqe) |_sqe| {
        if (sqe._len == 1) { // single
            if (c.io_uring_get_sqe(io_uring)) |s| {
                @memcpy(s, _sqe[0..1]);
                return true;
            }
        } else if (c.io_uring_sq_space_left(io_uring) >= sqe._len) { // multiple
            for (0..sqe._len) |i| {
                if (c.io_uring_get_sqe(io_uring)) |s| {
                    @memcpy(s, _sqe[i .. i + 1]);
                } // else should not trigger since space left is per-checked!
            }
            return true;
        }
        return false;
    } else return false;
}

/// A path argument (`str` or `os.PathLike`, not `bytes`, as with PyOZ): `path` is the UTF-8 of
/// the `str` that `os.fspath` gives, so it stays valid while that `str` lives, past the call:
/// io_uring reads it at submit time, not when the `sqe` is prepared.
///
/// Note
///      - `str` arguments (and `pathlib` paths, which cache their `str`) live as long as the
///        caller's object; `deinit` drops only the reference this took.
/// Keeps `obj` (a path `str`, ...) alive until the kernel has read the entry `sqe`: on its `Ring`
/// until a submit consumes it, or on its `Sqe` until `put_sqe` hands it to a ring. io_uring reads
/// paths at submit time, so a temporary (`dir / "name"`) would otherwise be freed before that.
pub fn keepUntilSubmit(sqe: *class.SQE, obj: *Object) py.Error!void {
    const self = class.SQEType.object(sqe);
    if (sqe._owner) |owner| {
        if (class.RingType.check(owner)) return keepIn(&class.RingType.data(owner)._keep, obj);
        if (class.SqeType.check(owner)) return keepIn(&class.SqeType.data(owner)._keep, obj);
    }
    if (class.SqeType.check(self)) return keepIn(&class.SqeType.data(self)._keep, obj);
}

/// Appends `obj` to the owned `list` field `field` (created on first use).
fn keepIn(field: *?*Object, obj: *Object) py.Error!void {
    if (field.* == null) field.* = sc.PyList_New(0) orelse return error.PythonError;
    if (sc.PyList_Append(field.*.?, obj) < 0) return error.PythonError;
}

/// Appends every item of the `list` `items` to the owned `list` field `field`.
fn keepAll(field: *?*Object, items: *Object) py.Error!void {
    const count = sc.PyList_Size(items);
    var i: sc.ssize = 0;
    while (i < count) : (i += 1) try keepIn(field, sc.PyList_GetItem(items, i).?);
}

pub const Path = struct {
    obj: *Object,
    path: [:0]const u8,

    pub fn deinit(self: Path) void {
        py.decref(self.obj);
    }
};

extern fn PyOS_FSPath(*Object) ?*Object;

pub fn toPath(obj: *Object) py.Error!Path {
    if (sc.PyBytes_Check(obj) != 0) return py.raiseTypeError("expected `str` or `os.PathLike`, not `bytes`", .{});
    const text = PyOS_FSPath(obj) orelse return error.PythonError; // a new reference
    errdefer py.decref(text);
    if (sc.PyUnicode_Check(text) == 0) return py.raiseTypeError("expected `str` or `os.PathLike`, not `bytes`", .{});
    var len: sc.ssize = 0;
    const ptr = sc.PyUnicode_AsUTF8AndSize(text, &len) orelse return error.PythonError;
    return .{ .obj = text, .path = ptr[0..@intCast(len) :0] };
}
