//! Liburing - submission queue entries
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const claim = @import("class.zig").claim;
const keep = @import("class.zig").keep;
const pthread_self = @import("class.zig").pthread_self;
const RingType = @import("ring.zig").RingType;
const Ring = @import("ring.zig").Ring;
const ringOf = @import("ring.zig").ringOf;

const py = setu.py;
const Object = setu.c.Object;
pub const SQEType = setu.Class(SQE, @embedFile("sqe.zig"));
pub const SqeType = setu.Class(Sqe, @embedFile("sqe.zig"));

/// Submission Queue Entry (SQE)
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_nop(sqe)
///     True
///     >>> sqe.user_data = 1
///     >>> sqe.opcode, sqe.flags
///     (0, 0)
///
/// Note
///     - Points into the ring's submission queue (or an `Sqe` template): `RuntimeError` once the ring has
///       exited or was initialized again.
pub const SQE = struct {
    _sqe: ?*c.io_uring_sqe = null, // `Sqe(ring)`: the slot of its last prep (`null`: none yet, or the queue was full)
    _owner: ?*Object = null, // keeps the memory `_sqe` points into alive (`Sqe` or `Ring`)
    _bound: bool = false, // `Sqe(ring)`: each prep takes the next slot of `_owner` (the `Ring`)
    _tail: u32 = 0, // `Sqe(ring)`: the ring's `sqe_tail` before the last prep took its slot (`undoSlot`)
    _gen: u32 = 0, // owned by a `Ring`: its `_gen` when `_sqe` was set

    pub const instantiable = false;
    pub const basetype = true; // `Sqe` / `Futex` subclass it

    const Self = @This();

    /// The entry for C, or `RuntimeError` once its ring has exited (its memory is unmapped), also when it
    /// was initialized again since, or for an `Sqe(ring)` without a slot (no prep yet, or the last one found
    /// the queue full). Inline: an out-of-line call returning an error union costs 3-5 ns here, the checks ~1.
    pub inline fn sqePtr(self: *const Self) py.Error!*c.io_uring_sqe {
        if (self._owner) |o| {
            if (RingType.check(o)) {
                _ = try Ring.checkGen(&RingType.data(o)._io_uring, self._gen);
            } else if (SqeType.check(o)) try SqeType.data(o).checkThread(); // a template's entry (`tmpl[i]`)
        } else {
            const obj = SQEType.object(@constCast(self));
            if (SqeType.check(obj)) try SqeType.data(obj).checkThread(); // a template itself
        }
        return self._sqe orelse raiseNoSlot();
    }

    noinline fn raiseNoSlot() py.Error {
        return py.raiseRuntimeError("`Sqe(ring)` has no entry: no prep yet, or the last one found the queue full", .{});
    }

    /// The entry a prep fills: an `Sqe(ring)` takes the ring's next free slot (`null`: the queue is full),
    /// `wide` a 128-byte one (`io_uring_get_sqe128`); any other its own entry (`sqePtr`). Pair it with
    /// `errdefer sqe.undoSlot()`: a prep that fails after this hands its slot back.
    pub inline fn prepSlot(self: *Self, comptime wide: bool) py.Error!?*c.io_uring_sqe {
        if (!self._bound) return try self.sqePtr();
        return self.takeRingSlot(wide);
    }

    inline fn takeRingSlot(self: *Self, comptime wide: bool) py.Error!?*c.io_uring_sqe {
        const ring = try RingType.data(self._owner.?).checkedPtr();
        self._gen = ringOf(ring)._gen; // a slot of this generation from here on (`null` too: `raiseNoSlot`)
        if (wide and ring.flags & (c.IORING_SETUP_SQE128 | c.IORING_SETUP_SQE_MIXED) == 0) return py.raiseValueError(
            "a 128-byte prep needs a ring set up with `IORING_SETUP_SQE128` or `IORING_SETUP_SQE_MIXED`",
            .{},
        );
        self._tail = ring.sq.sqe_tail;
        const s: *c.io_uring_sqe = (if (wide) c.io_uring_get_sqe128(ring) else c.io_uring_get_sqe(ring)) orelse retry: {
            if (!try ringOf(ring).autoSubmit()) break :retry null;
            break :retry if (wide) c.io_uring_get_sqe128(ring) else c.io_uring_get_sqe(ring);
        } orelse {
            self._sqe = null; // no stray writes through the properties
            return null;
        };
        s.user_data = 0; // `io_uring_get_sqe` keeps the slot's last value: a forgotten `user_data` would carry it
        self._sqe = s;
        return s;
    }

    /// Hands the slot `prepSlot` took back to its ring (an `Sqe(ring)` whose prep failed): the slot was not
    /// submitted yet, so moving the ring's `sqe_tail` back drops it, with what the prep held for it.
    pub inline fn undoSlot(self: *Self) void {
        if (self._bound) self.dropRingSlot();
    }

    fn dropRingSlot(self: *Self) void {
        const s = self._sqe orelse return;
        self._sqe = null;
        const ring = RingType.data(self._owner.?);
        ring._io_uring.sq.sqe_tail = self._tail;
        if (ring._pending != null) ring.pendingSlot(s).release();
    }

    // GET

    /// The `IORING_OP_*` the entry was prepped with.
    pub fn get_opcode(self: *const Self) py.Error!u8 {
        return (try self.sqePtr()).opcode;
    }

    /// The entry's `IOSQE_*` flags.
    ///
    /// Flags
    ///     IOSQE_FIXED_FILE        # fd is an index into the registered files (a direct descriptor). 5.1+
    ///     IOSQE_IO_DRAIN          # Starts after every earlier request completed; later ones wait for it. 5.2+
    ///     IOSQE_IO_LINK           # The next SQE starts only after this one completes (a chain). 5.3+
    ///     IOSQE_IO_HARDLINK       # IOSQE_IO_LINK that keeps the chain going after a failed result. 5.5+
    ///     IOSQE_ASYNC             # Hand to a worker thread at once, no non-blocking attempt first. 5.6+
    ///     IOSQE_BUFFER_SELECT     # Take a provided buffer of buf_group when the data is ready. 5.7+
    ///     IOSQE_CQE_SKIP_SUCCESS  # No completion when the request succeeds. 5.17+ (IORING_FEAT_CQE_SKIP)
    ///
    /// Note
    ///     - `IOSQE_IO_LINK`: a chain runs one request after the other and ends at the first SQE without the
    ///       flag; a submit ends it too (even if its last SQE has the flag). Any error or unexpected result (a
    ///       short read) breaks the chain: the requests not started yet complete with `OSError: ECANCELED`.
    ///       `IOSQE_IO_HARDLINK` implies `IOSQE_IO_LINK` and runs the rest anyway. Chains and single requests
    ///       outside them run in parallel.
    ///     - `IOSQE_BUFFER_SELECT`: the completion has `IORING_CQE_F_BUFFER` set and the buffer id in
    ///       `cqe.flags >> IORING_CQE_BUFFER_SHIFT`; `OSError: ENOBUFS` when the group is empty. A used buffer is
    ///       gone from the group until it is provided again.
    ///     - `IOSQE_CQE_SKIP_SUCCESS`: a failed request posts as usual, and without `IOSQE_IO_HARDLINK` the
    ///       linked ones after it post nothing. Not to be mixed with `IOSQE_IO_DRAIN` in one ring (the kernel
    ///       fails later drains). See `Ring` for what Liburing refuses at the submit.
    ///     - `IOSQE_FIXED_FILE` on an operation without fixed file support: `OSError: EBADF`.
    pub fn get_flags(self: *const Self) py.Error!u8 {
        return (try self.sqePtr()).flags;
    }

    /// The entry's I/O priority (`ioprio_set` values, for reads and writes). Network and accept requests reuse
    /// the field for their own flags (`IORING_RECVSEND_*`, `IORING_ACCEPT_*`), set by their preps.
    pub fn get_ioprio(self: *const Self) py.Error!u16 {
        return (try self.sqePtr()).ioprio;
    }

    /// The file descriptor the entry works on; with `IOSQE_FIXED_FILE` in `flags` the index of a registered file
    /// (a direct descriptor) instead.
    pub fn get_fd(self: *const Self) py.Error!i32 {
        return (try self.sqePtr()).fd;
    }

    /// The entry's `len` field (e.g. bytes to read, or number of `iovec`).
    pub fn get_len(self: *const Self) py.Error!u32 {
        return (try self.sqePtr()).len;
    }

    /// The `user_data` of the entry, given back as `cqe.user_data` in its completion(s): any 64-bit value, `0` and
    /// duplicates included (see `Ring`; after the submit this reads as the ring's index for it).
    pub fn get_user_data(self: *const Self) py.Error!u64 {
        return (try self.sqePtr()).user_data;
    }

    /// The registered personality id (`io_uring_register_personality`) whose credentials the request runs with
    /// (`0`: none, the submitting thread's; `IORING_FEAT_CUR_PERSONALITY`).
    pub fn get_personality(self: *const Self) py.Error!u16 {
        return (try self.sqePtr()).personality;
    }

    // SET

    /// Set the entry's `IOSQE_*` flags (replaces them, see `io_uring_sqe_set_flags`; the flags are described on
    /// the `flags` getter).
    pub fn set_flags(self: *Self, flags: u8) py.Error!void {
        (try self.sqePtr()).flags = flags;
    }

    /// Set the entry's `user_data` (an `int`, up to 64 bits). An entry from `io_uring_get_sqe` keeps the slot's
    /// last value until set; an `Sqe(ring)` prep starts it at `0`.
    pub fn set_user_data(self: *Self, data: u64) py.Error!void {
        (try self.sqePtr()).user_data = data;
    }
};

/// IO submission data structure (Submission Queue Entry) (SQE)
///
/// Type
///     no: int | Ring | None
///
/// Example
///     # `Sqe()` (`None`): one entry, a template `put_sqe` copies into the ring
///     >>> buf = bytearray(5)
///     >>> sqe = Sqe()                         # same as `Sqe(1)`
///     >>> io_uring_prep_read(sqe, fd, buf)
///     True
///     >>> sqe.user_data = 1
///     >>> put_sqe(ring, sqe)                  # *** MUST DO ***
///     True
///     >>> io_uring_submit(ring)
///     1
///
/// Example
///     # `Sqe(2)` (`int`): a block of entries, `sqe[0]` ... `sqe[1]`, put with one `put_sqe`
///     >>> buf = bytearray(5)
///     >>> sqe = Sqe(2)
///     >>> io_uring_prep_write(sqe[0], fd, b'hi...')
///     True
///     >>> sqe[0].user_data = 1
///     >>> io_uring_prep_read(sqe[1], fd, buf)
///     True
///     >>> sqe[1].user_data = 2
///     >>> put_sqe(ring, sqe)                  # *** MUST DO ***
///     True
///     >>> io_uring_submit(ring)
///     2
///
/// Example
///     # `Sqe(ring)` (`Ring`): bound to a ring, each prep takes the ring's next free entry
///     >>> buf = bytearray(5)
///     >>> sqe = Sqe(ring)
///     >>> io_uring_prep_read(sqe, fd, buf)    # entry 1
///     True
///     >>> sqe.user_data = 1                   # entry 1
///     >>> io_uring_prep_read(sqe, fd, buf)    # entry 2
///     True
///     >>> sqe.user_data = 2                   # entry 2
///     >>> io_uring_submit(ring)               # both, no `put_sqe`
///     2
///
/// Note
///     - This class has two usages:
///         1. `sqe = Sqe(<int>)`: rather than "get" sqe(s) you are going to "put" pre-made sqe(s)
///         into the ring later (templates). Refer to `help(put_sqe)` to see more detail.
///         2. `sqe = Sqe(ring)`: one object for the ring's lifetime, written straight into the ring's
///         submission queue: no `io_uring_get_sqe()`, no `put_sqe()`, no object per request.
///     - `io_uring_get_sqe()` returns an `SQE` (the ring's own entry), not an `Sqe`: the preps and
///     properties take either.
///     - `Sqe(no)`: `no` must be `> 0` (`RuntimeError`).
///     - `Sqe(ring)`: every prep takes the next free entry and returns `False` if the queue is full
///     (`io_uring_submit()` and prep again; `Ring(auto_submit=True)` does that for you);
///     `user_data` starts at `0`. Properties and
///     `io_uring_sqe_set_*` act on the entry of the last prep (`RuntimeError` before the first one, or
///     after a full queue). No `sqe[i]` (which entry is free depends on the kernel) and no `put_sqe()`.
pub const Sqe = struct {
    _len: usize = 0,
    _io_uring_sqe: ?[*]c.io_uring_sqe = null, // allocated here, `_len` entries
    /// What each entry's prep holds, for the template's lifetime (`put_sqe` copies hold the template).
    _holds: ?[*]Ring.Hold = null,
    _inflight: u32 = 0, // `put_sqe` copies of an entry that holds something, not released yet
    /// Holds a re-prep replaced while copies were in flight: released once `_inflight` is `0`.
    _retired: std.ArrayList(Ring.Hold) = .empty,
    /// `pthread_self()` of the first prep or `put_sqe`: copies are counted by the thread of their ring, so the
    /// template stays with it (`put_sqe` and preps from another thread: `RuntimeError`). `0`: none yet.
    _thread: usize = 0,

    pub const base = SQEType;

    const Self = @This();

    /// `Sqe(no=None)`: `no` entries (default `1`) to prep and `put_sqe` later, or a `Ring` to prep into.
    pub fn __new__(self: *Object, no: ?*Object) py.Error!void {
        const arg = if (no) |o| (if (o == py.none()) null else o) else null;
        if (arg) |o| if (RingType.check(o)) { // `Sqe(ring)`: no memory of its own, preps take the ring's slots
            const d = SQEType.data(self);
            d._owner = keep(o);
            d._bound = true;
            d._gen = RingType.data(o)._gen; // `RuntimeError` before the first prep is `raiseNoSlot`'s
            return;
        };
        const _no = if (arg) |o| try py.fromPython(usize, o) else 1; // no = null/None/1 == 1
        if (_no == 0) return py.raiseRuntimeError("New `Sqe()` class not created.", .{});
        const sqes = std.heap.c_allocator.alloc(c.io_uring_sqe, _no) catch return e.raiseMemoryError("out of memory!");
        @memset(sqes, std.mem.zeroes(c.io_uring_sqe));
        const holds = std.heap.c_allocator.alloc(Ring.Hold, _no) catch {
            // coverage-off: out of memory only
            std.heap.c_allocator.free(sqes);
            return e.raiseMemoryError("out of memory!");
            // coverage-on
        };
        @memset(holds, .{});
        const d = SqeType.data(self);
        d._len = _no;
        d._io_uring_sqe = sqes.ptr;
        d._holds = holds.ptr;
        SQEType.data(self)._sqe = &sqes[0]; // `sqe.user_data` is `sqe[0].user_data`
    }

    /// GC: the objects its entries hold (and the retired ones), so a cycle through one can be collected.
    pub fn __traverse__(self: *const Self, v: *setu.Visit) setu.Visit.Error!void {
        if (self._holds) |holds| for (holds[0..self._len]) |*hold| try hold.traverse(v);
        for (self._retired.items) |*hold| try hold.traverse(v);
    }

    /// GC breaking a cycle: releases what its entries hold, unless `put_sqe` copies are in flight (the kernel may
    /// still use it: their ring's `__clear__` drains them first, then this template's dealloc releases it).
    pub fn __clear__(self: *Self) void {
        if (self._inflight != 0) return;
        if (self._holds) |holds| for (holds[0..self._len]) |*hold| hold.release();
        self.releaseRetired();
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_sqe) |items| std.heap.c_allocator.free(items[0..self._len]);
        if (self._holds) |holds| {
            for (holds[0..self._len]) |*hold| hold.release();
            std.heap.c_allocator.free(holds[0..self._len]);
        }
        self.releaseRetired(); // no copy in flight: each holds the template
    }

    /// A copy's hold was released (its completion, or its slot re-prepped / drained).
    pub fn copyDone(self: *Self) void {
        self._inflight -= 1;
        if (self._inflight == 0) self.releaseRetired();
    }

    fn releaseRetired(self: *Self) void {
        var retired = self._retired;
        self._retired = .empty;
        for (retired.items) |*hold| hold.release();
        retired.deinit(std.heap.c_allocator);
    }

    /// `RuntimeError` unless the calling thread is the template's; with none yet, it becomes the template's
    /// (two threads prepping one template at once would replace and release the same holds).
    pub fn checkThread(self: *Self) py.Error!void {
        if (!claim(&self._thread, pthread_self())) return raiseTemplateThread();
    }

    /// `put_sqe` into a ring owned by `thread` (the calling one: the ring checked it): takes it as the template's,
    /// or `RuntimeError` for another one. No `pthread_self()` call.
    pub inline fn ownThread(self: *Self, thread: usize) py.Error!void {
        if (!claim(&self._thread, thread)) return raiseTemplateThread();
    }

    noinline fn raiseBound(comptime what: []const u8) py.Error {
        return py.raiseTypeError("`Sqe(ring)` " ++ what, .{});
    }

    noinline fn raiseTemplateThread() py.Error {
        return py.raiseRuntimeError(
            "`Sqe` template belongs to the thread of its first prep or `put_sqe` (its copies are counted there): " ++
                "use one per thread",
            .{},
        );
    }

    /// Puts `new` in the entry hold `target` (a prep): what it replaces is released, or retired while copies
    /// are in flight (the kernel may still use it through them).
    pub fn replaceHold(self: *Self, target: *Ring.Hold, new: Ring.Hold) py.Error!void {
        if (self._inflight != 0) self._retired.ensureUnusedCapacity(std.heap.c_allocator, 1) catch
            // coverage-off: out of memory only
            return e.raiseMemoryError("Out of Memory!");
        // coverage-on
        var old = target.*;
        target.* = new;
        if (old.isEmpty()) return;
        if (self._inflight != 0) self._retired.appendAssumeCapacity(old) else old.release();
    }

    /// The hold of the entry `sqe` points into.
    pub fn holdFor(self: *Self, sqe: *const c.io_uring_sqe) *Ring.Hold {
        const i = (@intFromPtr(sqe) - @intFromPtr(self._io_uring_sqe.?)) / @sizeOf(c.io_uring_sqe);
        return &self._holds.?[i];
    }

    /// `Sqe(ring)`: no length (its entries are the ring's free slots).
    pub fn __len__(self: *Object) py.Error!usize {
        if (SQEType.data(self)._bound) return raiseBound("has no length");
        return SqeType.data(self)._len;
    }

    /// Always `True`: an `Sqe` is bound to a ring or has at least one entry.
    pub fn __bool__(self: *Object) bool {
        return SQEType.data(self)._bound or SqeType.data(self)._len > 0;
    }

    /// The `index`-th entry of the template (`IndexError` out of range; `TypeError` for an `Sqe(ring)`).
    ///
    /// Type
    ///     return: SQE
    pub fn __getitem__(self: *Object, index: isize) py.Error!*Object {
        if (SQEType.data(self)._bound) return raiseBound("has no `sqe[i]`: each prep takes the next free entry");
        const d = SqeType.data(self);
        if (d._io_uring_sqe) |array| {
            if (index >= 0 and index < d._len) {
                return SQEType.new(.{ ._sqe = &array[@intCast(index)], ._owner = keep(self) }); // cast: checked
            }
        }
        return py.raiseIndexError("Index out of range", .{});
    }
};
