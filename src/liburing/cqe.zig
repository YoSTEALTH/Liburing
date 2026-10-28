//! Liburing - completion queue entries
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const setOwned = @import("class.zig").setOwned;
const claim = @import("class.zig").claim;
const raiseNotOwner = @import("class.zig").raiseNotOwner;
const keep = @import("class.zig").keep;
const pthread_self = @import("class.zig").pthread_self;
const RingType = @import("ring.zig").RingType;
const Ring = @import("ring.zig").Ring;
const ringOf = @import("ring.zig").ringOf;

const py = setu.py;
const Object = setu.c.Object;
pub const CQEType = setu.Class(CQE, @embedFile("cqe.zig"));
pub const CqeType = setu.Class(Cqe, @embedFile("cqe.zig"));
pub const CqeBatchType = setu.Class(CqeBatch, @embedFile("cqe.zig"));
pub const CqeBatchIterType = setu.Class(CqeBatchIter, @embedFile("cqe.zig"));
pub const CqeIterType = setu.Class(CqeIter, @embedFile("cqe.zig"));

/// Completion Queue Entry (CQE)
///
/// Example
///     >>> entry = cqe[0]
///     >>> entry.user_data, entry.res, entry.flags
///     (1, 0, 0)
///
/// Note
///     - Points into the ring's completion queue: `RuntimeError` once the ring has exited, and the entry is
///       only valid until `io_uring_cqe_seen` / `io_uring_cq_advance`.
pub const CQE = struct {
    _cqe: ?*c.io_uring_cqe = null,
    _owner: ?*Object = null, // the `Ring` whose completion queue `_cqe` points into
    _ring: ?*c.io_uring = null, // inside `_owner`
    _gen: u32 = 0, // `_owner`'s `_gen` when `_cqe` was set

    pub const instantiable = false;

    const Self = @This();

    // GET

    /// The entry for C, or `RuntimeError` once its ring has exited (its memory is unmapped), also when it
    /// was initialized again since.
    pub inline fn cqePtr(self: *const Self) py.Error!*c.io_uring_cqe {
        if (self._ring) |r| _ = try Ring.checkGen(r, self._gen);
        return self._cqe.?;
    }

    /// The `user_data` set on the request's `sqe` (an `int`): the kernel copies it into every completion of
    /// the request; a `io_uring_prep_msg_ring*` message carries the sender's `data` here.
    pub fn get_user_data(self: *const Self) py.Error!u64 {
        const kernel = (try self.cqePtr()).user_data;
        return if (self._ring) |r| ringOf(r).userData(kernel) else kernel;
    }

    /// The request's result: what the matching system call returns (bytes read or sent, a new file descriptor,
    /// `0`), or `-errno` for a failure (io_uring never sets `errno`); a negative one raises the `OSError` of that
    /// errno. `OSError: ECANCELED`: the request was cancelled, or an earlier request of its link chain failed.
    pub fn get_res(self: *const Self) py.Error!i32 {
        const res = (try self.cqePtr()).res;
        if (res >= 0) return res; // inline fast path: `checkErrno` is a call
        return py.checkErrno(res);
    }

    /// The completion's `IORING_CQE_F_*` flags.
    ///
    /// Flags
    ///     IORING_CQE_F_BUFFER         # A provided buffer was used: its id is flags >> IORING_CQE_BUFFER_SHIFT.
    ///     IORING_CQE_F_MORE           # More completions of this request follow (multishot, zero-copy send).
    ///     IORING_CQE_F_SOCK_NONEMPTY  # The socket still had data after this receive. 5.19+
    ///     IORING_CQE_F_NOTIF          # A zero-copy send's notification: its buffer may be reused now.
    ///     IORING_CQE_F_BUF_MORE       # The buffer is partly used, later completions continue in it.
    ///     IORING_CQE_F_SKIP           # A filler entry of an IORING_SETUP_CQE_MIXED ring: nothing to read.
    ///     IORING_CQE_F_32             # A 32-byte entry of an IORING_SETUP_CQE_MIXED ring (see big_cqe).
    ///
    /// Note
    ///     - A multishot request (accept, receive, read, poll, timeout) posts one completion per event with
    ///       `IORING_CQE_F_MORE`; the one without it is the last (an error, a cancel: `res` raises
    ///       `OSError: ECANCELED`, or no buffer left): re-arm it if wanted. The ring keeps the request's
    ///       `user_data` until that last one.
    ///     - A zero-copy send posts its result first (with `IORING_CQE_F_MORE`), then a notification with
    ///       `IORING_CQE_F_NOTIF` and the same `user_data` once the kernel is done with the buffer.
    ///     - `IORING_CQE_F_BUF_MORE` only comes from a buffer ring set up with `IOU_PBUF_RING_INC`: the buffer
    ///       returns to you when fully used, or on an error.
    pub fn get_flags(self: *const Self) py.Error!u32 {
        return (try self.cqePtr()).flags;
    }

    /// The 16 bytes after a 32-byte completion (a copy): every completion of an `IORING_SETUP_CQE32` ring,
    /// those with `IORING_CQE_F_32` of an `IORING_SETUP_CQE_MIXED` one. What the request put there (e.g.
    /// `IORING_OP_URING_CMD`); `None` for a 16-byte completion.
    ///
    /// Example
    ///     >>> cqe[0].big_cqe  # a NOP on an `IORING_SETUP_CQE32` ring
    ///     b'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
    pub fn get_big_cqe(self: *const Self) py.Error!?py.Bytes {
        const cqe = try self.cqePtr();
        const ring = self._ring orelse return null;
        const wide = ring.flags & c.IORING_SETUP_CQE32 != 0 or
            (ring.flags & c.IORING_SETUP_CQE_MIXED != 0 and cqe.flags & c.IORING_CQE_F_32 != 0);
        if (!wide) return null;
        const extra: [*]const u8 = @as([*]const u8, @ptrCast(cqe)) + @sizeOf(c.io_uring_cqe); // `big_cqe[]`
        return .{ .data = extra[0..16] };
    }
};

/// I/O completion data structure (Completion Queue Entry) (CQE)
///
/// Example
///     >>> cqe = Cqe()
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> ready = io_uring_cq_ready(ring)
///     >>> for i in range(ready):
///     ...     cqe[i].user_data  # do stuff
///     ...
///     1
///     2
///     >>> io_uring_cq_advance(ring, ready)  # free cqe already viewed.
///
/// Note
///     - `cqe` items e.g: `cqe[0], cqe[1], ...` are not cached (should be called/used only once) and
///     is very dynamic, so make copy if you want to keep data alive for longer use.
pub const Cqe = struct {
    _io_uring_cqe: ?[*]c.io_uring_cqe = null, // Note: Memory is managed by `io_uring`
    _ring: ?*Object = null, // the `Ring` `_io_uring_cqe` points into (set with it)
    _gen: u32 = 0, // `_ring`'s `_gen` when `_io_uring_cqe` was set
    /// `CQE`s handed out by `cqe[i]`, reused once nothing else holds them (see `__getitem__`).
    _reuse: [reuse_len]?*Object = @splat(null),
    /// `pthread_self()` of the thread that filled it first (`followRing`): the only one that may fill it, so two
    /// threads can not swap `_ring` (and `_reuse`) under each other. Reads go through the ring's own check. `0`: none
    /// yet.
    _thread: usize = 0,

    /// `entry = cqe[i]` in a loop still holds the previous entry while asking for the next one.
    const reuse_len = 4;

    /// Takes no arguments (`TypeError` for any). For batches of completions use `CqeBatch(no)`.
    pub fn __new__(_: *Cqe) void {}

    /// `False` until a wait or peek has set it to a completion.
    pub fn __bool__(self: *const Cqe) bool {
        return if (self._io_uring_cqe) |_| true else false;
    }

    /// The `cqe_ptr` argument for a liburing call on `ring` (Zig side): records the ring, so
    /// `cqe[i]` can follow its completion queue.
    pub fn outFor(self: *Cqe, ring: *Ring) py.Error!*?[*]c.io_uring_cqe {
        try self.followRing(RingType.object(ring));
        return &self._io_uring_cqe;
    }

    /// Records `ring_obj` (a `Ring`) and its generation, before `_io_uring_cqe` is set into its queue;
    /// `RuntimeError` from a thread that does not own the `Cqe` (`_thread`).
    pub inline fn followRing(self: *Cqe, ring_obj: *Object) py.Error!void {
        if (!claim(&self._thread, pthread_self())) return raiseNotOwner("Cqe", "wait or peek");
        setOwned(&self._ring, ring_obj);
        self._gen = RingType.data(ring_obj)._gen;
    }

    /// The ring `_io_uring_cqe` points into, or `RuntimeError` (`Ring.checkGen`).
    inline fn checkedRing(self: *const Cqe) py.Error!*c.io_uring {
        return Ring.checkGen(&RingType.data(self._ring.?)._io_uring, self._gen);
    }

    /// The `i`-th completion, as a `CQE`.
    ///
    /// Note
    ///     - `cqe[i]` is the `i`-th entry after `cqe[0]` in the ring's completion queue (wrapping
    ///       around its end); `IndexError` past the queue size.
    ///
    /// Type
    ///     return: CQE
    pub fn __getitem__(self: *Cqe, index: isize) py.Error!*Object {
        const first = self._io_uring_cqe orelse return py.raiseIndexError("`Cqe` - out of completed entries", .{});
        const ring_obj = self._ring.?;
        const ring = try self.checkedRing();
        const cq = &ring.cq;
        if (index < 0 or index >= cq.ring_entries) return py.raiseIndexError(
            "`Cqe[{d}]` - out of range, the ring has {d} completion entries",
            .{ index, cq.ring_entries },
        );
        const cqes: [*]c.io_uring_cqe = cq.cqes;
        const shift: u5 = @intCast(c.io_uring_cqe_shift(ring)); // cast: 0 or 1 (`IORING_SETUP_CQE32`)
        const slot = (@intFromPtr(first) - @intFromPtr(cqes)) / @sizeOf(c.io_uring_cqe);
        const pos = (((slot >> shift) + @as(usize, @intCast(index))) & cq.ring_mask) << shift; // cast: 0 <= index
        return self.entry(&cqes[pos], ring_obj, ring);
    }

    /// The `user_data` of `cqe[index]`, without creating an entry object.
    ///
    /// Example
    ///     >>> for i in range(io_uring_cq_ready(ring)):
    ///     ...     cqe.user_data_at(i)
    ///     ...
    ///     1
    ///     2
    pub fn user_data_at(self: *const Cqe, index: isize) py.Error!u64 {
        const kernel = (try self.slotPtr(index)).user_data;
        return RingType.data(self._ring.?).userData(kernel);
    }

    /// The `res` of `cqe[index]` (`OSError` if negative, as `CQE.res`), without creating an entry object.
    ///
    /// Example
    ///     >>> cqe.res_at(0)
    ///     0
    pub fn res_at(self: *const Cqe, index: isize) py.Error!i32 {
        const res = (try self.slotPtr(index)).res;
        if (res >= 0) return res;
        return py.checkErrno(res);
    }

    /// The `user_data` and `res` of `cqe[index]` in one call, without creating an entry object: a server's
    /// completion loop reads both. `res` is returned as is (a negative `-errno` for a failed request, no
    /// `OSError`), so the `user_data` of a failed request is not lost to an exception.
    ///
    /// Example
    ///     >>> cqe.user_data_res(0)
    ///     (1, 0)
    pub fn user_data_res(self: *const Cqe, index: isize) py.Error!struct { u64, i32 } {
        const cqe = try self.slotPtr(index);
        return .{ RingType.data(self._ring.?).userData(cqe.user_data), cqe.res };
    }

    /// The `index`-th completion after `cqe[0]` in the ring's queue (wrapping), checked like `__getitem__`.
    inline fn slotPtr(self: *const Cqe, index: isize) py.Error!*c.io_uring_cqe {
        const first = self._io_uring_cqe orelse return py.raiseIndexError("`Cqe` - out of completed entries", .{});
        const ring = try self.checkedRing();
        const cq = &ring.cq;
        if (index < 0 or index >= cq.ring_entries) return py.raiseIndexError(
            "`Cqe[{d}]` - out of range, the ring has {d} completion entries",
            .{ index, cq.ring_entries },
        );
        const cqes: [*]c.io_uring_cqe = cq.cqes;
        const shift: u5 = @intCast(c.io_uring_cqe_shift(ring)); // cast: 0 or 1 (`IORING_SETUP_CQE32`)
        const slot = (@intFromPtr(first) - @intFromPtr(cqes)) / @sizeOf(c.io_uring_cqe);
        const pos = (((slot >> shift) + @as(usize, @intCast(index))) & cq.ring_mask) << shift; // cast: 0 <= index
        return &cqes[pos];
    }

    /// A `CQE` for `cqe` (a new reference): a reused one that only `_reuse` holds (no one can see
    /// it change), else a new one, kept in `_reuse` if there is room.
    inline fn entry(self: *Cqe, cqe: *c.io_uring_cqe, ring_obj: *Object, ring: *c.io_uring) py.Error!*Object {
        for (&self._reuse) |*slot| {
            const o = slot.* orelse {
                const new = try CQEType.new(
                    .{ ._cqe = cqe, ._owner = keep(ring_obj), ._ring = ring, ._gen = self._gen },
                );
                slot.* = keep(new);
                return new;
            };
            if (Py_REFCNT(o) == 1) {
                const d = CQEType.data(o);
                d._cqe = cqe;
                setOwned(&d._owner, ring_obj);
                d._ring = ring;
                d._gen = self._gen;
                return keep(o);
            }
        }
        return CQEType.new(.{ ._cqe = cqe, ._owner = keep(ring_obj), ._ring = ring, ._gen = self._gen });
    }
};

/// Caller owned array of CQE pointers, filled by `io_uring_peek_batch_cqe`. `CqeBatch(no)` holds up to `no` of
/// them (`no` must be `> 0`, else `ValueError`); `len(batch)` is how many the last peek found.
///
/// Example
///     >>> batch = CqeBatch(64)
///     >>> n = io_uring_peek_batch_cqe(ring, batch)
///     >>> for cqe in batch:
///     ...     cqe.user_data, cqe.res
///     ...
///     (1, 0)
///     (2, 0)
///     >>> io_uring_cq_advance(ring, n)
///
/// Note
///     - Entries point into the ring, only valid until `io_uring_cq_advance`.
///     - Reusable: every peek overwrites previous entries.
pub const CqeBatch = struct {
    _array: ?[*]?*c.io_uring_cqe = null,
    _len: u32 = 0, // allocated slots
    _count: u32 = 0, // slots filled by last peek
    _ring: ?*Object = null, // the `Ring` the entries point into (set by `io_uring_peek_batch_cqe`)
    _gen: u32 = 0, // `_ring`'s `_gen` at that peek
    _thread: usize = 0, // `pthread_self()` of its first peek, the only thread that may fill it (`Cqe._thread`)

    const Self = @This();

    /// `RuntimeError` unless the calling thread owns it (or it has no owner yet: then it does).
    pub fn claimThread(self: *Self) py.Error!void {
        if (!claim(&self._thread, pthread_self())) return raiseNotOwner("CqeBatch", "peek");
    }

    /// `CqeBatch(no)`: room for `no` completions.
    pub fn __new__(self: *Self, no: u32) py.Error!void {
        if (no == 0) return py.raiseValueError("`CqeBatch(no)` - `no` must be > 0", .{});
        const array = std.heap.c_allocator.alloc(?*c.io_uring_cqe, no) catch return e.raiseMemoryError(
            "Out of Memory!",
        );
        self._array = array.ptr;
        self._len = no;
    }

    pub fn __del__(self: *Self) void {
        if (self._array) |array| std.heap.c_allocator.free(array[0..self._len]);
    }

    /// How many completions the last `io_uring_peek_batch_cqe` placed in it.
    pub fn __len__(self: *const Self) usize {
        return self._count;
    }

    /// The `index`-th completion of the last peek, as a `CQE` (`IndexError` past `len(batch)`).
    ///
    /// Type
    ///     return: CQE
    pub fn __getitem__(self: *const Self, index: isize) py.Error!*Object {
        if (index < 0 or index >= self._count) return py.raiseIndexError("`CqeBatch` - out of completed entries", .{});
        const ring_obj = self._ring.?;
        const ring = try Ring.checkGen(&RingType.data(ring_obj)._io_uring, self._gen);
        const cqe = self._array.?[@intCast(index)].?; // cast: checked
        return CQEType.new(.{ ._cqe = cqe, ._owner = keep(ring_obj), ._ring = ring, ._gen = self._gen });
    }

    /// A new iterator for each loop, so two loops over one batch don't interfere.
    ///
    /// Type
    ///     return: CqeBatchIter
    pub fn __iter__(self: *Object) py.Error!*Object {
        return CqeBatchIterType.new(.{ ._batch = keep(self) });
    }
};

/// Iterator over a `CqeBatch`'s entries, from `iter(batch)` (a `for` loop): its own position, so loops over
/// one batch don't interfere.
///
/// Example
///     >>> batch = CqeBatch(64)
///     >>> n = io_uring_peek_batch_cqe(ring, batch)
///     >>> [(a.user_data, b.user_data) for a in batch for b in batch]
///     [(1, 1), (1, 2), (2, 1), (2, 2)]
pub const CqeBatchIter = struct {
    _batch: ?*Object = null, // the `CqeBatch` iterated (owned)
    _index: u32 = 0, // the next entry

    pub const instantiable = false;

    const Self = @This();

    /// The next completion of the batch, as a `CQE`.
    ///
    /// Type
    ///     return: CQE
    pub fn __next__(self: *Self) py.Error!?*Object {
        const batch = CqeBatchType.data(self._batch.?);
        if (self._index >= batch._count) return null; // StopIteration
        defer self._index += 1;
        return try batch.__getitem__(self._index);
    }
};

/// Iterator over the ready completions of `ring`: each step sets `cqe[0]` to the next one and gives its index
/// (counted from `index`, default `0`).
///
/// Example
///     >>> for i in CqeIter(ring, cqe):
///     ...     i, cqe[0].user_data  # do stuff
///     ...
///     (0, 1)
///     (1, 2)
///     >>> io_uring_cq_advance(ring, 2)
///
/// Note
///     - Only `cqe[0]` gets updated with new completed entry value.
///     - Does not consume the completions: call `io_uring_cq_advance(ring, n)` afterwards.
pub const CqeIter = struct {
    _io_uring_cqe_iter: c.io_uring_cqe_iter = std.mem.zeroes(c.io_uring_cqe_iter),
    _index: usize = 0,
    _cqe: ?*Object = null, // the `Cqe` filled by `__next__` (owned)
    _ring: ?*Object = null, // the `Ring` the iterator reads (owned)
    _gen: u32 = 0, // `_ring`'s `_gen` when the iterator was made (it points into that queue)

    const Self = @This();

    /// `CqeIter(ring, cqe, index=None)`.
    pub fn __new__(self: *Self, ring: *Ring, cqe: *Cqe, index: ?usize) py.Error!void {
        self._io_uring_cqe_iter = c.io_uring_cqe_iter_init(try ring.checkedPtr());
        self._index = index orelse 0;
        self._cqe = keep(CqeType.object(cqe));
        self._ring = keep(RingType.object(ring));
        self._gen = ring._gen;
    }

    /// Sets `cqe[0]` to the next ready completion and returns its index; stops when none is left.
    pub fn __next__(self: *Self) py.Error!?usize {
        if (self._cqe) |o| {
            const _cqe = CqeType.data(o);
            if (self._ring) |r| {
                // the iterator reads its completion queue
                _ = try Ring.checkGen(&RingType.data(r)._io_uring, self._gen);
                try _cqe.followRing(r);
            }
            if (c.io_uring_cqe_iter_next(&self._io_uring_cqe_iter, &_cqe._io_uring_cqe)) {
                defer self._index += 1;
                return self._index;
            }
        }
        return null;
    }
};

/// `obj`'s reference count; a function in the stable ABI (abi3t too), right on 3.15t, unlike reading
/// `ob_refcnt`. (`PyUnstable_Object_IsUniquelyReferenced` is not in the stable ABI.)
extern fn Py_REFCNT(obj: *Object) isize;
