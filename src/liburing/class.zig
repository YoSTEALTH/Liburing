//! Liburing - io_uring related classes
const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

///Vector I/O data structure
///
///Type
///    buffers: Union[bytes, bytearray, memoryview, List[...], Tuple[...]]
///    return:  None
///
///Example
///    # read single
///    # -----------
///    >>> iov_read = Iovec(bytearray(11))
///    >>> io_uring_prep_readv(sqe, fd, iov_read, ...)
///
///    # read multiple
///    # -------------
///    >>> iov_read = Iovec([bytearray(1), bytearray(2), bytearray(3)])
///    >>> io_uring_prep_readv(sqe, fd, iov_read, ...)
///
///    # write single
///    # ------------
///    >>> iov_write = Iovec(b'hello world')
///    >>> io_uring_prep_readv(sqe, fd, iov_write, ...)
///
///    # write multiple
///    # --------------
///    >>> iov_write = Iovec([b'1', b'22', b'333'])
///    >>> io_uring_prep_readv(sqe, fd, iov_write, ...)
///
///Note
///    - Make sure to hold on to variable you are passing into `Iovec` so it does not get
///    garbage collected before you get the chance to use it!
pub const Iovec = extern struct {
    _len: usize = 0,
    _iovec: ?[*]c.iovec = null,

    const Self = @This();

    pub fn __new__(data: *oz.PyObject) ?Self {
        var length: usize = undefined; // base data length.
        var _len: usize = undefined;
        const msg = "`iovec(data)` type not supported!";

        // check if bytes, bytearray or memoryview
        if (oz.py.PyBytes_Check(data) | oz.py.PyByteArray_Check(data) | oz.py.PyMemoryView_Check(data)) {
            length = @intCast(oz.py.c.PyObject_Length(data)); // length of byte string.
            if (length == -1) return oz.raiseTypeError(msg);
            _len = 1;
            if (std.heap.c_allocator.alloc(c.iovec, _len)) |iovec| {
                iovec[0].iov_base = data;
                iovec[0].iov_len = length;
                return .{ ._len = _len, ._iovec = iovec.ptr };
            } else |_| return oz.raiseMemoryError("Out of Memory!");
        } else if (oz.py.PyList_Check(data) | oz.py.PyTuple_Check(data)) { // list[bytes, ...] | tuple[...]
            _len = @intCast(oz.py.c.PyObject_Length(data)); // length of sequence.
            if (_len == -1) return oz.raiseTypeError(msg);
            if (_len == 0) return oz.raiseValueError("`Iovec(data)` - received `0` length sequence!");
            if (_len > std.posix.IOV_MAX) {
                return oz.raiseValueError(oz.fmt(
                    "`Iovec(data)` - length of {d} exceeds `IOV_MAX` limit set by OS of {d}",
                    .{ _len, std.posix.IOV_MAX },
                ));
            }
            if (std.heap.c_allocator.alloc(c.iovec, _len)) |iovec| {
                const r = for (0.._len) |i| {
                    if (oz.py.c.PySequence_GetItem(data, @intCast(i))) |value| {
                        if (oz.py.PyBytes_Check(value) | oz.py.PyByteArray_Check(value) | oz.py.PyMemoryView_Check(value)) {
                            length = @intCast(oz.py.c.PyObject_Length(value)); // length of byte string.
                            if (length == -1) break oz.raiseTypeError(msg);
                            iovec[i].iov_base = value;
                            iovec[i].iov_len = length;
                        } else break oz.raiseTypeError(msg);
                    } else break oz.raiseIndexError(msg);
                };
                if (r == null) { // error
                    std.heap.c_allocator.free(iovec[0.._len]);
                    return null;
                }
                return .{ ._len = _len, ._iovec = iovec.ptr }; // good
            } else |_| return oz.raiseMemoryError("Out of Memory!");
        }
        return oz.raiseTypeError(msg);
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    pub fn __del__(self: *const Self) void {
        if (self._iovec) |iov| std.heap.c_allocator.free(iov[0..self._len]);
    }
};

///Kernel Timespec
///
///Example
///    >>> ts = timespec(2)
///    >>> ts.sec
///    2
///    >>> ts.nsec
///    0
///    >>> ts.sec = 1           # second
///    >>> ts.nsec = 500000000  # nanosecond
pub const Timespec = extern struct {
    _timespec: ?*c.__kernel_timespec = null,

    const Self = @This();

    pub fn __del__(self: *const Self) void {
        if (self._timespec) |ts| std.heap.c_allocator.destroy(ts);
    }

    // Get

    pub fn get_sec(self: *const Self) ?i64 {
        if (self._timespec) |ts| return ts.tv_sec;
        return oz.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    pub fn get_nsec(self: *const Self) ?i64 {
        if (self._timespec) |ts| return ts.tv_nsec;
        return oz.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    // Set

    pub fn set_sec(self: *const Self, value: i64) ?void {
        if (self._timespec) |ts| {
            ts.tv_sec = value;
            return;
        }
        return oz.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }

    pub fn set_nsec(self: *const Self, value: i64) ?void {
        if (self._timespec) |ts| {
            ts.tv_nsec = value;
            return;
        }
        return oz.raiseMemoryError("`kernel_timespec()` - Memory not set!");
    }
};

///I/O URing
///
///Example
///    >>> ring = Ring()
///    >>> io_uring_queue_init(8, ring)
///    >>> io_uring_queue_exit(ring)
pub const Ring = extern struct {
    _io_uring: ?*c.io_uring,

    pub fn __new__() ?Ring {
        const io_uring: *c.io_uring = std.heap.c_allocator.create(c.io_uring) catch {
            return oz.raiseMemoryError("`Ring()` - Out of Memory!");
        };
        io_uring.* = std.mem.zeroes(c.io_uring); // set default value to `0`
        return .{ ._io_uring = io_uring };
    }

    pub fn __del__(self: *const Ring) void {
        if (self._io_uring) |io_uring| std.heap.c_allocator.destroy(io_uring);
    }

    pub fn get_flags(self: *const Ring) u32 {
        if (self._io_uring) |io_uring| return io_uring.flags;
        return 0;
    }

    pub fn get_ring_fd(self: *const Ring) i32 {
        if (self._io_uring) |io_uring| return io_uring.ring_fd;
        return 0;
    }

    pub fn get_features(self: *const Ring) u32 {
        if (self._io_uring) |io_uring| return io_uring.features;
        return 0;
    }

    pub fn get_int_flags(self: *const Ring) u8 {
        if (self._io_uring) |io_uring| return io_uring.int_flags;
        return 0;
    }

    pub fn get_enter_ring_fd(self: *const Ring) i32 {
        if (self._io_uring) |io_uring| return io_uring.enter_ring_fd;
        return 0;
    }
};

/// Completion Queue Entry (CQE)
pub const CQE = extern struct {
    _cqe: *c.io_uring_cqe,

    const Self = @This();

    // GET

    pub fn get_user_data(self: *const Self) u64 {
        return self._cqe.user_data;
    }

    pub fn get_res(self: *const Self) i32 {
        return self._cqe.res;
    }

    pub fn get_flags(self: *const Self) u32 {
        return self._cqe.flags;
    }

    pub fn get_big_cqe(_: *const Self) ?void {
        return oz.raiseRuntimeError("`.big_cqe` not implemented!");
        // TODO: big_cqe: [16]u8, // when `IORING_SETUP_CQE32` is enabled.
    }
};

///I/O completion data structure (Completion Queue Entry) (CQE)
///
///Example
///    >>> cqe = Cqe()
///    ...
///    >>> io_uring_wait_cqe(ring, cqe)
///    >>> ready = io_uring_cq_ready(ring)
///
///    >>> for i in range(ready):
///    ...     cqe[i] # do stuff
///
///    >>> io_uring_cq_advance(ready) # free cqe already viewed.
///
///Note
///    - `cqe` items e.g: `cqe[0], cqe[1], ...` are not cached (should be called/used only once) and
///    is very dynamic, so make copy if you want to keep data alive for longer use.
pub const Cqe = extern struct {
    // TODO:
    // _array: ?[*]CQE = null, // custom memory for batch cqe
    _io_uring_cqe: ?[*]c.io_uring_cqe, // Note: Memory is managed by `io_uring`

    // TODO:
    pub fn __new__(no: ?u32) ?Cqe {
        if (no) |_| return oz.raiseNotImplementedError("`Cqe(no)` - Custom memory allocation not coded yet!");
        return .{ ._io_uring_cqe = null };
    }

    pub fn __bool__(self: *const Cqe) bool {
        return if (self._io_uring_cqe) |_| true else false;
    }

    pub fn __getitem__(self: *const Cqe, index: usize) ?CQE {
        if (self._io_uring_cqe) |cqe| {
            // if (cqe[index].user_data == 0) return oz.raiseIndexError("index out of range!"); // TODO: should remove.
            return .{ ._cqe = &cqe[index] };
        }
        return oz.raiseIndexError("`io_uring_cqe` - out of completed entries");
    }
};

///Example
///    >>> for i in CqeIter(ring, cqe):
///    >>>     cqe[0].user_data == i  # do stuff
///
///Note
///    - Only `cqe[0]` gets updated with new completed entry value.
pub const CqeIter = extern struct {
    _io_uring_cqe_iter: c.io_uring_cqe_iter,
    _index: usize = 0,
    _cqe: ?*Cqe = null,

    const Self = @This();

    pub fn __new__(ring: *Ring, cqe: *Cqe, index: ?usize) Self {
        const _index = index orelse 0;
        return .{ ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(ring._io_uring), ._index = _index, ._cqe = cqe };
    }

    pub fn __iter__(self: *Self) *Self {
        return self;
    }

    pub fn __next__(self: *Self) ?usize {
        if (self._cqe) |_cqe| {
            if (c.io_uring_cqe_iter_next(&self._io_uring_cqe_iter, &_cqe._io_uring_cqe)) {
                defer self._index += 1;
                return self._index;
            }
        }
        return null;
    }
};

/// Submission Queue Entry (SQE)
pub const SQE = extern struct {
    _sqe: *c.io_uring_sqe,

    const Self = @This();

    // GET

    pub fn get_opcode(self: *const Self) u8 {
        return self._sqe.opcode;
    }

    pub fn get_flags(self: *const Self) u8 {
        return self._sqe.flags;
    }

    pub fn get_ioprio(self: *const Self) u16 {
        return self._sqe.ioprio;
    }

    pub fn get_fd(self: *const Self) i32 {
        return self._sqe.fd;
    }

    pub fn get_len(self: *const Self) u32 {
        return self._sqe.len;
    }

    pub fn get_user_data(self: *const Self) u64 {
        return self._sqe.user_data;
    }

    pub fn get_personality(self: *const Self) u16 {
        return self._sqe.personality;
    }

    // SET

    pub fn set_flags(self: *Self, flags: u8) void {
        self._sqe.flags = flags;
        return;
    }

    pub fn set_user_data(self: *Self, data: u64) ?void {
        // if (data == 0) return oz.raiseValueError("`sqe.user_data` can not be set to `0`"); // TODO: should remove.
        self._sqe.user_data = data;
        return;
    }
};

///IO submission data structure (Submission Queue Entry) (SQE)
///
///Example
///    # single
///    >>> sqe = Sqe()  # defaults to `Sqe(1)`
///    >>> io_uring_prep_read(sqe, ...)
///    >>> sqe.user_data = 1
///
///    # multiple
///    >>> sqe = Sqe(2)
///    >>> io_uring_prep_write(sqe[0], ...)
///    >>> sqe[0].user_data = 1
///    >>> io_uring_prep_read(sqe[1], ...)
///    >>> sqe[1].user_data = 2
///
///    # *** MUST DO ***
///    >>> if io_uring_put_sqe(ring, sqe):
///    ...     io_uring_submit(ring)
///
///Note
///    - This class has dual usage:
///        1. It works as a base class for `io_uring_get_sqe()` return.
///        2. It can also be used as `sqe = Sqe(<int>)`, rather than "get" sqe(s)
///        you are going to "put" pre-made sqe(s) into the ring later. Refer to
///        `help(io_uring_put_sqe)` to see more detail.
///    - `Sqe(no)` is limited to max `0-255` items.
pub const Sqe = extern struct {
    _parent: SQE,
    _len: u8 = 0,
    _index: usize = 0,
    _array: ?[*]SQE = null, // alloc memory reference to `SQE` class stored here.
    _io_uring_sqe: ?[*]c.io_uring_sqe = null,

    const Self = @This();

    pub const __base__ = oz.base(SQE);

    pub fn __new__(no: ?u8) ?Self {
        const _no = if (no) |n| n else 1; // no = null/None/1 == 1
        if (_no > 0) {
            if (std.heap.c_allocator.alloc(c.io_uring_sqe, _no)) |sqes| {
                if (std.heap.c_allocator.alloc(SQE, _no)) |class| {
                    for (0.., sqes) |i, *sqe| {
                        sqe.* = std.mem.zeroes(c.io_uring_sqe);
                        class[i] = .{ ._sqe = sqe };
                    }
                    return .{ ._parent = class[0], ._len = _no, ._array = class.ptr, ._io_uring_sqe = sqes.ptr };
                } else |_| return oz.raiseMemoryError("out of memory!");
            } else |_| return oz.raiseMemoryError("out of memory!");
        }
        return oz.raiseRuntimeError("New `Sqe()` class not created.");
    }

    pub fn __getitem__(self: *const Self, index: u32) ?SQE {
        if (self._array) |array| {
            if (index < self._len) return array[index];
        } else if (index == 0) {
            if (self._io_uring_sqe) |sqe| return .{ ._sqe = &sqe[0] };
            return oz.raiseMemoryError("`io_uring_sqe()` is `null`!");
        }
        return oz.raiseIndexError("Index out of range");
    }

    pub fn __len__(self: *const Self) u8 {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    pub fn __del__(self: *Self) void {
        if (self._array) |list| { // clean up locally allocated memory
            if (self._io_uring_sqe) |items| std.heap.c_allocator.free(items[0..self._len]);
            std.heap.c_allocator.free(list[0..self._len]);
        }
    }
};

pub const Probe = extern struct {
    // _len: usize = 0,
    _io_uring_probe: ?*c.io_uring_probe = null,

    const Self = @This();

    pub fn __new__() ?Self {
        return oz.raiseNotImplementedError("`Probe()`");
        // if (no) |_no| {
        //     if (_no > 0) {
        //         if (std.heap.c_allocator.alloc(c.io_uring_probe, _no)) |probe| {
        //             return .{ ._len = _no, ._io_uring_probe = @ptrCast(probe) };
        //         } else |_| return oz.raiseMemoryError("out of memory!");
        //     }
        // }
        // return oz.raiseRuntimeError("New `Probe()` class not created.");

        // const p = std.heap.c_allocator.create(c.io_uring_probe) catch {
        //     return oz.raiseMemoryError("`io_uring_probe()` - Out of Memory!");
        // };
        // p.* = std.mem.zeroes(c.io_uring_probe); // set default value to `0`
        // return .{ ._io_uring_probe = p };
    }

    pub fn __del__(self: *Self) void {
        if (self._io_uring_probe) |p| c.io_uring_free_probe(p); // clean up in case user forgot to do so!
    }

    pub fn get_last_op(self: *const Self) ?u8 {
        if (self._io_uring_probe) |p| return p.last_op;
        return oz.raiseMemoryError("`Probe()` is null!");
    }

    pub fn get_ops_len(self: *const Self) ?u8 {
        if (self._io_uring_probe) |p| return p.ops_len;
        return oz.raiseMemoryError("`Probe()` is null!");
    }
};

pub const Param = extern struct {
    _io_uring_params: ?*c.io_uring_params,

    const Self = @This();

    pub fn get_sq_entries(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.sq_entries;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_cq_entries(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.cq_entries;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_flags(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.flags;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_sq_thread_cpu(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.sq_thread_cpu;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_sq_thread_idle(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.sq_thread_idle;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_features(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.features;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }

    pub fn get_wq_fd(self: *const Self) ?u32 {
        if (self._io_uring_params) |p| return p.wq_fd;
        return oz.raiseRuntimeError("`Param()` not initialized properly!");
    }
};

///RegWait
pub const RegWait = extern struct {
    _io_uring_reg_wait: ?*c.io_uring_reg_wait = null,

    const Self = @This();

    pub fn __del__(self: *const Self) void {
        if (self._io_uring_reg_wait) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///Restriction
pub const Restriction = extern struct {
    _len: usize = 0,
    _io_uring_restriction: ?[*]c.io_uring_restriction = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_restriction) |res| std.heap.c_allocator.free(res[0..self._len]);
    }
};

///BufReg
pub const BufReg = extern struct {
    _io_uring_buf_reg: ?*c.io_uring_buf_reg = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_buf_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///SyncCancelReg
pub const SyncCancelReg = extern struct {
    _io_uring_sync_cancel_reg: ?*c.io_uring_sync_cancel_reg = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_sync_cancel_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///Napi
pub const Napi = extern struct {
    _io_uring_napi: ?*c.io_uring_napi = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_napi) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///ZcrxIfqReg
pub const ZcrxIfqReg = extern struct {
    _io_uring_zcrx_ifq_reg: ?*c.io_uring_zcrx_ifq_reg = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_zcrx_ifq_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///ClockRegister
pub const ClockRegister = extern struct {
    _io_uring_clock_register: ?*c.io_uring_clock_register = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_clock_register) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///Bpf
pub const Bpf = extern struct {
    _io_uring_bpf: ?*c.io_uring_bpf = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_bpf) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///SigsetT
pub const SigsetT = extern struct {
    _sigset_t: ?*c.__sigset_t = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._sigset_t) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///MemRegionReg
pub const MemRegionReg = extern struct {
    _io_uring_mem_region_reg: ?*c.io_uring_mem_region_reg = null,

    const Self = @This();

    pub fn __del__(self: *Self) void {
        if (self._io_uring_mem_region_reg) |ptr| std.heap.c_allocator.destroy(ptr);
    }
};

///BufRing
pub const BufRing = extern struct {
    _io_uring_buf_ring: [*]c.io_uring_buf_ring,
    // note: `io_uring_free_buf_ring()` should be called manually to free the memory.
};

///Cmsghdr
pub const Cmsghdr = extern struct {
    _cmsghdr: *c.cmsghdr,

    // const Self = @This();

    // TODO: create fields
    // cmsg_len: usize align(8)    // Length of data in `cmsg_data` plus length of `cmsghdr` structure.
    // cmsg_level: c_int           // Originating protocol.
    // cmsg_type: c_int            // Protocol specific type.

    // pub fn __del__(self: *Self) void {
    //     if (self._cmsghdr) |ptr| std.heap.c_allocator.destroy(ptr);
    // }
};

///Msghdr
pub const Msghdr = extern struct {
    _msghdr: *c.msghdr,

    // const Self = @This();

    // TODO: create fields
    // msg_name: ?*anyopaque,      // Address to send to/receive from.
    // msg_namelen: socklen_t,     // Length of address data.
    // msg_iov: [*c]struct_iovec,  // Vector of data to send/receive into.
    // msg_iovlen: usize,          // Number of elements in the vector.
    // msg_control: ?*anyopaque,   // Ancillary data (eg BSD filedesc passing).
    // msg_controllen: usize,      // Ancillary data buffer length.
    // msg_flags: c_int,           // Flags on received message.

    // pub fn __del__(self: *Self) void {
    //     if (self._msghdr) |ptr| std.heap.c_allocator.destroy(ptr);
    // }
};

///EpollEvent
pub const EpollEvent = extern struct {
    _epoll_event: *c.epoll_event,
};

///RecvmsgOut
pub const RecvmsgOut = extern struct {
    _recvmsg_out: *c.io_uring_recvmsg_out,

    // const Self = @This();

    // pub fn __del__(self: *Self) void {
    //     if (self._recvmsg_out) |ptr| std.heap.c_allocator.destroy(ptr);
    // }
};

///How to Open a Path
///
///Example
///    >>> how = OpenHow(O_CREAT | O_RDWR, 0o777, RESOLVE_CACHED)
///    >>> io_uring_prep_openat2(..., how)
///
///    # or
///
///    >>> how = OpenHow()
///    >>> how.flags   = O_CREAT | O_RDWR
///    >>> how.mode    = 0
///    >>> how.resolve = RESOLVE_CACHED
///    >>> io_uring_prep_openat2(..., how)
///
///flags
///    O_CREAT
///    O_RDWR
///    O_RDONLY
///    O_WRONLY
///    O_TMPFILE
///    ...
///
///Resolve
///    RESOLVE_BENEATH
///    RESOLVE_IN_ROOT
///    RESOLVE_NO_MAGICLINKS
///    RESOLVE_NO_SYMLINKS
///    RESOLVE_NO_XDEV
///    RESOLVE_CACHED
///
///Note
///    - `mode` is only to set when creating new or temp file.
///    - You can use same `OpenHow()` reference if opening multiple files with same settings.
pub const OpenHow = extern struct {
    _open_how: *c.open_how,

    const Self = @This();

    pub fn __new__(flags: ?u64, mode: ?u64, resolve: ?u64) !OpenHow {
        const how: *c.open_how = try std.heap.c_allocator.create(c.open_how);
        how.flags = flags orelse 0;
        how.mode = mode orelse 0;
        how.resolve = resolve orelse 0;
        return .{ ._open_how = how };
    }

    // Get
    // ---

    pub fn __del__(self: *Self) void {
        std.heap.c_allocator.destroy(self._open_how);
    }

    pub fn __repr__(self: *const Self) [*:0]const u8 {
        return oz.fmt("OpenHow(flags={}, mode={}, resolve={})", .{
            self._open_how.flags,
            self._open_how.mode,
            self._open_how.resolve,
        });
    }

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

// TODO:
// pub const Futex = extern struct {}
