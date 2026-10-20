//! Liburing - io_uring related classes
const c = @import("c.zig").c;
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const linux = std.os.linux;

const py = setu.py;
const Object = setu.c.Object;
pub const IovecType = setu.Class(Iovec, @embedFile("class.zig"));
pub const TimespecType = setu.Class(Timespec, @embedFile("class.zig"));
pub const RingType = setu.Class(Ring, @embedFile("class.zig"));
pub const CQEType = setu.Class(CQE, @embedFile("class.zig"));
pub const CqeType = setu.Class(Cqe, @embedFile("class.zig"));
pub const CqeIterType = setu.Class(CqeIter, @embedFile("class.zig"));
pub const SQEType = setu.Class(SQE, @embedFile("class.zig"));
pub const SqeType = setu.Class(Sqe, @embedFile("class.zig"));
pub const ProbeType = setu.Class(Probe, @embedFile("class.zig"));
pub const ParamType = setu.Class(Param, @embedFile("class.zig"));
pub const RegWaitType = setu.Class(RegWait, @embedFile("class.zig"));
pub const RestrictionType = setu.Class(Restriction, @embedFile("class.zig"));
pub const BufRegType = setu.Class(BufReg, @embedFile("class.zig"));
pub const SyncCancelRegType = setu.Class(SyncCancelReg, @embedFile("class.zig"));
pub const NapiType = setu.Class(Napi, @embedFile("class.zig"));
pub const ZcrxIfqRegType = setu.Class(ZcrxIfqReg, @embedFile("class.zig"));
pub const ClockRegisterType = setu.Class(ClockRegister, @embedFile("class.zig"));
pub const BpfType = setu.Class(Bpf, @embedFile("class.zig"));
pub const SigsetTType = setu.Class(SigsetT, @embedFile("class.zig"));
pub const MemRegionRegType = setu.Class(MemRegionReg, @embedFile("class.zig"));
pub const BufRingType = setu.Class(BufRing, @embedFile("class.zig"));
pub const CmsghdrType = setu.Class(Cmsghdr, @embedFile("class.zig"));
pub const MsghdrType = setu.Class(Msghdr, @embedFile("class.zig"));
pub const EpollEventType = setu.Class(EpollEvent, @embedFile("class.zig"));
pub const RecvmsgOutType = setu.Class(RecvmsgOut, @embedFile("class.zig"));
pub const OpenHowType = setu.Class(OpenHow, @embedFile("class.zig"));

/// Vector I/O data structure
///
/// Example
///     # Read
///     # ----
///     >>> iov = Iovec([bytearray(1), bytearray(2), bytearray(3)])
///     >>> io_uring_prep_readv(sqe, fd, iov, ...)
///     ...
///     >>> iov.buffers
///     (bytearray(b"a"), bytearray(b"bc"), bytearray(b"def"))
///
///     # Write
///     # -----
///     >>> iov = Iovec([b"1", b"22", b"333"])
///     >>> io_uring_prep_writev(sqe, fd, iov, ...)
///
/// Note
///     - `Iovec` holds on to the buffers it is given, so there is no need for a separate variable;
///     `iov.buffers` / `iov[i]` give them back (e.g. to read what `io_uring_prep_readv` filled).
///     - Hold on to the `Iovec` itself until the request has completed.
pub const Iovec = struct {
    _len: usize = 0,
    _iovec: ?[*]c.iovec = null,
    _buffers: ?*Object = null, // the tuple of buffers the `iovec` points into (owned)

    const Self = @This();

    pub fn __new__(self: *Self, list: py.Sequence(py.Buffer)) py.Error!void {
        const _len = list.items.len;
        if (_len == 0) return py.raiseValueError("`Iovec(list)` - received `0` length sequence!", .{});
        if (_len > std.posix.IOV_MAX) {
            return py.raiseValueError(
                "`Iovec(data)` - length of {d} exceeds `IOV_MAX` limit set by OS of {d}",
                .{ _len, std.posix.IOV_MAX },
            );
        }

        const iovec = std.heap.c_allocator.alloc(c.iovec, _len) catch return e.raiseMemoryError("Out of Memory!");
        for (list.items, iovec) |item, *iov| {
            iov.iov_base = @ptrCast(@constCast(item.data.ptr));
            iov.iov_len = item.data.len;
        }
        self._len = _len;
        self._iovec = iovec.ptr;
        self._buffers = keep(list.tuple);
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    /// The buffers, as given (a `tuple`).
    ///
    /// Type
    ///     return: tuple[Buffer, ...]
    pub fn get_buffers(self: *const Self) py.Error!*Object {
        return keep(self._buffers orelse return py.raiseRuntimeError("`Iovec` not initialized!", .{}));
    }

    /// Type
    ///     return: Buffer
    pub fn __getitem__(self: *const Self, index: isize) py.Error!*Object {
        const tuple = self._buffers orelse return py.raiseRuntimeError("`Iovec` not initialized!", .{});
        if (index >= 0 and index < self._len) return keep(setu.c.PyTuple_GetItem(tuple, index).?);
        return py.raiseIndexError("Index out of range", .{});
    }

    pub fn __del__(self: *const Self) void {
        if (self._iovec) |iovec| std.heap.c_allocator.free(iovec[0..self._len]);
    }
};

/// Kernel Timespec
///
/// Example
///     >>> ts = timespec(2)
///     >>> ts.sec
///     2
///     >>> ts.nsec
///     0
///     >>> ts.sec = 1           # second
///     >>> ts.nsec = 500000000  # nanosecond
pub const Timespec = struct {
    _timespec: ?*c.__kernel_timespec = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *const Self) void {
        if (self._timespec) |ts| std.heap.c_allocator.destroy(ts);
    }

    // Get

    pub fn get_sec(self: *const Self) py.Error!i64 {
        if (self._timespec) |ts| return ts.tv_sec;
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    pub fn get_nsec(self: *const Self) py.Error!i64 {
        if (self._timespec) |ts| return ts.tv_nsec;
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    // Set

    pub fn set_sec(self: *const Self, value: i64) py.Error!void {
        if (self._timespec) |ts| {
            ts.tv_sec = value;
            return;
        }
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    pub fn set_nsec(self: *const Self, value: i64) py.Error!void {
        if (self._timespec) |ts| {
            ts.tv_nsec = value;
            return;
        }
        return e.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }
};

/// I/O URing
///
/// Example
///     >>> ring = Ring()
///     >>> io_uring_queue_init(8, ring)
///     >>> io_uring_queue_exit(ring)
pub const Ring = struct {
    _io_uring: c.io_uring = std.mem.zeroes(c.io_uring), // lives inside the Python object
    /// Objects the kernel still has to read (path strings, ...): a `list`, dropped once a submit has
    /// handed every SQE to the kernel (`releaseSubmitted`). See `keepUntilSubmit`.
    _keep: ?*Object = null,
    /// The `buf` of `io_uring_queue_init_mem`, locked until `io_uring_queue_exit`.
    _mem: ?py.WritableBuffer = null,

    pub fn __new__(_: *Ring) void {}

    /// The `io_uring` for C, or `RuntimeError` if the ring is not initialised (or already exited):
    /// liburing would read unmapped memory.
    pub fn checkedPtr(self: *Ring) py.Error!*c.io_uring {
        return checkRing(&self._io_uring);
    }

    /// `ring` (inside a `Ring`), or `RuntimeError` as `checkedPtr` does: for entries, which keep
    /// the pointer next to their owner to skip the `Ring` lookup.
    pub inline fn checkRing(ring: *c.io_uring) py.Error!*c.io_uring {
        if (ring.ring_fd <= 0) return raiseNotInitialized();
        return ring;
    }

    /// Out of line: keeps its message formatting off the hot paths that inline `checkRing`.
    noinline fn raiseNotInitialized() py.Error {
        return py.raiseRuntimeError(
            "`Ring` is not initialized (`io_uring_queue_init`) or already exited (`io_uring_queue_exit`)",
            .{},
        );
    }

    /// After a submit: drops `_keep` once the kernel has consumed every SQE (it read their paths then).
    pub fn releaseSubmitted(self: *Ring) void {
        if (self._keep == null or self._io_uring.ring_fd <= 0) return;
        if (c.io_uring_sq_ready(&self._io_uring) != 0) return; // not all consumed yet (`SQPOLL`)
        const list = self._keep;
        self._keep = null;
        py.decref(list);
    }

    pub fn get_flags(self: *const Ring) u32 {
        return self._io_uring.flags;
    }

    pub fn get_ring_fd(self: *const Ring) i32 {
        return self._io_uring.ring_fd;
    }

    pub fn get_features(self: *const Ring) u32 {
        return self._io_uring.features;
    }

    pub fn get_int_flags(self: *const Ring) u8 {
        return self._io_uring.int_flags;
    }

    pub fn get_enter_ring_fd(self: *const Ring) i32 {
        return self._io_uring.enter_ring_fd;
    }
};

/// Completion Queue Entry (CQE)
pub const CQE = struct {
    _cqe: ?*c.io_uring_cqe = null,
    _owner: ?*Object = null, // the `Ring` whose completion queue `_cqe` points into
    _ring: ?*c.io_uring = null, // inside `_owner`

    pub const instantiable = false;

    const Self = @This();

    // GET

    /// The entry for C, or `RuntimeError` once its ring has exited (its memory is unmapped).
    pub inline fn cqePtr(self: *const Self) py.Error!*c.io_uring_cqe {
        if (self._ring) |r| _ = try Ring.checkRing(r);
        return self._cqe.?;
    }

    pub fn get_user_data(self: *const Self) py.Error!u64 {
        return (try self.cqePtr()).user_data;
    }

    pub fn get_res(self: *const Self) py.Error!i32 {
        const res = (try self.cqePtr()).res;
        if (res >= 0) return res; // inline fast path: `checkErrno` is a call
        return py.checkErrno(res);
    }

    pub fn get_flags(self: *const Self) py.Error!u32 {
        return (try self.cqePtr()).flags;
    }

    pub fn get_big_cqe(_: *const Self) py.Error!void {
        return py.raiseRuntimeError("`.big_cqe` not implemented!", .{});
        // TODO: big_cqe: [16]u8, // when `IORING_SETUP_CQE32` is enabled.
    }
};

/// I/O completion data structure (Completion Queue Entry) (CQE)
///
/// Example
///     >>> cqe = Cqe()
///     ...
///     >>> io_uring_wait_cqe(ring, cqe)
///     >>> ready = io_uring_cq_ready(ring)
///
///     >>> for i in range(ready):
///     ...     cqe[i] # do stuff
///
///     >>> io_uring_cq_advance(ready) # free cqe already viewed.
///
/// Note
///     - `cqe` items e.g: `cqe[0], cqe[1], ...` are not cached (should be called/used only once) and
///     is very dynamic, so make copy if you want to keep data alive for longer use.
pub const Cqe = struct {
    // TODO:
    // _array: ?[*]CQE = null, // custom memory for batch cqe
    _io_uring_cqe: ?[*]c.io_uring_cqe = null, // Note: Memory is managed by `io_uring`
    _ring: ?*Object = null, // the `Ring` `_io_uring_cqe` points into (set with it)
    /// `CQE`s handed out by `cqe[i]`, reused once nothing else holds them (see `__getitem__`).
    _reuse: [reuse_len]?*Object = @splat(null),

    /// `entry = cqe[i]` in a loop still holds the previous entry while asking for the next one.
    const reuse_len = 4;

    pub fn __new__(_: *Cqe, no: ?u32) py.Error!void {
        // TODO: `no` is need to get `io_uring_peek_batch_cqe` working
        if (no) |_| return py.raiseNotImplementedError("`Cqe(no)` - Custom memory allocation not coded yet!", .{});
    }

    pub fn __bool__(self: *const Cqe) bool {
        return if (self._io_uring_cqe) |_| true else false;
    }

    /// The `cqe_ptr` argument for a liburing call on `ring` (Zig side): records the ring, so
    /// `cqe[i]` can follow its completion queue.
    pub fn outFor(self: *Cqe, ring: *Ring) *?[*]c.io_uring_cqe {
        setOwned(&self._ring, RingType.object(ring));
        return &self._io_uring_cqe;
    }

    /// Note
    ///     - `cqe[i]` is the `i`-th entry after `cqe[0]` in the ring's completion queue (wrapping
    ///       around its end); `IndexError` past the queue size.
    ///
    /// Type
    ///     return: CQE
    pub fn __getitem__(self: *Cqe, index: isize) py.Error!*Object {
        const first = self._io_uring_cqe orelse return py.raiseIndexError("`Cqe` - out of completed entries", .{});
        const ring_obj = self._ring.?;
        const ring = try RingType.data(ring_obj).checkedPtr();
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
    pub fn user_data_at(self: *const Cqe, index: isize) py.Error!u64 {
        return (try self.slotPtr(index)).user_data;
    }

    /// The `res` of `cqe[index]` (`OSError` if negative, as `CQE.res`), without creating an entry object.
    pub fn res_at(self: *const Cqe, index: isize) py.Error!i32 {
        const res = (try self.slotPtr(index)).res;
        if (res >= 0) return res;
        return py.checkErrno(res);
    }

    /// The `index`-th completion after `cqe[0]` in the ring's queue (wrapping), checked like `__getitem__`.
    inline fn slotPtr(self: *const Cqe, index: isize) py.Error!*c.io_uring_cqe {
        const first = self._io_uring_cqe orelse return py.raiseIndexError("`Cqe` - out of completed entries", .{});
        const ring = try RingType.data(self._ring.?).checkedPtr();
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
    fn entry(self: *Cqe, cqe: *c.io_uring_cqe, ring_obj: *Object, ring: *c.io_uring) py.Error!*Object {
        for (&self._reuse) |*slot| {
            const o = slot.* orelse {
                const new = try CQEType.new(.{ ._cqe = cqe, ._owner = keep(ring_obj), ._ring = ring });
                slot.* = keep(new);
                return new;
            };
            if (PyUnstable_Object_IsUniquelyReferenced(o) != 0) {
                const d = CQEType.data(o);
                d._cqe = cqe;
                setOwned(&d._owner, ring_obj);
                d._ring = ring;
                return keep(o);
            }
        }
        return CQEType.new(.{ ._cqe = cqe, ._owner = keep(ring_obj), ._ring = ring });
    }
};

/// Example
///     >>> for i in CqeIter(ring, cqe):
///     ...     cqe[0].user_data == i  # do stuff
///
/// Note
///     - Only `cqe[0]` gets updated with new completed entry value.
pub const CqeIter = struct {
    _io_uring_cqe_iter: c.io_uring_cqe_iter = std.mem.zeroes(c.io_uring_cqe_iter),
    _index: usize = 0,
    _cqe: ?*Object = null, // the `Cqe` filled by `__next__` (owned)
    _ring: ?*Object = null, // the `Ring` the iterator reads (owned)

    const Self = @This();

    pub fn __new__(self: *Self, ring: *Ring, cqe: *Cqe, index: ?usize) py.Error!void {
        self._io_uring_cqe_iter = c.io_uring_cqe_iter_init(try ring.checkedPtr());
        self._index = index orelse 0;
        self._cqe = keep(CqeType.object(cqe));
        self._ring = keep(RingType.object(ring));
    }

    pub fn __next__(self: *Self) ?usize {
        if (self._cqe) |o| {
            const _cqe = CqeType.data(o);
            if (self._ring) |r| setOwned(&_cqe._ring, r);
            if (c.io_uring_cqe_iter_next(&self._io_uring_cqe_iter, &_cqe._io_uring_cqe)) {
                defer self._index += 1;
                return self._index;
            }
        }
        return null;
    }
};

/// Submission Queue Entry (SQE)
pub const SQE = struct {
    _sqe: ?*c.io_uring_sqe = null,
    _owner: ?*Object = null, // keeps the memory `_sqe` points into alive (`Sqe` or `Ring`)

    pub const instantiable = false;
    pub const basetype = true; // `Sqe` / `Futex` subclass it

    const Self = @This();

    /// The entry for C, or `RuntimeError` once its ring has exited (its memory is unmapped).
    pub fn sqePtr(self: *const Self) py.Error!*c.io_uring_sqe {
        if (self._owner) |o| if (RingType.check(o)) {
            _ = try RingType.data(o).checkedPtr();
        };
        return self._sqe.?;
    }

    // GET

    pub fn get_opcode(self: *const Self) py.Error!u8 {
        return (try self.sqePtr()).opcode;
    }

    pub fn get_flags(self: *const Self) py.Error!u8 {
        return (try self.sqePtr()).flags;
    }

    pub fn get_ioprio(self: *const Self) py.Error!u16 {
        return (try self.sqePtr()).ioprio;
    }

    pub fn get_fd(self: *const Self) py.Error!i32 {
        return (try self.sqePtr()).fd;
    }

    pub fn get_len(self: *const Self) py.Error!u32 {
        return (try self.sqePtr()).len;
    }

    pub fn get_user_data(self: *const Self) py.Error!u64 {
        return (try self.sqePtr()).user_data;
    }

    pub fn get_personality(self: *const Self) py.Error!u16 {
        return (try self.sqePtr()).personality;
    }

    // SET

    pub fn set_flags(self: *Self, flags: u8) py.Error!void {
        (try self.sqePtr()).flags = flags;
    }

    pub fn set_user_data(self: *Self, data: u64) py.Error!void {
        (try self.sqePtr()).user_data = data;
    }
};

/// IO submission data structure (Submission Queue Entry) (SQE)
///
/// Example
///     # single
///     >>> sqe = Sqe()  # defaults to `Sqe(1)`
///     >>> io_uring_prep_read(sqe, ...)
///     >>> sqe.user_data = 1
///
///     # multiple
///     >>> sqe = Sqe(2)
///     >>> io_uring_prep_write(sqe[0], ...)
///     >>> sqe[0].user_data = 1
///     >>> io_uring_prep_read(sqe[1], ...)
///     >>> sqe[1].user_data = 2
///
///     # *** MUST DO ***
///     >>> if put_sqe(ring, sqe):
///     ...     io_uring_submit(ring)
///
/// Note
///     - This class has dual usage:
///         1. It works as a base class for `io_uring_get_sqe()` return.
///         2. It can also be used as `sqe = Sqe(<int>)`, rather than "get" sqe(s)
///         you are going to "put" pre-made sqe(s) into the ring later. Refer to
///         `help(put_sqe)` to see more detail.
///     - `Sqe(no)` is limited to max `0-255` items.
pub const Sqe = struct {
    _len: usize = 0,
    _io_uring_sqe: ?[*]c.io_uring_sqe = null, // allocated here, `_len` entries
    /// Like `Ring._keep`, for entries prepared here: `put_sqe` hands them to the ring.
    _keep: ?*Object = null,

    pub const base = SQEType;

    const Self = @This();

    pub fn __new__(self: *Object, no: ?usize) py.Error!void {
        const _no = no orelse 1; // no = null/None/1 == 1
        if (_no == 0) return py.raiseRuntimeError("New `Sqe()` class not created.", .{});
        const sqes = std.heap.c_allocator.alloc(c.io_uring_sqe, _no) catch return e.raiseMemoryError("out of memory!");
        @memset(sqes, std.mem.zeroes(c.io_uring_sqe));
        const d = SqeType.data(self);
        d._len = _no;
        d._io_uring_sqe = sqes.ptr;
        SQEType.data(self)._sqe = &sqes[0]; // `sqe.user_data` is `sqe[0].user_data`
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_sqe) |items| std.heap.c_allocator.free(items[0..self._len]);
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    /// Type
    ///     return: SQE
    pub fn __getitem__(self: *Object, index: isize) py.Error!*Object {
        const d = SqeType.data(self);
        if (d._io_uring_sqe) |array| {
            if (index >= 0 and index < d._len) {
                return SQEType.new(.{ ._sqe = &array[@intCast(index)], ._owner = keep(self) }); // cast: checked
            }
        }
        return py.raiseIndexError("Index out of range", .{});
    }
};

pub const Probe = struct {
    _io_uring_probe: ?*c.io_uring_probe = null,

    const Self = @This();

    pub fn __new__(_: *Self) py.Error!void {
        return py.raiseNotImplementedError("`Probe()`", .{});
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_probe) |p| c.io_uring_free_probe(p); // clean up in case user forgot to do so!
    }

    pub fn get_last_op(self: *const Self) py.Error!u8 {
        if (self._io_uring_probe) |p| return p.last_op;
        return e.raiseMemoryError("`Probe()` is null!");
    }

    pub fn get_ops_len(self: *const Self) py.Error!u8 {
        if (self._io_uring_probe) |p| return p.ops_len;
        return e.raiseMemoryError("`Probe()` is null!");
    }
};

pub const Param = struct {
    _io_uring_params: c.io_uring_params = std.mem.zeroes(c.io_uring_params), // lives inside the Python object

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_sq_entries(self: *const Self) u32 {
        return self._io_uring_params.sq_entries;
    }

    pub fn set_sq_entries(self: *Self, value: u32) void {
        self._io_uring_params.sq_entries = value;
    }

    pub fn get_cq_entries(self: *const Self) u32 {
        return self._io_uring_params.cq_entries;
    }

    pub fn set_cq_entries(self: *Self, value: u32) void {
        self._io_uring_params.cq_entries = value;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_params.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_params.flags = value;
    }

    pub fn get_sq_thread_cpu(self: *const Self) u32 {
        return self._io_uring_params.sq_thread_cpu;
    }

    pub fn set_sq_thread_cpu(self: *Self, value: u32) void {
        self._io_uring_params.sq_thread_cpu = value;
    }

    pub fn get_sq_thread_idle(self: *const Self) u32 {
        return self._io_uring_params.sq_thread_idle;
    }

    pub fn set_sq_thread_idle(self: *Self, value: u32) void {
        self._io_uring_params.sq_thread_idle = value;
    }

    pub fn get_features(self: *const Self) u32 {
        return self._io_uring_params.features;
    }

    pub fn get_wq_fd(self: *const Self) u32 {
        return self._io_uring_params.wq_fd;
    }

    pub fn set_wq_fd(self: *Self, value: u32) void {
        self._io_uring_params.wq_fd = value;
    }
};

/// `ts` of a kernel timespec as seconds: `None` for the "no timeout" value (negative).
fn timeoutSeconds(ts: c.__kernel_timespec) ?f64 {
    if (ts.tv_sec < 0 or ts.tv_nsec < 0) return null;
    return @as(f64, @floatFromInt(ts.tv_sec)) + @as(f64, @floatFromInt(ts.tv_nsec)) / 1e9;
}

/// Seconds (or `None` for no timeout) as a kernel timespec.
fn secondsTimeout(value: ?f64) py.Error!c.__kernel_timespec {
    const v = value orelse return .{ .tv_sec = -1, .tv_nsec = -1 };
    if (!(v >= 0) or v > 1e15) return py.raiseValueError("a timeout must be 0 .. 1e15 seconds, or None", .{});
    const whole = @floor(v);
    return .{ .tv_sec = @intFromFloat(whole), .tv_nsec = @intFromFloat(@round((v - whole) * 1e9)) };
}

/// One wait argument (`struct io_uring_reg_wait`), for `io_uring_submit_and_wait_reg`: it is copied into a memory
/// region registered with `IORING_MEM_REGION_REG_WAIT_ARG` (see `MemRegionReg`), at `index * RegWait.SIZE`.
///
/// Example
///     >>> mem = mmap.mmap(-1, 4096)
///     >>> region = MemRegionReg()
///     >>> region.flags = IORING_MEM_REGION_REG_WAIT_ARG
///     >>> region.region_user_addr = address_of(mem)
///     >>> region.region_size = len(mem)
///     >>> region.region_flags = IORING_MEM_REGION_TYPE_USER
///     >>> io_uring_register_region(ring, region)
///
///     >>> wait = RegWait()
///     >>> wait.timeout = 0.5            # seconds, `None` for none
///     >>> wait.flags = IORING_REG_WAIT_TS
///     >>> mem[0 : RegWait.SIZE] = wait.to_bytes()
///     >>> io_uring_submit_and_wait_reg(ring, cqe, 1, 0)   # the wait argument at index 0
///
/// Note
///     - `io_uring_register_wait_reg` is gone from the kernel interface: C liburing always answers `EINVAL`.
pub const RegWait = struct {
    _io_uring_reg_wait: c.io_uring_reg_wait = std.mem.zeroes(c.io_uring_reg_wait),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// The size in bytes of one entry in the registered region.
    pub const SIZE: usize = @sizeOf(c.io_uring_reg_wait);

    /// The entry as bytes (`RegWait.SIZE` of them) to copy into the registered memory region.
    pub fn to_bytes(self: *const Self) py.Bytes {
        const raw: *const [@sizeOf(c.io_uring_reg_wait)]u8 = @ptrCast(&self._io_uring_reg_wait);
        return .{ .data = raw };
    }

    /// The wait time in seconds (`None` for none); needs `IORING_REG_WAIT_TS` in `flags`.
    pub fn get_timeout(self: *const Self) ?f64 {
        return timeoutSeconds(self._io_uring_reg_wait.ts);
    }

    pub fn set_timeout(self: *Self, value: ?f64) py.Error!void {
        self._io_uring_reg_wait.ts = try secondsTimeout(value);
    }

    pub fn get_min_wait_usec(self: *const Self) u32 {
        return self._io_uring_reg_wait.min_wait_usec;
    }

    pub fn set_min_wait_usec(self: *Self, value: u32) void {
        self._io_uring_reg_wait.min_wait_usec = value;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_reg_wait.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_reg_wait.flags = value;
    }
};

/// What a ring set up with `IORING_SETUP_R_DISABLED` may do once `io_uring_enable_rings` is called.
///
/// Example
///     >>> res = Restriction()
///     >>> res.add(IORING_RESTRICTION_SQE_OP, IORING_OP_NOP)
///     >>> res.add(IORING_RESTRICTION_SQE_FLAGS_ALLOWED, IOSQE_IO_LINK)
///     >>> io_uring_register_restrictions(ring, res)
///     >>> io_uring_enable_rings(ring)
pub const Restriction = struct {
    _len: usize = 0,
    _io_uring_restriction: ?[*]c.io_uring_restriction = null,
    _capacity: usize = 0,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// Allows `value` for `opcode` (`IORING_RESTRICTION_*`): an sqe opcode, register opcode or sqe flags.
    pub fn add(self: *Self, opcode: u16, value: u8) py.Error!void {
        if (self._len == self._capacity) {
            const cap = if (self._capacity == 0) 4 else self._capacity * 2;
            const old: []c.io_uring_restriction = if (self._io_uring_restriction) |ptr| ptr[0..self._capacity] else &.{};
            const grown = std.heap.c_allocator.realloc(old, cap) catch return e.raiseMemoryError("Out of Memory!");
            self._io_uring_restriction = grown.ptr;
            self._capacity = cap;
        }
        const item = &self._io_uring_restriction.?[self._len];
        item.* = std.mem.zeroes(c.io_uring_restriction);
        item.opcode = opcode;
        item.unnamed_0.register_op = value; // the union shares one byte for register_op / sqe_op / sqe_flags
        self._len += 1;
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_restriction) |ptr| std.heap.c_allocator.free(ptr[0..self._capacity]);
    }
};

/// Registration of a buffer ring you set up yourself (`io_uring_register_buf_ring`); `io_uring_setup_buf_ring`
/// does this for you.
///
/// Example
///     >>> reg = BufReg()
///     >>> reg.ring_addr = address_of_16_bytes_per_entry_memory
///     >>> reg.ring_entries = 8
///     >>> reg.bgid = 1
///     >>> io_uring_register_buf_ring(ring, reg)
pub const BufReg = struct {
    _io_uring_buf_reg: c.io_uring_buf_reg = std.mem.zeroes(c.io_uring_buf_reg),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_ring_addr(self: *const Self) u64 {
        return self._io_uring_buf_reg.ring_addr;
    }

    pub fn set_ring_addr(self: *Self, value: u64) void {
        self._io_uring_buf_reg.ring_addr = value;
    }

    pub fn get_ring_entries(self: *const Self) u32 {
        return self._io_uring_buf_reg.ring_entries;
    }

    pub fn set_ring_entries(self: *Self, value: u32) void {
        self._io_uring_buf_reg.ring_entries = value;
    }

    pub fn get_bgid(self: *const Self) u16 {
        return self._io_uring_buf_reg.bgid;
    }

    pub fn set_bgid(self: *Self, value: u16) void {
        self._io_uring_buf_reg.bgid = value;
    }

    pub fn get_flags(self: *const Self) u16 {
        return self._io_uring_buf_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u16) void {
        self._io_uring_buf_reg.flags = value;
    }

    pub fn get_min_left(self: *const Self) u32 {
        return self._io_uring_buf_reg.min_left;
    }

    pub fn set_min_left(self: *Self, value: u32) void {
        self._io_uring_buf_reg.min_left = value;
    }
};

/// What `io_uring_register_sync_cancel` cancels: by `addr` (user_data), `fd`, or both with `flags`.
///
/// Example
///     >>> reg = SyncCancelReg()
///     >>> reg.addr = 123                      # the user_data of the request
///     >>> reg.timeout = 1.0                   # seconds to wait (default: until done)
///     >>> io_uring_register_sync_cancel(ring, reg)
pub const SyncCancelReg = struct {
    _io_uring_sync_cancel_reg: c.io_uring_sync_cancel_reg = std.mem.zeroes(c.io_uring_sync_cancel_reg),

    pub fn __new__(self: *Self) void { // no arguments: `TypeError` for any
        self._io_uring_sync_cancel_reg.timeout = .{ .tv_sec = -1, .tv_nsec = -1 }; // no timeout
        self._io_uring_sync_cancel_reg.fd = -1;
    }
    const Self = @This();

    pub fn get_addr(self: *const Self) u64 {
        return self._io_uring_sync_cancel_reg.addr;
    }

    pub fn set_addr(self: *Self, value: u64) void {
        self._io_uring_sync_cancel_reg.addr = value;
    }

    pub fn get_fd(self: *const Self) i32 {
        return self._io_uring_sync_cancel_reg.fd;
    }

    pub fn set_fd(self: *Self, value: i32) void {
        self._io_uring_sync_cancel_reg.fd = value;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_sync_cancel_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_sync_cancel_reg.flags = value;
    }

    pub fn get_opcode(self: *const Self) u8 {
        return self._io_uring_sync_cancel_reg.opcode;
    }

    pub fn set_opcode(self: *Self, value: u8) void {
        self._io_uring_sync_cancel_reg.opcode = value;
    }

    /// Seconds to wait for the cancellation (`None` for no limit).
    pub fn get_timeout(self: *const Self) ?f64 {
        return timeoutSeconds(self._io_uring_sync_cancel_reg.timeout);
    }

    pub fn set_timeout(self: *Self, value: ?f64) py.Error!void {
        self._io_uring_sync_cancel_reg.timeout = try secondsTimeout(value);
    }
};

/// Busy polling of the network device for a ring (`io_uring_register_napi`; the old settings are written back).
///
/// Example
///     >>> napi = Napi()
///     >>> napi.busy_poll_to = 50      # microseconds
///     >>> napi.prefer_busy_poll = True
///     >>> io_uring_register_napi(ring, napi)
pub const Napi = struct {
    _io_uring_napi: c.io_uring_napi = std.mem.zeroes(c.io_uring_napi),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_busy_poll_to(self: *const Self) u32 {
        return self._io_uring_napi.busy_poll_to;
    }

    pub fn set_busy_poll_to(self: *Self, value: u32) void {
        self._io_uring_napi.busy_poll_to = value;
    }

    pub fn get_prefer_busy_poll(self: *const Self) bool {
        return self._io_uring_napi.prefer_busy_poll != 0;
    }

    pub fn set_prefer_busy_poll(self: *Self, value: bool) void {
        self._io_uring_napi.prefer_busy_poll = @intFromBool(value);
    }
};

/// Zero-copy receive queue registration (`io_uring_register_ifq`); needs a network device that supports it.
///
/// Example
///     >>> reg = ZcrxIfqReg()
///     >>> reg.if_idx = socket.if_nametoindex("eth0")
///     >>> reg.if_rxq = 0
///     >>> reg.rq_entries = 4096
///     >>> reg.area_addr, reg.area_len = address_of(mem), len(mem)
///     >>> reg.region_user_addr, reg.region_size = address_of(rq), len(rq)
///     >>> io_uring_register_ifq(ring, reg)
///     >>> reg.zcrx_id
pub const ZcrxIfqReg = struct {
    _io_uring_zcrx_ifq_reg: c.io_uring_zcrx_ifq_reg = std.mem.zeroes(c.io_uring_zcrx_ifq_reg),
    _area: c.io_uring_zcrx_area_reg = std.mem.zeroes(c.io_uring_zcrx_area_reg), // what `area_ptr` points to
    _region: c.io_uring_region_desc = std.mem.zeroes(c.io_uring_region_desc), // what `region_ptr` points to

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_if_idx(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.if_idx;
    }

    pub fn set_if_idx(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.if_idx = value;
    }

    pub fn get_if_rxq(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.if_rxq;
    }

    pub fn set_if_rxq(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.if_rxq = value;
    }

    pub fn get_rq_entries(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.rq_entries;
    }

    pub fn set_rq_entries(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.rq_entries = value;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.flags = value;
    }

    pub fn get_rx_buf_len(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.rx_buf_len;
    }

    pub fn set_rx_buf_len(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.rx_buf_len = value;
    }

    pub fn get_zcrx_id(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.zcrx_id;
    }

    pub fn get_area_addr(self: *const Self) u64 {
        return self._area.addr;
    }

    pub fn set_area_addr(self: *Self, value: u64) void {
        self._area.addr = value;
    }

    pub fn get_area_len(self: *const Self) u64 {
        return self._area.len;
    }

    pub fn set_area_len(self: *Self, value: u64) void {
        self._area.len = value;
    }

    pub fn get_area_flags(self: *const Self) u32 {
        return self._area.flags;
    }

    pub fn set_area_flags(self: *Self, value: u32) void {
        self._area.flags = value;
    }

    pub fn get_area_dmabuf_fd(self: *const Self) u32 {
        return self._area.dmabuf_fd;
    }

    pub fn set_area_dmabuf_fd(self: *Self, value: u32) void {
        self._area.dmabuf_fd = value;
    }

    pub fn get_area_rq_area_token(self: *const Self) u64 {
        return self._area.rq_area_token;
    }

    pub fn get_region_user_addr(self: *const Self) u64 {
        return self._region.user_addr;
    }

    pub fn set_region_user_addr(self: *Self, value: u64) void {
        self._region.user_addr = value;
    }

    pub fn get_region_size(self: *const Self) u64 {
        return self._region.size;
    }

    pub fn set_region_size(self: *Self, value: u64) void {
        self._region.size = value;
    }

    pub fn get_region_flags(self: *const Self) u32 {
        return self._region.flags;
    }

    pub fn set_region_flags(self: *Self, value: u32) void {
        self._region.flags = value;
    }
};

/// The clock a ring uses for waiting with timeouts (`io_uring_register_clock`).
///
/// Example
///     >>> reg = ClockRegister()
///     >>> reg.clockid = time.CLOCK_BOOTTIME
///     >>> io_uring_register_clock(ring, reg)
pub const ClockRegister = struct {
    _io_uring_clock_register: c.io_uring_clock_register = std.mem.zeroes(c.io_uring_clock_register),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_clockid(self: *const Self) u32 {
        return self._io_uring_clock_register.clockid;
    }

    pub fn set_clockid(self: *Self, value: u32) void {
        self._io_uring_clock_register.clockid = value;
    }
};

/// A BPF filter for the requests of a ring or task (`io_uring_register_bpf_filter`,
/// `io_uring_register_bpf_filter_task`).
///
/// Example
///     >>> bpf = Bpf()
///     >>> bpf.opcode = IORING_OP_OPENAT
///     >>> bpf.filter = program          # `struct sock_filter` instructions (8 bytes each), hold on to it
///     >>> io_uring_register_bpf_filter(ring, bpf)
pub const Bpf = struct {
    _io_uring_bpf: c.io_uring_bpf = std.mem.zeroes(c.io_uring_bpf),
    _program: ?*Object = null, // the buffer `filter_ptr` points into

    pub fn __new__(self: *Self) void { // no arguments: `TypeError` for any
        self._io_uring_bpf.cmd_type = c.IO_URING_BPF_CMD_FILTER;
    }
    const Self = @This();

    pub fn get_cmd_type(self: *const Self) u16 {
        return self._io_uring_bpf.cmd_type;
    }

    pub fn set_cmd_type(self: *Self, value: u16) void {
        self._io_uring_bpf.cmd_type = value;
    }

    pub fn get_cmd_flags(self: *const Self) u16 {
        return self._io_uring_bpf.cmd_flags;
    }

    pub fn set_cmd_flags(self: *Self, value: u16) void {
        self._io_uring_bpf.cmd_flags = value;
    }

    pub fn get_opcode(self: *const Self) u32 {
        return self._io_uring_bpf.unnamed_0.filter.opcode;
    }

    pub fn set_opcode(self: *Self, value: u32) void {
        self._io_uring_bpf.unnamed_0.filter.opcode = value;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_bpf.unnamed_0.filter.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_bpf.unnamed_0.filter.flags = value;
    }

    pub fn get_pdu_size(self: *const Self) u8 {
        return self._io_uring_bpf.unnamed_0.filter.pdu_size;
    }

    pub fn set_pdu_size(self: *Self, value: u8) void {
        self._io_uring_bpf.unnamed_0.filter.pdu_size = value;
    }

    /// The number of BPF instructions.
    pub fn get_filter_len(self: *const Self) u32 {
        return self._io_uring_bpf.unnamed_0.filter.filter_len;
    }

    /// The filter program: a bytes-like object of `struct sock_filter` instructions (8 bytes each).
    pub fn set_filter(self: *Self, program: *Object) py.Error!void {
        const buf = try py.Buffer.from(program);
        defer buf.deinit();
        if (buf.data.len % 8 != 0) return py.raiseValueError("`filter` must be a multiple of 8 bytes (one `sock_filter` each)", .{});
        const filter = &self._io_uring_bpf.unnamed_0.filter;
        filter.filter_ptr = @intFromPtr(buf.data.ptr);
        filter.filter_len = @intCast(buf.data.len / 8); // cast: the filter limit is far below u32
        setOwned(&self._program, program);
    }

    pub fn get_filter(self: *const Self) ?*Object {
        return if (self._program) |o| keep(o) else null; // a new reference
    }
};

/// SigsetT
pub const SigsetT = struct {
    _sigset_t: ?*c.__sigset_t = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._sigset_t) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// Registers memory the ring uses itself (`io_uring_register_region`): `flags` for the registration and the
/// region's description (`region_*`).
///
/// Example
///     >>> mem = bytearray(4096)
///     >>> reg = MemRegionReg()
///     >>> reg.region_user_addr = address_of(mem)
///     >>> reg.region_size = len(mem)
///     >>> reg.flags = IORING_MEM_REGION_REG_WAIT_ARG
///     >>> io_uring_register_region(ring, reg)
pub const MemRegionReg = struct {
    _io_uring_mem_region_reg: c.io_uring_mem_region_reg = std.mem.zeroes(c.io_uring_mem_region_reg),
    _desc: c.io_uring_region_desc = std.mem.zeroes(c.io_uring_region_desc), // what `region_uptr` points to

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn get_flags(self: *const Self) u64 {
        return self._io_uring_mem_region_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u64) void {
        self._io_uring_mem_region_reg.flags = value;
    }

    pub fn get_region_user_addr(self: *const Self) u64 {
        return self._desc.user_addr;
    }

    pub fn set_region_user_addr(self: *Self, value: u64) void {
        self._desc.user_addr = value;
    }

    pub fn get_region_size(self: *const Self) u64 {
        return self._desc.size;
    }

    pub fn set_region_size(self: *Self, value: u64) void {
        self._desc.size = value;
    }

    pub fn get_region_flags(self: *const Self) u32 {
        return self._desc.flags;
    }

    pub fn set_region_flags(self: *Self, value: u32) void {
        self._desc.flags = value;
    }

    pub fn get_region_id(self: *const Self) u32 {
        return self._desc.id;
    }

    pub fn set_region_id(self: *Self, value: u32) void {
        self._desc.id = value;
    }

    pub fn get_region_mmap_offset(self: *const Self) u64 {
        return self._desc.mmap_offset;
    }

    pub fn set_region_mmap_offset(self: *Self, value: u64) void {
        self._desc.mmap_offset = value;
    }
};

/// BufRing
pub const BufRing = struct {
    _io_uring_buf_ring: ?[*]c.io_uring_buf_ring = null,
    // note: `io_uring_free_buf_ring()` should be called manually to free the memory.

    pub const instantiable = false;
};

/// Message header for `io_uring_prep_sendmsg` / `io_uring_prep_recvmsg`: an address, a vector of buffers and
/// ancillary data.
///
/// Example
///     >>> msg = Msghdr(Sockaddr(AF_INET, "127.0.0.1", 9000), Iovec([b"hello"]), flags=0)
///     >>> io_uring_prep_sendmsg(sqe, sockfd, msg)
///
///     >>> # receive: the kernel fills `name`, the iovec buffers and `control`
///     >>> name, buf, control = Sockaddr(), bytearray(1024), bytearray(64)
///     >>> iov = Iovec([buf])
///     >>> msg = Msghdr(name, iov, control)
///     >>> io_uring_prep_recvmsg(sqe, sockfd, msg)
///
///     >>> # multishot receive with provided buffers: only the lengths are given
///     >>> msg = Msghdr(namelen=16, controllen=0)
///     >>> io_uring_prep_recvmsg_multishot(sqe, sockfd, msg)
///
/// Note
///     - Hold on to `msg` (and what it was made from) until the request has completed: io_uring reads it when
///     submitting and writes `namelen`, `controllen` and `flags` back when done.
///     - `name`, `iov` and `control` are kept alive by the `Msghdr`; `namelen` / `controllen` start as the
///     size of the `Sockaddr` / `control` given and can be set (e.g. for a multishot receive, where the
///     kernel puts both, with the data, into a provided buffer).
pub const Msghdr = struct {
    _msghdr: c.msghdr = std.mem.zeroes(c.msghdr), // lives inside the Python object
    _name: ?*Object = null, // the `Sockaddr` `msg_name` points into
    _iov: ?*Object = null, // the `Iovec` `msg_iov` points into
    _control: ?*Object = null, // the buffer object `msg_control` points into
    _control_len: usize = 0, // the size of that buffer

    const Self = @This();

    pub fn __new__(
        self: *Self,
        name: ?*Object,
        iov: ?*Object,
        control: ?*Object,
        flags: ?i32,
        namelen: ?u32,
        controllen: ?usize,
    ) py.Error!void {
        if (name) |o| {
            const SockaddrType = @import("socket.zig").SockaddrType;
            if (!SockaddrType.check(o)) return py.raiseTypeError("`Msghdr(name)` must be a `Sockaddr`", .{});
            const sock = SockaddrType.data(o);
            self._msghdr.msg_name = sock.addrPtr();
            self._msghdr.msg_namelen = sock._socklen;
            self._name = keep(o);
        }
        if (iov) |o| {
            if (!IovecType.check(o)) return py.raiseTypeError("`Msghdr(iov)` must be an `Iovec`", .{});
            const v = IovecType.data(o);
            self._msghdr.msg_iov = v._iovec;
            self._msghdr.msg_iovlen = v._len;
            self._iov = keep(o);
        }
        if (control) |o| {
            const buf = try py.Buffer.from(o);
            defer buf.deinit();
            self._msghdr.msg_control = @ptrCast(@constCast(buf.data.ptr));
            self._msghdr.msg_controllen = buf.data.len;
            self._control_len = buf.data.len;
            self._control = keep(o);
        }
        if (flags) |f| self._msghdr.msg_flags = f;
        if (namelen) |n| self._msghdr.msg_namelen = n;
        if (controllen) |n| {
            if (self._control != null and n > self._control_len)
                return py.raiseValueError("`Msghdr(controllen)` is longer than `control`", .{});
            self._msghdr.msg_controllen = n;
        }
    }

    pub fn get_flags(self: *const Self) i32 {
        return self._msghdr.msg_flags;
    }

    pub fn set_flags(self: *Self, value: i32) void {
        self._msghdr.msg_flags = value;
    }

    pub fn get_namelen(self: *const Self) u32 {
        return self._msghdr.msg_namelen;
    }

    pub fn set_namelen(self: *Self, value: u32) py.Error!void {
        if (self._name != null and value > @sizeOf(c.sockaddr_storage))
            return py.raiseValueError("`namelen` is longer than a `Sockaddr`", .{});
        self._msghdr.msg_namelen = value;
    }

    pub fn get_controllen(self: *const Self) usize {
        return self._msghdr.msg_controllen;
    }

    pub fn set_controllen(self: *Self, value: usize) py.Error!void {
        if (self._control != null and value > self._control_len)
            return py.raiseValueError("`controllen` is longer than `control`", .{});
        self._msghdr.msg_controllen = value;
    }

    pub fn get_iovlen(self: *const Self) usize {
        return self._msghdr.msg_iovlen;
    }
};

/// One control message (`struct cmsghdr`) of a received `Msghdr`, from `io_uring_recvmsg_cmsg_firsthdr` /
/// `io_uring_recvmsg_cmsg_nexthdr`.
///
/// Example
///     >>> cmsg = io_uring_recvmsg_cmsg_firsthdr(out, msg)
///     >>> while cmsg:
///     ...     cmsg.level, cmsg.type, cmsg.data
///     ...     cmsg = io_uring_recvmsg_cmsg_nexthdr(out, msg, cmsg)
pub const Cmsghdr = struct {
    _cmsghdr: ?*c.cmsghdr = null,
    _owner: ?*Object = null, // the `RecvmsgOut` (and so the buffer) `_cmsghdr` points into

    pub const instantiable = false;

    const Self = @This();

    pub fn get_level(self: *const Self) i32 {
        return self._cmsghdr.?.cmsg_level;
    }

    pub fn get_type(self: *const Self) i32 {
        return self._cmsghdr.?.cmsg_type;
    }

    /// `cmsg_len`: the header and the data.
    pub fn get_len(self: *const Self) usize {
        return self._cmsghdr.?.cmsg_len;
    }

    /// The data after the header (a copy).
    pub fn get_data(self: *const Self) py.Bytes {
        const hdr = self._cmsghdr.?;
        const header: usize = @sizeOf(c.cmsghdr); // CMSG_LEN(0): the header is already aligned
        const len = if (hdr.cmsg_len > header) hdr.cmsg_len - header else 0;
        const base: [*]const u8 = @ptrCast(hdr);
        return .{ .data = (base + header)[0..len] };
    }

    pub fn __bool__(self: *const Self) bool {
        return self._cmsghdr != null;
    }
};

/// The result of `io_uring_recvmsg_validate`: the header the kernel put in front of a message received with
/// `io_uring_prep_recvmsg_multishot` into a provided buffer: `[header][name][control][payload]`.
///
/// Example
///     >>> out = io_uring_recvmsg_validate(buf, msg)
///     >>> out.namelen, out.controllen, out.payloadlen, out.flags
///     >>> io_uring_recvmsg_payload(out, msg)
///     b"hello"
pub const RecvmsgOut = struct {
    _recvmsg_out: ?*c.io_uring_recvmsg_out = null,
    _len: usize = 0, // the size of the buffer it points into
    _view: ?py.WritableBuffer = null, // locks the buffer (can not be resized) while this lives

    pub const instantiable = false;

    const Self = @This();

    pub fn get_namelen(self: *const Self) u32 {
        return self._recvmsg_out.?.namelen;
    }

    pub fn get_controllen(self: *const Self) u32 {
        return self._recvmsg_out.?.controllen;
    }

    pub fn get_payloadlen(self: *const Self) u32 {
        return self._recvmsg_out.?.payloadlen;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._recvmsg_out.?.flags;
    }

    pub fn __del__(self: *Self) void {
        if (self._view) |v| v.deinit();
    }
};

/// Event for `io_uring_prep_epoll_ctl` (one, the events and the user data to get back) and
/// `io_uring_prep_epoll_wait` (`EpollEvent(no=n)`: room for `n` events, read with `events[i]`).
///
/// Example
///     >>> ev = EpollEvent(events=EPOLLIN, data=123)
///     >>> io_uring_prep_epoll_ctl(sqe, epfd, fd, EPOLL_CTL_ADD, ev)
///
///     >>> ready = EpollEvent(no=8)
///     >>> io_uring_prep_epoll_wait(sqe, epfd, ready, 8)
///     ... # after the completion `res` events are set:
///     >>> ready[0].events, ready[0].data
pub const EpollEvent = struct {
    _events: ?[*]linux.epoll_event = null,
    _len: usize = 0,
    _index: usize = 0, // the event `events` / `data` are about
    _owner: ?*Object = null, // the `EpollEvent` that owns the array, for `events[i]`
    _owns: bool = false, // frees the array (not a `events[i]` view); `_owner` is already dropped when `__del__` runs

    const Self = @This();

    /// `EpollEvent(events=..., data=...)` is one event, `EpollEvent(no=n)` is room for `n`.
    pub fn __new__(self: *Self, no: ?u32, events: ?u32, data: ?u64) py.Error!void {
        const count: usize = no orelse 1;
        if (count == 0) return py.raiseValueError("`EpollEvent(no)` must be at least 1", .{});
        if (no != null and (events != null or data != null))
            return py.raiseValueError("`EpollEvent`: give `no`, or `events` and `data`", .{});
        const all = std.heap.c_allocator.alloc(linux.epoll_event, count) catch return e.raiseMemoryError("Out of Memory!");
        @memset(all, std.mem.zeroes(linux.epoll_event));
        all[0].events = events orelse 0;
        all[0].data.u64 = data orelse 0;
        self._events = all.ptr;
        self._len = count;
        self._owns = true;
    }

    pub fn __del__(self: *Self) void {
        if (self._owns) if (self._events) |ptr| std.heap.c_allocator.free(ptr[0..self._len]);
    }

    pub fn __len__(self: *const Self) usize {
        return if (self._owner == null) self._len else 1;
    }

    pub fn __getitem__(self: *Self, index: isize) py.Error!*Object {
        if (self._owner != null or index < 0 or index >= self._len) return py.raiseIndexError("Index out of range", .{});
        const root = EpollEventType.object(self);
        return EpollEventType.new(.{
            ._events = self._events,
            ._len = self._len,
            ._index = @intCast(index), // cast: checked
            ._owner = keep(root),
        });
    }

    pub fn get_events(self: *const Self) u32 {
        return self._events.?[self._index].events;
    }

    pub fn set_events(self: *Self, value: u32) void {
        self._events.?[self._index].events = value;
    }

    pub fn get_data(self: *const Self) u64 {
        return self._events.?[self._index].data.u64;
    }

    pub fn set_data(self: *Self, value: u64) void {
        self._events.?[self._index].data.u64 = value;
    }
};

/// How to Open a Path
///
/// Example
///     >>> how = OpenHow(O_CREAT | O_RDWR, 0o777, RESOLVE_CACHED)
///     >>> io_uring_prep_openat2(..., how)
///
///     # or
///
///     >>> how = OpenHow()
///     >>> how.flags   = O_CREAT | O_RDWR
///     >>> how.mode    = 0
///     >>> how.resolve = RESOLVE_CACHED
///     >>> io_uring_prep_openat2(..., how)
///
/// flags
///     O_CREAT
///     O_RDWR
///     O_RDONLY
///     O_WRONLY
///     O_TMPFILE
///     ...
///
/// Resolve
///     RESOLVE_BENEATH
///     RESOLVE_IN_ROOT
///     RESOLVE_NO_MAGICLINKS
///     RESOLVE_NO_SYMLINKS
///     RESOLVE_NO_XDEV
///     RESOLVE_CACHED
///
/// Note
///     - `mode` is only to set when creating new or temp file.
///     - You can use same `OpenHow()` reference if opening multiple files with same settings.
pub const OpenHow = struct {
    _open_how: c.open_how = std.mem.zeroes(c.open_how), // lives inside the Python object

    const Self = @This();

    pub fn __new__(self: *Self, flags: ?u64, mode: ?u64, resolve: ?u64) void {
        self._open_how.flags = flags orelse 0;
        self._open_how.mode = mode orelse 0;
        self._open_how.resolve = resolve orelse 0;
    }

    pub fn __repr__(self: *const Self) py.Error!*Object {
        var buf: [96]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "OpenHow(flags={d}, mode={d}, resolve={d})", .{
            self._open_how.flags,
            self._open_how.mode,
            self._open_how.resolve,
        }) catch unreachable; // three u64s fit
        return py.new(text);
    }

    // Get
    // ---

    pub fn get_flags(self: *const Self) u64 {
        return self._open_how.flags;
    }

    pub fn get_mode(self: *const Self) u64 {
        return self._open_how.mode;
    }

    pub fn get_resolve(self: *const Self) u64 {
        return self._open_how.resolve;
    }

    // Set
    // ---

    pub fn set_flags(self: *Self, value: u64) void {
        self._open_how.flags = value;
    }

    pub fn set_mode(self: *Self, value: u64) void {
        self._open_how.mode = value;
    }

    pub fn set_resolve(self: *Self, value: u64) void {
        self._open_how.resolve = value;
    }
};

/// Points the owned field `field` at `obj` (a new reference), dropping the old one.
pub fn setOwned(field: *?*Object, obj: *Object) void {
    if (field.* == obj) return;
    const old = field.*;
    field.* = keep(obj);
    py.decref(old);
}

/// Is `obj` referenced only by the caller (on 3.15t too, unlike reading its refcount)?
extern fn PyUnstable_Object_IsUniquelyReferenced(obj: *Object) c_int;

/// A new reference to `obj`, for an owned (`?*Object`) field.
pub fn keep(obj: *Object) *Object {
    py.incref(obj);
    return obj;
}
