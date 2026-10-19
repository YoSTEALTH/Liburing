//! Liburing - io_uring related classes
const c = @import("c.zig").c;
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");

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
////   # Read
///     # ----
///     >>> buffer = [bytearray(1), bytearray(2), bytearray(3)]
///     >>> iov_read = Iovec(buffer)
///     >>> io_uring_prep_readv(sqe, fd, iov_read, ...)
///
///     # Write
///     # -----
///     >>> buffer = [b'1', b'22', b'333']
///     >>> iov_write = Iovec(buffer)
///     >>> io_uring_prep_writev(sqe, fd, iov_write, ...)
///
/// Note
///     - Make sure to hold on to variable you are passing into `Iovec` so it does not get
///     garbage collected before you get the chance to use it!
pub const Iovec = struct {
    _len: usize = 0,
    _iovec: ?[*]c.iovec = null,

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
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
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

/// RegWait
pub const RegWait = struct {
    _io_uring_reg_wait: ?*c.io_uring_reg_wait = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *const Self) void {
        if (self._io_uring_reg_wait) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// Restriction
pub const Restriction = struct {
    _len: usize = 0,
    _io_uring_restriction: ?[*]c.io_uring_restriction = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_restriction) |res| std.heap.c_allocator.free(res[0..self._len]);
    }
};

/// BufReg
pub const BufReg = struct {
    _io_uring_buf_reg: ?*c.io_uring_buf_reg = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_buf_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// SyncCancelReg
pub const SyncCancelReg = struct {
    _io_uring_sync_cancel_reg: ?*c.io_uring_sync_cancel_reg = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_sync_cancel_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// Napi
pub const Napi = struct {
    _io_uring_napi: ?*c.io_uring_napi = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_napi) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// ZcrxIfqReg
pub const ZcrxIfqReg = struct {
    _io_uring_zcrx_ifq_reg: ?*c.io_uring_zcrx_ifq_reg = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_zcrx_ifq_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// ClockRegister
pub const ClockRegister = struct {
    _io_uring_clock_register: ?*c.io_uring_clock_register = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_clock_register) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// Bpf
pub const Bpf = struct {
    _io_uring_bpf: ?*c.io_uring_bpf = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_bpf) |ptr| std.heap.c_allocator.destroy(ptr);
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

/// MemRegionReg
pub const MemRegionReg = struct {
    _io_uring_mem_region_reg: ?*c.io_uring_mem_region_reg = null,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_mem_region_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

/// BufRing
pub const BufRing = struct {
    _io_uring_buf_ring: ?[*]c.io_uring_buf_ring = null,
    // note: `io_uring_free_buf_ring()` should be called manually to free the memory.

    pub const instantiable = false;
};

/// Cmsghdr
pub const Cmsghdr = struct {
    _cmsghdr: ?*c.cmsghdr = null,

    pub const instantiable = false;

    // TODO: create fields
    // cmsg_len: usize align(8)    // Length of data in `cmsg_data` plus length of `cmsghdr` structure.
    // cmsg_level: c_int           // Originating protocol.
    // cmsg_type: c_int            // Protocol specific type.
};

/// Msghdr
pub const Msghdr = struct {
    _msghdr: ?*c.msghdr = null,

    pub const instantiable = false;

    // TODO: create fields
    // msg_name: ?*anyopaque,      // Address to send to/receive from.
    // msg_namelen: socklen_t,     // Length of address data.
    // msg_iov: [*c]struct_iovec,  // Vector of data to send/receive into.
    // msg_iovlen: usize,          // Number of elements in the vector.
    // msg_control: ?*anyopaque,   // Ancillary data (eg BSD filedesc passing).
    // msg_controllen: usize,      // Ancillary data buffer length.
    // msg_flags: c_int,           // Flags on received message.
};

/// EpollEvent
pub const EpollEvent = struct {
    _epoll_event: ?*c.epoll_event = null,

    pub const instantiable = false;
};

/// RecvmsgOut
pub const RecvmsgOut = struct {
    _recvmsg_out: ?*c.io_uring_recvmsg_out = null,

    pub const instantiable = false;
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
