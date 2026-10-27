//! Liburing - Helper functions
const c = @import("c");
const e = @import("error.zig");
const n = @import("enum.zig");
const setu = @import("setu");
const std = @import("std");
const class = @import("class.zig");
const Ring = @import("ring.zig").Ring;
const RingType = @import("ring.zig").RingType;
const Sqe = @import("sqe.zig").Sqe;
const SQE = @import("sqe.zig").SQE;
const SQEType = @import("sqe.zig").SQEType;
const SqeType = @import("sqe.zig").SqeType;

const py = setu.py;
const sc = setu.c;
const Object = sc.Object;
const Timespec = class.Timespec;

pub const FileIndexType = setu.Class(FileIndex, @embedFile("helper.zig"));
pub const FileIndexIterType = setu.Class(FileIndexIter, @embedFile("helper.zig"));

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
///     ...     id  # do something e.g.`if id != -1: os.close(id)`
///     ...
///     4
///     5
///     6
///
/// Note
///     - Makes copy of the list provided & shares it with `io_uring`,
///     so modifying python list will not effect `FileIndex` already submitting.
///     - For `io_uring_register_files` / `_files_update`: each slot is a file descriptor to register, `-1` an
///       empty (sparse) slot a later update or a `*_direct` request (`IORING_FILE_INDEX_ALLOC`) may fill. A
///       request uses a registered file by its slot index as `fd` with `IOSQE_FIXED_FILE` in `sqe.flags`.
pub const FileIndex = struct {
    _fds: ?[*]i32 = null,
    _len: usize = 0,

    const Self = @This();

    /// `FileIndex(list)`: a copy of the file descriptors in `list` (`-1`: a free slot).
    pub fn __new__(self: *Self, list: py.Sequence(i32)) py.Error!void {
        const fds = std.heap.c_allocator.dupe(i32, list.items) catch return e.raiseMemoryError("Out of Memory!");
        self._fds = fds.ptr;
        self._len = fds.len;
    }

    pub fn __del__(self: *Self) void {
        if (self._fds) |fds| std.heap.c_allocator.free(fds[0..self._len]);
    }

    /// A new iterator for each loop, so two loops (or two threads) over one `FileIndex` don't interfere.
    ///
    /// Type
    ///     return: FileIndexIter
    pub fn __iter__(self: *Object) py.Error!*Object {
        return FileIndexIterType.new(.{ ._ids = class.keep(self) });
    }

    /// The file descriptor at `index` (`IndexError` out of range).
    pub fn __getitem__(self: *const Self, index: isize) py.Error!i32 {
        if (index >= 0 and index < self._len) return self._fds.?[@intCast(index)]; // cast: checked
        return py.raiseIndexError("`FileIndex` - index out of range", .{});
    }

    /// Replace the file descriptors with `list`, which must have the same length (`ValueError` otherwise).
    ///
    /// Example
    ///     >>> ids = FileIndex([-1, -1, -1])
    ///     >>> ids.update([4, 5, 6])
    ///     >>> list(ids)
    ///     [4, 5, 6]
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

/// Iterator over a `FileIndex`, from `iter(ids)` (a `for` loop): its own position, so loops over one `FileIndex`
/// don't interfere.
pub const FileIndexIter = struct {
    _ids: ?*Object = null, // the `FileIndex` iterated (owned)
    _index: usize = 0, // the next entry

    pub const instantiable = false;

    const Self = @This();

    /// The next file descriptor.
    pub fn __next__(self: *Self) ?i32 {
        const ids = FileIndexType.data(self._ids.?);
        if (self._index >= ids._len) return null; // StopIteration
        defer self._index += 1;
        return ids._fds.?[self._index];
    }
};

/// Probe your system to find out which `io_uring` operations are available: a `dict` of every `IORING_OP_*` name
/// (up to, not including, `IORING_OP_LAST`) and whether the running kernel supports it.
///
/// Type
///     return: dict[str, bool]
///
/// Example
///     >>> probe()
///     {'IORING_OP_NOP': True, 'IORING_OP_READV': True, 'IORING_OP_WRITEV': True, ...}
///
/// Example
///     # or: one operation
///     >>> probe()['IORING_OP_READ']
///     True
///
/// Note
///     - Needs Linux 5.6+ (`IORING_REGISTER_PROBE`), else `RuntimeError`. Opcodes after the kernel's
///       `Probe.last_op` are `False`. Submitting an unsupported opcode is not refused: its completion fails with
///       `OSError: EINVAL`.
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
/// Type
///     second: float
///     return: Timespec
///
/// Example
///     >>> ts = timespec(1)        # int
///     >>> ts = timespec(1.5)      # float
///     >>> io_uring_prep_timeout(sqe, ts, 0)
///     True
///
/// Note
///     - `ValueError` if `second` is negative, `nan` or `inf`; `OverflowError` if too large.
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
        ts.tv_sec = @trunc(second);
        const x: f64 = @floatFromInt(ts.tv_sec);
        ts.tv_nsec = @trunc((second - x) * 1_000_000_000);
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
///     # single: `Sqe()`
///     >>> sqe = Sqe()
///     >>> io_uring_prep_nop(sqe)
///     True
///     >>> if put_sqe(ring, sqe):
///     ...     io_uring_submit(ring)  # do stuff
///     ...
///     1
///
/// Example
///     # multiple: `Sqe(2)`, both entries put with one call
///     >>> buf = bytearray(5)
///     >>> sqe = Sqe(2)
///     >>> io_uring_prep_read(sqe[0], fd, buf)
///     True
///     >>> io_uring_prep_write(sqe[1], fd, b'hi...')
///     True
///     >>> if put_sqe(ring, sqe):
///     ...     io_uring_submit(ring)  # do stuff
///     ...
///     2
///
/// Example
///     # failed: `ring` was full (2 entries here), submit and try again.
///     >>> sqe = Sqe(2)
///     >>> io_uring_prep_nop(sqe[0])
///     True
///     >>> io_uring_prep_nop(sqe[1])
///     True
///     >>> put_sqe(ring, sqe)
///     True
///     >>> put_sqe(ring, sqe)
///     False
///     >>> io_uring_submit(ring)
///     2
///     >>> put_sqe(ring, sqe)
///     True
///
/// Note
///     - Returns `False` if queue is full. Will need to `io_uring_submit()` and try again
///     (`Ring(auto_submit=True)` does that for you, unless the last queued request links on).
///     - Returns `False` if `entries` < `len(sqe)`
///     - Not for an `Sqe(ring)` (`TypeError`): its preps already wrote into the ring.
pub fn put_sqe(ring: *Ring, sqe: *Sqe) py.Error!bool {
    const io_uring = try ring.checkedPtr();
    if (SQEType.data(SqeType.object(sqe))._bound) return py.raiseTypeError(
        "`put_sqe(ring, sqe)`: an `Sqe(ring)` is already in its ring (its preps wrote there)",
        .{},
    );
    //note:
    //    - its ok to submit `0` sqe thus `True`
    //    - this also accounts for `ptr` gotten from `io_uring_get_sqe`
    //    as its `len == 0` thus not try to replace memory by mistake!
    if (sqe._len == 0) return true;

    if (sqe._io_uring_sqe) |_sqe| {
        try sqe.ownThread(ring._thread); // `checkedPtr`: the calling thread owns `ring`
        const holds = sqe._holds.?[0..sqe._len];
        for (holds) |*hold_| {
            if (!hold_.isEmpty()) break try ring.ensurePending(); // before any copy: no error after one
        }
        if (sqe._len == 1) { // single
            const slot = c.io_uring_get_sqe(io_uring) orelse
                if (try ring.autoSubmit()) c.io_uring_get_sqe(io_uring) else null;
            if (slot) |s| {
                @memcpy(s, _sqe[0..1]);
                holdTemplate(ring, s, sqe, &holds[0]);
                return true;
            }
        } else if (c.io_uring_sq_space_left(io_uring) >= sqe._len or
            (try ring.autoSubmit() and c.io_uring_sq_space_left(io_uring) >= sqe._len))
        { // multiple: all or none, so a chain in the template is never split
            for (0..sqe._len) |i| {
                if (c.io_uring_get_sqe(io_uring)) |s| {
                    @memcpy(s, _sqe[i .. i + 1]);
                    holdTemplate(ring, s, sqe, &holds[i]);
                } // else should not trigger since space left is per-checked!
            }
            return true;
        }
        return false;
    } else return false;
}

/// A copy (in the ring's slot `s`) of a template entry that holds something holds the template itself until
/// its completion, counted in `_inflight`: `del template`, or a re-prep of the entry, with the request in
/// flight can not free what the kernel uses.
inline fn holdTemplate(ring: *Ring, s: *c.io_uring_sqe, sqe: *Sqe, entry: *const Ring.Hold) void {
    if (entry.isEmpty()) return;
    const pending = ring.pendingSlot(s); // allocated: `ensurePending`
    var old = pending.*;
    sqe._inflight += 1;
    pending.* = .{ .template = class.keep(SqeType.object(sqe)) };
    old.release();
}

/// Keeps `buf` (a `py.Buffer` / `py.WritableBuffer`, an optional one, or `null`) locked and `objs` alive until
/// the completion of the request `sqe` prepares: in its ring's slot until the submit moves them into the
/// request's entry (`Ring.submitPtr`), or in its `Sqe` template for the template's lifetime (copies made by
/// `put_sqe` hold the template). Replaces what an earlier prep of the same entry held. Call it once per prep.
///
/// Note
///     - io_uring reads paths, `Sockaddr`, `timespec`, ... at submit time and writes into buffers until the
///       completion: a temporary (`bytearray(5)`, `dir / "name"`) would otherwise be freed under the kernel,
///       and a `bytearray` resized (`BufferError` now, while it is held).
pub fn holdUntilCompletion(sqe: *SQE, buf_ptr: anytype, objs: []const *Object) py.Error!void {
    const has_buf = @TypeOf(buf_ptr) != @TypeOf(null);
    const B = if (has_buf) @TypeOf(buf_ptr.*) else @TypeOf(null);
    const owned = comptime has_buf and py.owns(B); // `py.OwnedBuffer` / `py.OwnedWritableBuffer`: ours to release
    var moved = false; // an owned view went into the hold
    defer if (owned and !moved) releaseOwned(buf_ptr);
    const buf = if (has_buf) buf_ptr.* else null;
    if (objs.len == 0) switch (@typeInfo(B)) {
        .null => return,
        .optional => if (buf == null) return, // nothing to hold: what the slot held stays
        else => {},
    };
    _ = try sqe.sqePtr(); // ring initialized (and its thread), or a template's thread
    const where = try holdOf(sqe) orelse return;
    var new: Ring.Hold = .{};
    errdefer new.release();
    var bytes: ?*Object = null;
    switch (@typeInfo(B)) {
        .null => {},
        .optional => if (buf_ptr.*) |*b| try holdView(b, &new, &bytes, &moved),
        else => try holdView(buf_ptr, &new, &bytes, &moved),
    }
    const count = objs.len + @intFromBool(bytes != null);
    new.obj = switch (count) {
        0 => null,
        1 => class.keep(bytes orelse objs[0]),
        else => blk: {
            const tuple = sc.PyTuple_New(@intCast(count)) orelse return error.PythonError; // cast: a few
            for (objs, 0..) |o, i| _ = sc.PyTuple_SetItem(tuple, @intCast(i), class.keep(o)); // steals; cast: a few
            if (bytes) |o| _ = sc.PyTuple_SetItem(tuple, @intCast(objs.len), class.keep(o));
            break :blk tuple;
        },
    };
    if (where.template) |t| return t.replaceHold(where.hold, new); // on error: `errdefer` releases `new`
    if (where.hold.isEmpty()) { // the usual case (the submit emptied the slot): no copy of the old hold
        where.hold.* = new;
        return;
    }
    var old = where.hold.*;
    where.hold.* = new;
    old.release();
}

/// Keeps `vec` (a vectored prep's buffers and `struct iovec` array, owned from here on every path) until the
/// completion of the request `sqe` prepares, like `holdUntilCompletion`.
pub fn holdVecUntilCompletion(sqe: *SQE, vec: *Ring.Vec) py.Error!void {
    var new: Ring.Hold = .{ .vec = vec };
    errdefer new.release();
    _ = try sqe.sqePtr(); // ring initialized (and its thread), or a template's thread
    const where = try holdOf(sqe) orelse return; // nowhere to hold (no ring, no template): kept, not freed
    if (where.template) |t| return t.replaceHold(where.hold, new);
    var old = where.hold.*;
    where.hold.* = new;
    old.release();
}

/// A buffer argument for `holdUntilCompletion` (a pointer to it: no copy of the view). An owned one
/// (`py.OwnedBuffer` / `py.OwnedWritableBuffer`, what the preps take) moves its own view into the hold
/// (`moved`), released at the completion: no second `PyObject_GetBuffer`. A plain one: an exact `bytes`
/// (immutable, its memory lives as long as the object) only needs a reference (`bytes`), any other a locked
/// view of its own (`take`: ~35 ns more).
inline fn holdView(b: anytype, new: *Ring.Hold, bytes: *?*Object, moved: *bool) py.Error!void {
    if (comptime py.owns(@TypeOf(b.*))) { // its own view: kept, released at the completion
        new.view = b.view;
        moved.* = true;
        return;
    }
    if (b.view.obj) |obj| if (sc.Py_TYPE(obj) == sc.PyBytes_Type) {
        bytes.* = obj;
        return;
    };
    new.view = (try b.take()).view;
}

/// `sqe.prepSlot(false)` for a prep taking the owned buffer `buf_ptr` (optional or not): released here when the prep
/// stops before `holdUntilCompletion` owns it (no slot: `null`, or an error).
pub inline fn prepSlot(sqe: *SQE, buf_ptr: anytype) py.Error!?*c.io_uring_sqe {
    errdefer releaseOwned(buf_ptr);
    return try sqe.prepSlot(false) orelse {
        releaseOwned(buf_ptr);
        return null;
    };
}

/// Releases an owned buffer argument (optional or not) that did not go into a hold, in place: `deinit` copies
/// the view first, a store-forwarding stall (~10 ns, Setu's notes).
inline fn releaseOwned(buf: anytype) void {
    if (@typeInfo(@TypeOf(buf.*)) == .optional) {
        if (buf.*) |*b| sc.PyBuffer_Release(@constCast(&b.view));
    } else sc.PyBuffer_Release(@constCast(&buf.view));
}

/// Where a prep holds things: its ring's pending slot, or its template's entry (and the template).
const HoldPlace = struct { hold: *Ring.Hold, template: ?*Sqe = null };

/// Where a prep of `sqe` holds things, or nowhere (`null`).
inline fn holdOf(sqe: *SQE) py.Error!?HoldPlace {
    const ptr = sqe._sqe orelse return null;
    if (sqe._owner) |owner| {
        if (RingType.check(owner)) return .{ .hold = try RingType.data(owner).pendingFor(ptr) };
        if (SqeType.check(owner)) {
            const t = SqeType.data(owner);
            return .{ .hold = t.holdFor(ptr), .template = t };
        }
    }
    const self = SQEType.object(sqe);
    if (SqeType.check(self)) {
        const t = SqeType.data(self);
        return .{ .hold = t.holdFor(ptr), .template = t };
    }
    return null;
}

/// A path argument (`str` or `os.PathLike`, not `bytes`): `path` is the UTF-8 of
/// the `str` that `os.fspath` gives, so it stays valid while that `str` lives, past the call:
/// io_uring reads it at submit time, not when the `sqe` is prepared (`holdUntilCompletion` keeps `obj`).
///
/// Note
///      - `str` arguments (and `pathlib` paths, which cache their `str`) live as long as the
///        caller's object; `deinit` drops only the reference this took.
pub const Path = struct {
    obj: *Object,
    path: [:0]const u8,

    pub fn deinit(self: Path) void {
        py.decref(self.obj);
    }
};

extern fn PyOS_FSPath(*Object) ?*Object;

/// `obj` (`str` or `os.PathLike`) as a `Path`; `TypeError` for `bytes`. The caller calls `deinit`.
pub fn toPath(obj: *Object) py.Error!Path {
    if (sc.PyBytes_Check(obj) != 0) return py.raiseTypeError("expected `str` or `os.PathLike`, not `bytes`", .{});
    const text = PyOS_FSPath(obj) orelse return error.PythonError; // a new reference
    errdefer py.decref(text);
    if (sc.PyUnicode_Check(text) == 0) return py.raiseTypeError("expected `str` or `os.PathLike`, not `bytes`", .{});
    var len: sc.ssize = 0;
    const ptr = sc.PyUnicode_AsUTF8AndSize(text, &len) orelse return error.PythonError;
    return .{ .obj = text, .path = ptr[0..@intCast(len) :0] };
}

/// A prep's owned `buf` (`py.OwnedBuffer` / `py.OwnedWritableBuffer`) when a conversion fails before
/// `h.holdUntilCompletion` took it: released, `err` returned.
pub fn releaseFailed(buf: anytype, err: py.Error) py.Error {
    buf.deinit();
    return err;
}
