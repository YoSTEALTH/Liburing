//! Liburing - register structs and functions, buffer rings
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const support = @import("support.zig");
const setOwned = @import("class.zig").setOwned;
const keep = @import("class.zig").keep;
const callReleased = @import("complete.zig").callReleased;
const FileIndex = @import("helper.zig").FileIndex;
const releaseFailed = @import("helper.zig").releaseFailed;
const Ring = @import("ring.zig").Ring;
const Sqe = @import("sqe.zig").Sqe;

const py = setu.py;
const Object = setu.c.Object;
pub const RegWaitType = setu.Class(RegWait, @embedFile("register.zig"));
pub const RestrictionType = setu.Class(Restriction, @embedFile("register.zig"));
pub const BufRegType = setu.Class(BufReg, @embedFile("register.zig"));
pub const SyncCancelRegType = setu.Class(SyncCancelReg, @embedFile("register.zig"));
pub const NapiType = setu.Class(Napi, @embedFile("register.zig"));
pub const QueryType = setu.Class(Query, @embedFile("register.zig"));
pub const ZcrxCtrlType = setu.Class(ZcrxCtrl, @embedFile("register.zig"));
pub const ZcrxIfqRegType = setu.Class(ZcrxIfqReg, @embedFile("register.zig"));
pub const ClockRegisterType = setu.Class(ClockRegister, @embedFile("register.zig"));
pub const BpfType = setu.Class(Bpf, @embedFile("register.zig"));
pub const MemRegionRegType = setu.Class(MemRegionReg, @embedFile("register.zig"));
pub const BufRingType = setu.Class(BufRing, @embedFile("register.zig"));

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
    return .{ .tv_sec = @trunc(whole), .tv_nsec = @round((v - whole) * 1e9) };
}

/// One wait argument (`struct io_uring_reg_wait`), for `io_uring_submit_and_wait_reg`: it is copied into a memory
/// region registered with `IORING_MEM_REGION_REG_WAIT_ARG` (see `MemRegionReg`), at `index * RegWait.SIZE`.
///
/// Example
///     >>> mem = mmap.mmap(-1, 4096)
///     >>> region = MemRegionReg()
///     >>> region.flags = IORING_MEM_REGION_REG_WAIT_ARG
///     >>> region.region = mem
///     >>> io_uring_register_region(ring, region)  # `ring` set up with `IORING_SETUP_R_DISABLED`
///     0
///     >>> io_uring_enable_rings(ring)
///     0
///
///     >>> wait = RegWait()
///     >>> wait.timeout = 0.5            # seconds, `None` for none
///     >>> wait.flags = IORING_REG_WAIT_TS
///     >>> mem[0 : RegWait.SIZE] = wait.to_bytes()
///     >>> io_uring_prep_nop(io_uring_get_sqe(ring))
///     True
///     >>> io_uring_submit_and_wait_reg(ring, cqe, 1, 0)   # the wait argument at index 0
///     1
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

    /// Set the wait time in seconds (`None` for none); `ValueError` outside `0 .. 1e15`.
    pub fn set_timeout(self: *Self, value: ?f64) py.Error!void {
        self._io_uring_reg_wait.ts = try secondsTimeout(value);
    }

    /// The minimum wait in microseconds (`min_wait_usec`).
    pub fn get_min_wait_usec(self: *const Self) u32 {
        return self._io_uring_reg_wait.min_wait_usec;
    }

    pub fn set_min_wait_usec(self: *Self, value: u32) void {
        self._io_uring_reg_wait.min_wait_usec = value;
    }

    /// `IORING_REG_WAIT_*` flags.
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
///     >>> res.add(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_NOP)
///     >>> res.add(IORING_RESTRICTION_SQE_FLAGS_ALLOWED, IOSQE_IO_LINK)
///     >>> io_uring_register_restrictions(ring, res)  # `ring` set up with `IORING_SETUP_R_DISABLED`
///     0
///     >>> io_uring_enable_rings(ring)
///     0
pub const Restriction = struct {
    _len: usize = 0,
    _io_uring_restriction: ?[*]c.io_uring_restriction = null,
    _capacity: usize = 0,

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// Allows `value` for `opcode` (`IORING_RESTRICTION_*`): an sqe opcode, register opcode or sqe flags.
    pub fn add(self: *Self, opcode: u16, value: u8) py.Error!void {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, RestrictionType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        if (self._len == self._capacity) {
            const cap = if (self._capacity == 0) 4 else self._capacity * 2;
            const old: []c.io_uring_restriction =
                if (self._io_uring_restriction) |ptr| ptr[0..self._capacity] else &.{};
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

    /// The number of restrictions added.
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
///     >>> reg.ring = mmap.mmap(-1, 8 * 16)   # 16 bytes per entry, page aligned
///     >>> reg.ring_entries = 8
///     >>> reg.bgid = 1
///     >>> io_uring_register_buf_ring(ring, reg)
///     0
///
/// Note
///     - `ring` is the memory itself, not its address: the ring keeps it locked from the register until
///       `io_uring_unregister_buf_ring` or its exit (it can not be resized, closed or freed meanwhile).
pub const BufReg = struct {
    _io_uring_buf_reg: c.io_uring_buf_reg = std.mem.zeroes(c.io_uring_buf_reg),
    _ring: ?*Object = null, // the memory `ring_addr` is set to at the register

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// The buffer ring's memory: a writable, page-aligned buffer (`mmap.mmap`) of at least `ring_entries * 16`
    /// bytes, or `None` (with `IOU_PBUF_RING_MMAP` the kernel allocates it).
    ///
    /// Type
    ///     return: Buffer | None
    pub fn get_ring(self: *const Self) ?*Object {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, BufRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        return if (self._ring) |o| keep(o) else null; // a new reference
    }

    /// Sets `ring`.
    ///
    /// Type
    ///     value: Buffer | None
    pub fn set_ring(self: *Self, value: ?*Object) py.Error!void {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, BufRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        _ = try setMemory(&self._ring, value);
    }

    /// The locked view `io_uring_register_buf_ring` hands the kernel (`null`: no `ring`), `ring_addr` set to it.
    pub fn lockViews(self: *Self) py.Error!?setu.c.Buffer {
        const reg = &self._io_uring_buf_reg;
        reg.ring_addr = 0;
        const obj = self._ring orelse return null;
        if (reg.flags & c.IOU_PBUF_RING_MMAP != 0)
            return py.raiseValueError(
                "`BufReg.ring` must be `None` with `IOU_PBUF_RING_MMAP` (the kernel allocates it)",
                .{},
            );
        const view = try lockMemory(obj, @as(u64, reg.ring_entries) * @sizeOf(c.io_uring_buf), "BufReg.ring");
        reg.ring_addr = @intFromPtr(view.buf);
        return view;
    }

    /// The number of entries in the ring (a power of 2).
    pub fn get_ring_entries(self: *const Self) u32 {
        return self._io_uring_buf_reg.ring_entries;
    }

    pub fn set_ring_entries(self: *Self, value: u32) void {
        self._io_uring_buf_reg.ring_entries = value;
    }

    /// The buffer group id.
    pub fn get_bgid(self: *const Self) u16 {
        return self._io_uring_buf_reg.bgid;
    }

    pub fn set_bgid(self: *Self, value: u16) void {
        self._io_uring_buf_reg.bgid = value;
    }

    /// `IOU_PBUF_RING_*` flags.
    pub fn get_flags(self: *const Self) u16 {
        return self._io_uring_buf_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u16) void {
        self._io_uring_buf_reg.flags = value;
    }

    /// `min_left` of `struct io_uring_buf_reg`.
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
///     >>> reg.addr = 123                      # the user_data of the request (a pending read here)
///     >>> reg.timeout = 1.0                   # seconds to wait (default: until done)
///     >>> io_uring_register_sync_cancel(ring, reg)
///     0
pub const SyncCancelReg = struct {
    _io_uring_sync_cancel_reg: c.io_uring_sync_cancel_reg = std.mem.zeroes(c.io_uring_sync_cancel_reg),

    pub fn __new__(self: *Self) void { // no arguments: `TypeError` for any
        self._io_uring_sync_cancel_reg.timeout = .{ .tv_sec = -1, .tv_nsec = -1 }; // no timeout
        self._io_uring_sync_cancel_reg.fd = -1;
    }
    const Self = @This();

    /// The `user_data` of the request to cancel (with `IORING_ASYNC_CANCEL_USERDATA`, or by default).
    pub fn get_addr(self: *const Self) u64 {
        return self._io_uring_sync_cancel_reg.addr;
    }

    pub fn set_addr(self: *Self, value: u64) void {
        self._io_uring_sync_cancel_reg.addr = value;
    }

    /// The file descriptor to cancel by (with `IORING_ASYNC_CANCEL_FD`); `-1` by default.
    pub fn get_fd(self: *const Self) i32 {
        return self._io_uring_sync_cancel_reg.fd;
    }

    pub fn set_fd(self: *Self, value: i32) void {
        self._io_uring_sync_cancel_reg.fd = value;
    }

    /// `IORING_ASYNC_CANCEL_*` flags.
    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_sync_cancel_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_sync_cancel_reg.flags = value;
    }

    /// The opcode to cancel by (with `IORING_ASYNC_CANCEL_OP`).
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
///     0
pub const Napi = struct {
    _io_uring_napi: c.io_uring_napi = std.mem.zeroes(c.io_uring_napi),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// The busy poll timeout in microseconds.
    pub fn get_busy_poll_to(self: *const Self) u32 {
        return self._io_uring_napi.busy_poll_to;
    }

    pub fn set_busy_poll_to(self: *Self, value: u32) void {
        self._io_uring_napi.busy_poll_to = value;
    }

    /// Prefer busy polling over interrupts.
    pub fn get_prefer_busy_poll(self: *const Self) bool {
        return self._io_uring_napi.prefer_busy_poll != 0;
    }

    pub fn set_prefer_busy_poll(self: *Self, value: bool) void {
        self._io_uring_napi.prefer_busy_poll = @intFromBool(value);
    }
};

/// Asks the kernel what `io_uring` supports (`io_uring_register_query`; needs no ring).
///
/// Example
///     >>> query = Query()                   # IO_URING_QUERY_OPCODES
///     >>> io_uring_register_query(query)
///     0
///     >>> query.data["nr_request_opcodes"]  # the kernel's count
///     65
///     >>> query = Query(IO_URING_QUERY_SCQ)
///     >>> io_uring_register_query(query)
///     0
///     >>> query.data
///     {'hdr_size': 64, 'hdr_alignment': 64}
///
/// Note
///     - `query.data` has the fields of the C struct for `op`:
///     `IO_URING_QUERY_OPCODES` (`io_uring_query_opcode`), `IO_URING_QUERY_ZCRX` (`io_uring_query_zcrx`)
///     or `IO_URING_QUERY_SCQ` (`io_uring_query_scq`); all `0` until it is registered.
///     - `query.result` is the error the kernel put in the header (`0` on success).
pub const Query = struct {
    _hdr: c.io_uring_query_hdr = std.mem.zeroes(c.io_uring_query_hdr),
    _data: extern union {
        opcode: c.io_uring_query_opcode,
        zcrx: c.io_uring_query_zcrx,
        scq: c.io_uring_query_scq,
    } = std.mem.zeroes(@FieldType(Query, "_data")),

    const Self = @This();

    /// `op`: `IO_URING_QUERY_OPCODES` (default), `IO_URING_QUERY_ZCRX` or `IO_URING_QUERY_SCQ`; `ValueError` for
    /// any other.
    pub fn __new__(self: *Self, op: ?u32) py.Error!void {
        const _op = op orelse c.IO_URING_QUERY_OPCODES;
        if (_op >= c.__IO_URING_QUERY_MAX) return py.raiseValueError("`Query(op)` - unknown query `{d}`", .{_op});
        self._hdr.query_op = _op;
    }

    /// The query this was made for (`IO_URING_QUERY_*`).
    pub fn get_op(self: *const Self) u32 {
        return self._hdr.query_op;
    }

    /// The error the kernel put in the header (`0` on success).
    pub fn get_result(self: *const Self) i32 {
        return self._hdr.result;
    }

    /// The fields of the C struct for `op` by name (all `0` until it is registered).
    ///
    /// Type
    ///     return: dict[str, int]
    pub fn get_data(self: *const Self) py.Error!*Object {
        return switch (self._hdr.query_op) {
            c.IO_URING_QUERY_OPCODES => structDict(self._data.opcode, .{
                "nr_request_opcodes", "nr_register_opcodes", "feature_flags",    "ring_setup_flags",
                "enter_flags",        "sqe_flags",           "nr_query_opcodes",
            }),
            c.IO_URING_QUERY_ZCRX => structDict(self._data.zcrx, .{
                "register_flags", "area_flags", "nr_ctrl_opcodes", "features", "rq_hdr_size", "rq_hdr_alignment",
            }),
            else => structDict(self._data.scq, .{ "hdr_size", "hdr_alignment" }),
        };
    }
};

/// A `dict` of the `names` fields of `value`.
fn structDict(value: anytype, comptime names: anytype) py.Error!*Object {
    const dict = setu.c.PyDict_New() orelse return error.PythonError;
    // coverage-off: out of memory only
    errdefer py.decref(dict);
    // coverage-on
    inline for (names) |name| {
        const key = try py.new(name);
        defer py.decref(key);
        const item = try py.new(@as(u64, @field(value, name)));
        defer py.decref(item);
        if (setu.c.PyDict_SetItem(dict, key, item) < 0) return error.PythonError;
    }
    return dict;
}

/// Control of a zero-copy receive instance (`io_uring_register_zcrx_ctrl`).
///
/// Example
///     >>> ctrl = ZcrxCtrl(zcrx_id, ZCRX_CTRL_FLUSH_RQ)
///     >>> io_uring_register_zcrx_ctrl(ring, ctrl)
///     # or export it to share with another ring
///     >>> ctrl = ZcrxCtrl(zcrx_id, ZCRX_CTRL_EXPORT)
///     >>> io_uring_register_zcrx_ctrl(ring, ctrl)
///     >>> ctrl.zcrx_fd
///
/// Note
///     - `zcrx_id` is the `ZcrxIfqReg.zcrx_id` of `io_uring_register_ifq`; needs a registered instance.
///     - Not tested with a real device (needs a NIC whose driver supports zero-copy receive, like `mlx5`, `bnxt`,
///       `gve`): only the fields and the error without a device are.
pub const ZcrxCtrl = struct {
    _zcrx_ctrl: c.zcrx_ctrl = std.mem.zeroes(c.zcrx_ctrl),

    const Self = @This();

    /// `op`: `ZCRX_CTRL_*`; `ValueError` for an unknown one.
    pub fn __new__(self: *Self, zcrx_id: u32, op: u32) py.Error!void {
        if (op >= c.__ZCRX_CTRL_LAST) return py.raiseValueError("`ZcrxCtrl(zcrx_id, op)` - unknown op `{d}`", .{op});
        self._zcrx_ctrl.zcrx_id = zcrx_id;
        self._zcrx_ctrl.op = op;
    }

    /// The zero-copy receive instance the control is for.
    pub fn get_zcrx_id(self: *const Self) u32 {
        return self._zcrx_ctrl.zcrx_id;
    }

    /// The control operation (`ZCRX_CTRL_*`).
    pub fn get_op(self: *const Self) u32 {
        return self._zcrx_ctrl.op;
    }

    /// The file descriptor `ZCRX_CTRL_EXPORT` wrote.
    pub fn get_zcrx_fd(self: *const Self) u32 {
        return self._zcrx_ctrl.unnamed_0.zc_export.zcrx_fd;
    }
};

/// Zero-copy receive queue registration (`io_uring_register_ifq`); needs a network device that supports it.
///
/// Example
///     >>> reg = ZcrxIfqReg()
///     >>> reg.if_idx = socket.if_nametoindex("eth0")
///     >>> reg.if_rxq = 0
///     >>> reg.rq_entries = 4096
///     >>> reg.area = mmap.mmap(-1, 64 * 4096)    # also `area_len`
///     >>> reg.region = mmap.mmap(-1, 4 * 4096)   # the refill queue; also `region_size`, `region_flags`
///     >>> io_uring_register_ifq(ring, reg)
///     0
///     >>> reg.zcrx_id
///     0
///
/// Note
///     - `area` and `region` are the memory itself, not addresses: the ring keeps them locked from the register
///       until its exit (the device writes into `area`). `region = None`: the kernel allocates the refill queue.
///     - Not tested with a real device (needs a NIC whose driver supports zero-copy receive, like `mlx5`, `bnxt`,
///       `gve`): only the fields and the error without a device are.
pub const ZcrxIfqReg = struct {
    _io_uring_zcrx_ifq_reg: c.io_uring_zcrx_ifq_reg = std.mem.zeroes(c.io_uring_zcrx_ifq_reg),
    _area: c.io_uring_zcrx_area_reg = std.mem.zeroes(c.io_uring_zcrx_area_reg), // what `area_ptr` points to
    _region: c.io_uring_region_desc = std.mem.zeroes(c.io_uring_region_desc), // what `region_ptr` points to
    _area_mem: ?*Object = null, // the memory `_area.addr` is set to at the register
    _region_mem: ?*Object = null, // the memory `_region.user_addr` is set to at the register

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// The receive area: a writable, page-aligned buffer (`mmap.mmap`) the device writes into. Setting it sets
    /// `area_len` to its length (it may be lowered); `None` for none (a dma-buf: `area_dmabuf_fd`).
    ///
    /// Type
    ///     return: Buffer | None
    pub fn get_area(self: *const Self) ?*Object {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, ZcrxIfqRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        return if (self._area_mem) |o| keep(o) else null; // a new reference
    }

    /// Sets `area`.
    ///
    /// Type
    ///     value: Buffer | None
    pub fn set_area(self: *Self, value: ?*Object) py.Error!void {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, ZcrxIfqRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        self._area.len = try setMemory(&self._area_mem, value);
        self._area.addr = 0;
    }

    /// The refill queue's memory: a writable, page-aligned buffer (`mmap.mmap`). Setting it sets `region_size`
    /// to its length (it may be lowered) and `IORING_MEM_REGION_TYPE_USER` in `region_flags`; `None` clears
    /// both (the kernel allocates it).
    ///
    /// Type
    ///     return: Buffer | None
    pub fn get_region(self: *const Self) ?*Object {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, ZcrxIfqRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        return if (self._region_mem) |o| keep(o) else null; // a new reference
    }

    /// Sets `region`.
    ///
    /// Type
    ///     value: Buffer | None
    pub fn set_region(self: *Self, value: ?*Object) py.Error!void {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, ZcrxIfqRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        try setRegion(&self._region_mem, &self._region, value);
    }

    /// The locked views `io_uring_register_ifq` hands the kernel (`null`: none), the addresses set to them.
    pub fn lockViews(self: *Self) py.Error![2]?setu.c.Buffer {
        self._area.addr = 0;
        const area: ?setu.c.Buffer =
            if (self._area_mem) |o| try lockMemory(o, self._area.len, "ZcrxIfqReg.area") else null;
        errdefer if (area) |a| {
            var v = a;
            setu.c.PyBuffer_Release(&v);
        };
        if (area) |a| self._area.addr = @intFromPtr(a.buf);
        return .{ area, try lockRegion(&self._region, self._region_mem, "ZcrxIfqReg.region") };
    }

    /// The network interface index (`socket.if_nametoindex`).
    pub fn get_if_idx(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.if_idx;
    }

    pub fn set_if_idx(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.if_idx = value;
    }

    /// The receive queue of the interface.
    pub fn get_if_rxq(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.if_rxq;
    }

    pub fn set_if_rxq(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.if_rxq = value;
    }

    /// The number of entries in the refill queue.
    pub fn get_rq_entries(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.rq_entries;
    }

    pub fn set_rq_entries(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.rq_entries = value;
    }

    /// `ZCRX_REG_*` flags.
    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.flags = value;
    }

    /// The receive buffer length (`0`: the default).
    pub fn get_rx_buf_len(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.rx_buf_len;
    }

    pub fn set_rx_buf_len(self: *Self, value: u32) void {
        self._io_uring_zcrx_ifq_reg.rx_buf_len = value;
    }

    /// The id of the instance, set by `io_uring_register_ifq`.
    pub fn get_zcrx_id(self: *const Self) u32 {
        return self._io_uring_zcrx_ifq_reg.zcrx_id;
    }

    /// The length of `area` in bytes.
    pub fn get_area_len(self: *const Self) u64 {
        return self._area.len;
    }

    pub fn set_area_len(self: *Self, value: u64) void {
        self._area.len = value;
    }

    /// `IORING_ZCRX_AREA_*` flags.
    pub fn get_area_flags(self: *const Self) u32 {
        return self._area.flags;
    }

    pub fn set_area_flags(self: *Self, value: u32) void {
        self._area.flags = value;
    }

    /// The dma-buf file descriptor for an `area` of `None`.
    pub fn get_area_dmabuf_fd(self: *const Self) u32 {
        return self._area.dmabuf_fd;
    }

    pub fn set_area_dmabuf_fd(self: *Self, value: u32) void {
        self._area.dmabuf_fd = value;
    }

    /// The token the kernel gave for the area, set by `io_uring_register_ifq`.
    pub fn get_area_rq_area_token(self: *const Self) u64 {
        return self._area.rq_area_token;
    }

    /// The size of `region` in bytes.
    pub fn get_region_size(self: *const Self) u64 {
        return self._region.size;
    }

    pub fn set_region_size(self: *Self, value: u64) void {
        self._region.size = value;
    }

    /// `IORING_MEM_REGION_*` flags of `region`.
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
///     0
pub const ClockRegister = struct {
    _io_uring_clock_register: c.io_uring_clock_register = std.mem.zeroes(c.io_uring_clock_register),

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// The clock id (`time.CLOCK_*`).
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
///     >>> bpf.opcode = io_uring_op.IORING_OP_OPENAT
///     >>> program = struct.pack("HBBI", 0x06, 0, 0, 0)  # `BPF_RET | BPF_K` 0: deny every `openat`
///     >>> bpf.filter = program          # `struct sock_filter` instructions (8 bytes each), hold on to it
///     >>> io_uring_register_bpf_filter(ring, bpf)
///     0
pub const Bpf = struct {
    _io_uring_bpf: c.io_uring_bpf = std.mem.zeroes(c.io_uring_bpf),
    _program: ?*Object = null, // the buffer `filter_ptr` points into

    pub fn __new__(self: *Self) void { // no arguments: `TypeError` for any
        self._io_uring_bpf.cmd_type = c.IO_URING_BPF_CMD_FILTER;
    }
    const Self = @This();

    /// The command type (`IO_URING_BPF_CMD_*`); `IO_URING_BPF_CMD_FILTER` by default.
    pub fn get_cmd_type(self: *const Self) u16 {
        return self._io_uring_bpf.cmd_type;
    }

    pub fn set_cmd_type(self: *Self, value: u16) void {
        self._io_uring_bpf.cmd_type = value;
    }

    /// The command flags.
    pub fn get_cmd_flags(self: *const Self) u16 {
        return self._io_uring_bpf.cmd_flags;
    }

    pub fn set_cmd_flags(self: *Self, value: u16) void {
        self._io_uring_bpf.cmd_flags = value;
    }

    /// The opcode of the requests to filter (`IORING_OP_*`).
    pub fn get_opcode(self: *const Self) u32 {
        return self._io_uring_bpf.unnamed_0.filter.opcode;
    }

    pub fn set_opcode(self: *Self, value: u32) void {
        self._io_uring_bpf.unnamed_0.filter.opcode = value;
    }

    /// The filter flags.
    pub fn get_flags(self: *const Self) u32 {
        return self._io_uring_bpf.unnamed_0.filter.flags;
    }

    pub fn set_flags(self: *Self, value: u32) void {
        self._io_uring_bpf.unnamed_0.filter.flags = value;
    }

    /// The size of the per-request data the filter sees.
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
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, BpfType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        const buf = try py.Buffer.from(program);
        defer buf.deinit();
        if (buf.data.len % 8 != 0) return py.raiseValueError(
            "`filter` must be a multiple of 8 bytes (one `sock_filter` each)",
            .{},
        );
        const filter = &self._io_uring_bpf.unnamed_0.filter;
        filter.filter_ptr = @intFromPtr(buf.data.ptr);
        filter.filter_len = @intCast(buf.data.len / 8); // cast: the filter limit is far below u32
        setOwned(&self._program, program);
    }

    /// The program set by `filter`, or `None`.
    pub fn get_filter(self: *const Self) ?*Object {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, BpfType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        return if (self._program) |o| keep(o) else null; // a new reference
    }
};

/// Registers memory the ring uses itself (`io_uring_register_region`): `flags` for the registration and the
/// region's description (`region_*`).
///
/// Example
///     >>> mem = mmap.mmap(-1, 4096)
///     >>> reg = MemRegionReg()
///     >>> reg.region = mem      # also `region_size = len(mem)` and `IORING_MEM_REGION_TYPE_USER` in `region_flags`
///     >>> reg.flags = IORING_MEM_REGION_REG_WAIT_ARG
///     >>> io_uring_register_region(ring, reg)  # `ring` set up with `IORING_SETUP_R_DISABLED`
///     0
///
/// Note
///     - `region` is the memory itself, not its address: the ring keeps it locked from the register until its
///       exit (a region can not be unregistered).
pub const MemRegionReg = struct {
    _io_uring_mem_region_reg: c.io_uring_mem_region_reg = std.mem.zeroes(c.io_uring_mem_region_reg),
    _desc: c.io_uring_region_desc = std.mem.zeroes(c.io_uring_region_desc), // what `region_uptr` points to
    _region: ?*Object = null, // the memory `_desc.user_addr` is set to at the register

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any
    const Self = @This();

    /// `IORING_MEM_REGION_REG_*` flags of the registration.
    pub fn get_flags(self: *const Self) u64 {
        return self._io_uring_mem_region_reg.flags;
    }

    pub fn set_flags(self: *Self, value: u64) void {
        self._io_uring_mem_region_reg.flags = value;
    }

    /// The region's memory: a writable, page-aligned buffer (`mmap.mmap`). Setting it sets `region_size` to its
    /// length (it may be lowered) and `IORING_MEM_REGION_TYPE_USER` in `region_flags`; `None` clears both (the
    /// kernel allocates the region).
    ///
    /// Type
    ///     return: Buffer | None
    pub fn get_region(self: *const Self) ?*Object {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, MemRegionRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        return if (self._region) |o| keep(o) else null; // a new reference
    }

    /// Sets `region`.
    ///
    /// Type
    ///     value: Buffer | None
    pub fn set_region(self: *Self, value: ?*Object) py.Error!void {
        var cs: setu.c.CriticalSection = undefined; // free-threaded: a get / set / register from another thread waits
        setu.c.PyCriticalSection_Begin(&cs, MemRegionRegType.object(@constCast(self)));
        defer setu.c.PyCriticalSection_End(&cs);
        try setRegion(&self._region, &self._desc, value);
    }

    /// The locked view `io_uring_register_region` hands the kernel (`null`: no `region`).
    pub fn lockViews(self: *Self) py.Error!?setu.c.Buffer {
        return lockRegion(&self._desc, self._region, "MemRegionReg.region");
    }

    /// The size of `region` in bytes.
    pub fn get_region_size(self: *const Self) u64 {
        return self._desc.size;
    }

    pub fn set_region_size(self: *Self, value: u64) void {
        self._desc.size = value;
    }

    /// `IORING_MEM_REGION_TYPE_*` flags of `region`.
    pub fn get_region_flags(self: *const Self) u32 {
        return self._desc.flags;
    }

    pub fn set_region_flags(self: *Self, value: u32) void {
        self._desc.flags = value;
    }

    /// The region id.
    pub fn get_region_id(self: *const Self) u32 {
        return self._desc.id;
    }

    pub fn set_region_id(self: *Self, value: u32) void {
        self._desc.id = value;
    }

    /// The offset to `mmap` the region at, when the kernel allocated it.
    pub fn get_region_mmap_offset(self: *const Self) u64 {
        return self._desc.mmap_offset;
    }

    pub fn set_region_mmap_offset(self: *Self, value: u64) void {
        self._desc.mmap_offset = value;
    }
};

/// A buffer ring made by `io_uring_setup_buf_ring` (not instantiable): add buffers with `io_uring_buf_ring_add`,
/// then `io_uring_buf_ring_advance`.
pub const BufRing = struct {
    _io_uring_buf_ring: ?[*]c.io_uring_buf_ring = null,
    // note: `io_uring_free_buf_ring()` should be called manually to free the memory.
    _bgid: i32 = 0,
    /// The buffer added for each id (`io_uring_buf_ring_add`): a locked view, until the id is added again or
    /// this is freed. The `Ring` holds its `BufRing`s until `io_uring_free_buf_ring` / `_unregister_buf_ring`
    /// or its exit, so the kernel never fills a released buffer.
    _views: std.ArrayList(?setu.c.Buffer) = .empty,

    pub const instantiable = false;

    /// GC: the buffers added to it, so a cycle through one can be collected. No `__clear__`: the kernel fills
    /// them until the ring lets go of the `BufRing` (the ring's `__clear__` exits first).
    pub fn __traverse__(self: *const BufRing, v: *setu.Visit) setu.Visit.Error!void {
        for (self._views.items) |view| if (view) |b| try v.add(b.obj);
    }

    pub fn __del__(self: *BufRing) void {
        for (self._views.items) |*view| if (view.*) |*v| setu.c.PyBuffer_Release(v);
        self._views.deinit(std.heap.c_allocator);
    }

    /// Keeps `view` (owned from here) for the buffer id `bid`, releasing the one it replaces.
    pub fn keepView(self: *BufRing, bid: u16, view: setu.c.Buffer) py.Error!void {
        var v = view;
        if (bid >= self._views.items.len) {
            self._views.appendNTimes(std.heap.c_allocator, null, bid + 1 - self._views.items.len) catch {
                // coverage-off: out of memory only
                setu.c.PyBuffer_Release(&v);
                return e.raiseMemoryError("Out of Memory!");
                // coverage-on
            };
        }
        const slot = &self._views.items[bid];
        var old = slot.*;
        slot.* = v;
        if (old) |*o| setu.c.PyBuffer_Release(o);
    }
};

/// Sets a register struct's memory field (`BufReg.ring`, `MemRegionReg.region`, ...) to `value`: a writable
/// buffer (`TypeError` now, not at the register) or `None`. Locked only by the register (`lockMemory`).
/// Returns its length in bytes (`0` for `None`).
fn setMemory(field: *?*Object, value: ?*Object) py.Error!u64 {
    const obj = (if (value) |v| (if (v == py.none()) null else v) else null) orelse {
        const old = field.*;
        field.* = null;
        py.decref(old);
        return 0;
    };
    const b = try py.WritableBuffer.from(obj);
    defer b.deinit();
    setOwned(field, obj);
    return b.data.len;
}

/// A locked, writable view of `obj` (at least `need` bytes, else `ValueError` naming `what`) for the kernel to
/// use until an unregister or the ring's exit (`Ring.keepMemory`).
fn lockMemory(obj: *Object, need: u64, comptime what: []const u8) py.Error!setu.c.Buffer {
    const b = try py.WritableBuffer.from(obj); // still writable: `TypeError` if it is not
    if (b.data.len < need) {
        b.deinit();
        return py.raiseValueError("`" ++ what ++ "` is {d} bytes, the registration needs {d}", .{ b.data.len, need });
    }
    return b.view;
}

/// Sets a region description's user memory (`MemRegionReg.region`, `ZcrxIfqReg.region`): `size` becomes its
/// length and `IORING_MEM_REGION_TYPE_USER` is set; `None` clears all three (the kernel allocates the region).
fn setRegion(field: *?*Object, desc: *c.io_uring_region_desc, value: ?*Object) py.Error!void {
    desc.size = try setMemory(field, value);
    desc.user_addr = 0;
    if (field.* != null) {
        desc.flags |= c.IORING_MEM_REGION_TYPE_USER;
    } else {
        desc.flags &= ~@as(u32, c.IORING_MEM_REGION_TYPE_USER);
    }
}

/// The locked view of a region's user memory (`null`: none), `user_addr` set to it; `size` must fit in it.
fn lockRegion(desc: *c.io_uring_region_desc, obj: ?*Object, comptime what: []const u8) py.Error!?setu.c.Buffer {
    desc.user_addr = 0;
    const o = obj orelse return null;
    const view = try lockMemory(o, desc.size, what);
    desc.user_addr = @intFromPtr(view.buf);
    return view;
}

/// Always `EINVAL`: C liburing no longer supports it (see `RegWait`, `io_uring_register_region`). `nr` must be `1`
/// (`ValueError` otherwise).
pub fn io_uring_register_wait_reg(ring: *Ring, reg: *RegWait, nr: i32) py.Error!i32 {
    if (nr != 1) return py.raiseValueError(
        "`io_uring_register_wait_reg(nr)` - only one `RegWait` can be registered from Python for now",
        .{},
    );
    return py.checkErrno(c.io_uring_register_wait_reg(try ring.checkedPtr(), &reg._io_uring_reg_wait, nr));
}

/// Like `io_uring_clone_buffers`, but clones `nr` buffers from `src_off` of `src_ring` to `dst_off` of `dst_ring`.
///
/// Flags
///     IORING_REGISTER_SRC_REGISTERED  # Find src_ring by its registered ring fd (this thread registered it).
///     IORING_REGISTER_DST_REPLACE     # Allow a dst_ring with buffers: the slots in range are replaced.
///
/// Note
///     - Linux 6.13+. Returns `0`. `dst_off`, `src_off` and `nr` all `0`: the whole table, as
///       `io_uring_clone_buffers`.
///     - `OSError`: `EBUSY` when `dst_ring` has buffers registered and `IORING_REGISTER_DST_REPLACE` is not set,
///       `ENXIO` when `src_ring` has none.
///     - `dst_ring` holds every buffer registered on `src_ring` (not only the cloned ones) until its own
///     `io_uring_unregister_buffers` (or its exit), as `io_uring_clone_buffers` does.
///     - Linux 7.2+ (kernel bug): cloning some of `src_ring`'s buffers, when one shares a huge page with a buffer
///     not cloned, miscounts locked memory. Unregistering (or exiting) `src_ring` first stops counting memory
///     that `dst_ring` still pins; then `dst_ring` uncounts it again: the user's count goes below `0`, and every
///     small buffer registration fails with `OSError: ENOMEM` until a reboot. Clone the whole table
///     (`io_uring_clone_buffers`), or keep each registered buffer off shared huge pages (e.g. its own
///     `mmap.mmap` with `madvise(mmap.MADV_NOHUGEPAGE)`).
pub fn io_uring_clone_buffers_offset(
    dst_ring: *Ring,
    src_ring: *Ring,
    dst_off: c_uint,
    src_off: c_uint,
    nr: c_uint,
    flags: ?c_uint,
) py.Error!i32 {
    const dst = try dst_ring.checkedPtr();
    const src = try src_ring.checkedPtr();
    try dst_ring.reserveShared(src_ring); // before the clone: nothing can fail after it
    const res = try support.register(
        "IORING_REGISTER_CLONE_BUFFERS",
        c.io_uring_clone_buffers_offset(dst, src, dst_off, src_off, nr, flags orelse 0),
    );
    dst_ring.shareRegistered(src_ring);
    return res;
}

/// Register the buffers registered on `src_ring` with `dst_ring` too (the kernel shares them).
///
/// Example
///     >>> bufs = [bytearray(4096)]
///     >>> io_uring_register_buffers(src, bufs)
///     0
///     >>> io_uring_clone_buffers(dst, src)
///     0
///     >>> io_uring_unregister_buffers(src)  # `dst` still uses them: `bufs` stay locked
///     0
///     >>> io_uring_unregister_buffers(dst)  # released
///     0
///
/// Note
///     - Linux 6.12+. Returns `0`; afterwards both rings have the same registered buffers (as if
///       `io_uring_register_buffers` had been called on `dst_ring` with them).
///     - `OSError`: `EBUSY` when `dst_ring` already has buffers registered (unregister them first, or clone with
///       `IORING_REGISTER_DST_REPLACE`, see `io_uring_clone_buffers_offset`), `ENXIO` when `src_ring` has none.
///     - `flags` defaults to `0` (C's `__io_uring_clone_buffers`): the rings are found by their real file
///       descriptors, so these must still be open; `IORING_REGISTER_SRC_REGISTERED` uses `src_ring`'s registered
///       ring fd instead, which only the thread that registered it can.
///     - Both rings must belong to the calling thread.
///     - `dst_ring` holds `src_ring`'s registered buffers until its own `io_uring_unregister_buffers` (or
///     its exit): each ring keeps them locked (no resize) while the kernel can use them through it.
pub fn io_uring_clone_buffers(dst_ring: *Ring, src_ring: *Ring, flags: ?u32) py.Error!i32 {
    const dst = try dst_ring.checkedPtr();
    const src = try src_ring.checkedPtr();
    try dst_ring.reserveShared(src_ring); // before the clone: nothing can fail after it
    const res = try support.register(
        "IORING_REGISTER_CLONE_BUFFERS",
        c.__io_uring_clone_buffers(dst, src, flags orelse 0),
    );
    dst_ring.shareRegistered(src_ring);
    return res;
}

/// Register the buffers `bufs` with the ring, with an optional `tags` for each.
///
/// Example
///     >>> bufs = [bytearray(4096), bytearray(4096)]
///     >>> io_uring_register_buffers(ring, bufs)
///     0
///     >>> io_uring_unregister_buffers(ring)
///     0
///
/// Example
///     # with a tag for each buffer
///     >>> bufs = [bytearray(4096), bytearray(4096)]
///     >>> io_uring_register_buffers(ring, bufs, [1, 2])
///     0
///
/// Note
///     - `io_uring_register_buffers` includes `io_uring_register_buffers_tags`
///     - Linux 5.13+ (`IORING_REGISTER_BUFFERS2`). Returns `0`. Use the buffers with the `*_fixed` requests
///       (`io_uring_prep_read_fixed`, ...) by their index in `bufs`; a request may cover any part of its buffer.
///     - `bufs`: writable buffers; the kernel pins them until `io_uring_unregister_buffers` (or the ring's
///       exit), so the ring holds them (locked: no resize) until then.
///     - `bufs` must be anonymous memory (`bytearray`, `mmap.mmap(-1, ...)`; file-backed memory fails with
///       `EOPNOTSUPP` or `EFAULT`), each at most 1 GiB (`EFAULT`), at most 1024 of them (`EINVAL`). A buffer
///       on a huge page pins the whole page. Before Linux 5.12 they count against `RLIMIT_MEMLOCK` (`ENOMEM`).
///     - `OSError: EBUSY` when buffers are already registered: unregister them first (registering again is how
///       to change the set). Before Linux 5.13 the registration waits for the ring to go idle.
///     - `tags` needs one item for each buffer in `bufs`. A tag of `0` means none; for any other, once the
///       buffer is unregistered (or replaced) and no request uses it any more, a CQE is posted with `user_data`
///       set to the tag and every other field `0`.
pub fn io_uring_register_buffers(
    ring: *Ring,
    bufs: py.Sequence(py.WritableBuffer),
    tags: ?py.Sequence(u64),
) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, bufs.items.len, "io_uring_register_buffers");
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_register_buffers(bufs)");
    const res = c.io_uring_register_buffers_tags(ptr, vec.iov.ptr, _tags, @intCast(vec.iov.len)); // cast: <= IOV_MAX
    if (res < 0) vec.destroy() else try ring.keepRegistered(vec);
    return support.register("IORING_REGISTER_BUFFERS2", res);
}

/// The `__u64 *tags` for C: `null` for no tags, else the list, which must have one item for each of `count`.
fn tagsPtr(tags: ?py.Sequence(u64), count: usize, comptime name: []const u8) py.Error!?[*]const u64 {
    const list = tags orelse return null;
    if (list.items.len != count) return py.raiseValueError(
        "`" ++ name ++ "(..., tags)` - length of {d} does not match {d}",
        .{ list.items.len, count },
    );
    return list.items.ptr;
}

/// Register `nr` empty buffer slots, to fill with `io_uring_register_buffers_update_tag`.
///
/// Note
///     - Linux 5.19+ (`IORING_RSRC_REGISTER_SPARSE`). Returns `0`; `OSError: EBUSY` when buffers are already
///       registered.
pub fn io_uring_register_buffers_sparse(ring: *Ring, nr: u32) py.Error!i32 {
    return support.register("IORING_REGISTER_BUFFERS2", c.io_uring_register_buffers_sparse(try ring.checkedPtr(), nr));
}

/// Update the registered buffers from slot `offset` (default `0`) with `bufs` and `tags`.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - Linux 5.13+. Returns the number of buffers updated. A slot may be empty (from
///       `io_uring_register_buffers_sparse`) or already in use: a replaced buffer stays valid until the requests
///       using it complete, then its tag's CQE (see `io_uring_register_buffers`) is posted.
///     - The ring holds `bufs` until `io_uring_unregister_buffers` (or its exit); the buffers they replace too.
pub fn io_uring_register_buffers_update_tag(
    ring: *Ring,
    bufs: py.Sequence(py.WritableBuffer),
    tags: py.Sequence(u64),
    offset: ?u32,
) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, bufs.items.len, "io_uring_register_buffers_update_tag");
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_register_buffers_update_tag(bufs)");
    // cast: <= IOV_MAX
    const res = c.io_uring_register_buffers_update_tag(ptr, offset orelse 0, vec.iov.ptr, _tags, @intCast(vec.iov.len));
    if (res < 0) vec.destroy() else try ring.keepRegistered(vec);
    return support.register("IORING_REGISTER_BUFFERS_UPDATE", res);
}

/// Unregister all buffers.
///
/// Note
///     - Returns `0`; `OSError: ENXIO` when none are registered. Not needed before `io_uring_queue_exit`, which
///       unregisters them too (the pages may be unpinned a little later then).
///     - A CQE is posted for each tagged buffer (`io_uring_register_buffers`) once no request uses it.
///     - Releases the buffers the ring held for the registrations (`io_uring_register_buffers` / `_update_tag`).
pub fn io_uring_unregister_buffers(ring: *Ring) py.Error!i32 {
    const res = c.io_uring_unregister_buffers(try ring.checkedPtr());
    if (res == 0) ring.releaseRegistered();
    return support.register("IORING_UNREGISTER_BUFFERS", res);
}

/// Register the file descriptors of `files`.
///
/// Example
///     >>> ids = FileIndex([fd, -1, -1])  # `-1`: an empty slot
///     >>> io_uring_register_files(ring, ids)
///     0
///     >>> io_uring_unregister_files(ring)
///     0
///
/// Note
///     - Returns `0`. Use a registered file with `IOSQE_FIXED_FILE` in the sqe's `flags` and its index in
///       `files` as the sqe's `fd`. A file table is also what direct descriptors (`*_direct` requests) live in.
///     - The kernel copies the descriptors at registration: `ids` can be freed, and the fds closed, afterwards
///       (the ring holds its own reference to each file).
///     - `OSError`: `EBUSY` when files are already registered (unregister first, or use
///       `io_uring_register_files_update`), `EMFILE` over the fixed file table maximum or, for an unprivileged
///       user, over `RLIMIT_NOFILE` (a per user limit), `EBADF` for a descriptor that is not open.
///       Before Linux 5.13 the registration waits for the ring to go idle.
///     - "Registered files have less overhead per operation than normal files.
///     This is due to the kernel grabbing a reference count on a file when an
///     operation begins, and dropping it when it's done. When the process file
///     table is shared, for example if the process has ever created any
///     threads, then this cost goes up even more. Using registered files
///     reduces the overhead of file reference management across requests that
///     operate on a file."
pub fn io_uring_register_files(ring: *Ring, files: *const FileIndex) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_FILES",
        c.io_uring_register_files(try ring.checkedPtr(), files.fdSlice().ptr, @intCast(files._len)),
    );
}

/// Register the file descriptors of `files`, with a tag for each.
///
/// Example
///     >>> io_uring_register_files_tags(ring, FileIndex([fd, -1]), [1, 0])  # an empty slot takes no tag
///     0
///
/// Note
///     - Linux 5.13+ (`IORING_REGISTER_FILES2`). Returns `0`; the errors of `io_uring_register_files`.
///     - `tags` needs one item for each file in `files`. A tag of `0` means none; for any other, once the file
///       is unregistered (or replaced) and no request uses it any more, a CQE is posted with `user_data` set to
///       the tag and every other field `0`.
pub fn io_uring_register_files_tags(ring: *Ring, files: *const FileIndex, tags: py.Sequence(u64)) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, files._len, "io_uring_register_files_tags");
    return support.register(
        "IORING_REGISTER_FILES2",
        c.io_uring_register_files_tags(ptr, files.fdSlice().ptr, _tags, @intCast(files._len)),
    );
}

/// Register `nr` empty file slots (`-1`), to fill with `io_uring_register_files_update` or direct descriptors.
///
/// Note
///     - Linux 5.19+. Returns `0`; `OSError: EBUSY` when files are already registered.
///     - If `nr` is over `RLIMIT_NOFILE`, C liburing raises the limit (`setrlimit`) and retries before failing.
pub fn io_uring_register_files_sparse(ring: *Ring, nr: u32) py.Error!i32 {
    return support.register("IORING_REGISTER_FILES2", c.io_uring_register_files_sparse(try ring.checkedPtr(), nr));
}

/// Update the registered files from slot `offset` (default `0`) with `files` and `tags`.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - Linux 5.13+. Returns the number of files updated. In `files`, `-1` empties a slot and
///       `IORING_REGISTER_FILES_SKIP` leaves one as it is; a replaced file stays open for the requests using
///       it, then its tag's CQE (see `io_uring_register_files_tags`) is posted.
pub fn io_uring_register_files_update_tag(
    ring: *Ring,
    files: *const FileIndex,
    tags: py.Sequence(u64),
    offset: ?u32,
) py.Error!i32 {
    const ptr = try ring.checkedPtr();
    const _tags = try tagsPtr(tags, files._len, "io_uring_register_files_update_tag");
    const _offset = offset orelse 0;
    return support.register(
        "IORING_REGISTER_FILES_UPDATE2",
        c.io_uring_register_files_update_tag(ptr, _offset, files.fdSlice().ptr, _tags, @intCast(files._len)),
    );
}

/// Unregister all files.
///
/// Example
///     >>> io_uring_register_files_sparse(ring, 4)
///     0
///     >>> io_uring_unregister_files(ring)
///     0
///
/// Note
///     - Returns `0`; `OSError: ENXIO` when none are registered. Not needed before `io_uring_queue_exit`, which
///       unregisters them too; a CQE is posted for each tagged file (`io_uring_register_files_tags`).
pub fn io_uring_unregister_files(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_FILES", c.io_uring_unregister_files(try ring.checkedPtr()));
}

/// Update the registered files from slot `offset` (default `0`) with `fds`.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - Linux 5.5+. Returns the number of files updated. In `fds`, `-1` empties a slot (closing a direct
///       descriptor) and `IORING_REGISTER_FILES_SKIP` (Linux 5.12+) leaves one as it is. Unlike a registration,
///       an update never waits for the ring to go idle (since Linux 5.13).
pub fn io_uring_register_files_update(ring: *Ring, fds: *const FileIndex, offset: ?u32) py.Error!i32 {
    const _offset = offset orelse 0;
    return support.register(
        "IORING_REGISTER_FILES_UPDATE",
        c.io_uring_register_files_update(try ring.checkedPtr(), _offset, fds.fdSlice().ptr, @intCast(fds._len)),
    );
}

/// Register an eventfd `fd` that is signalled for each completion.
///
/// Example
///     >>> efd = os.eventfd(0)
///     >>> io_uring_register_eventfd(ring, efd)
///     0
///
/// Note
///     - Returns `0`. A ring has at most one eventfd.
///     - A signal is only a hint to check the CQ ring: spurious ones happen, and a batch of completions may
///       signal once.
pub fn io_uring_register_eventfd(ring: *Ring, fd: i32) py.Error!i32 {
    return support.register("IORING_REGISTER_EVENTFD", c.io_uring_register_eventfd(try ring.checkedPtr(), fd));
}

/// Like `io_uring_register_eventfd`, but only signalled for requests completed asynchronously.
///
/// Note
///     - Linux 5.6+. A request that completes inline during `io_uring_submit` does not signal.
pub fn io_uring_register_eventfd_async(ring: *Ring, fd: i32) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_EVENTFD_ASYNC",
        c.io_uring_register_eventfd_async(try ring.checkedPtr(), fd),
    );
}

/// Unregister the eventfd.
///
/// Example
///     >>> io_uring_register_eventfd(ring, os.eventfd(0))
///     0
///     >>> io_uring_unregister_eventfd(ring)
///     0
pub fn io_uring_unregister_eventfd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_EVENTFD", c.io_uring_unregister_eventfd(try ring.checkedPtr()));
}

/// Register the credentials of the calling task and give their id (use as `personality` of an sqe).
///
/// Example
///     >>> io_uring_register_personality(ring)
///     1
///
/// Note
///     - Linux 5.6+. Returns a positive id. An sqe with it in `personality` runs with these credentials: a
///       ring shared between users or processes keeps them separate this way.
pub fn io_uring_register_personality(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_PERSONALITY", c.io_uring_register_personality(try ring.checkedPtr()));
}

/// Unregister the personality `id`.
///
/// Example
///     >>> id = io_uring_register_personality(ring)
///     >>> io_uring_unregister_personality(ring, id)
///     0
///
/// Note
///     - Returns `0`; `OSError` for an id not registered. `id` must not be used in an sqe afterwards.
pub fn io_uring_unregister_personality(ring: *Ring, id: i32) py.Error!i32 {
    return support.register(
        "IORING_UNREGISTER_PERSONALITY",
        c.io_uring_unregister_personality(try ring.checkedPtr(), id),
    );
}

/// Register the restrictions added to `res` (`ValueError` if it is empty), for a ring set up with
/// `IORING_SETUP_R_DISABLED`.
///
/// Note
///     - Linux 5.10+. Returns `0`. The restrictions are an allowlist (an opcode or flag not added is denied,
///       `OSError: EACCES` for the request or register call), registered all in one call before
///       `io_uring_enable_rings`.
///     - `OSError`: `EBADFD` when the ring is not disabled, `EBUSY` when restrictions are already registered,
///       `EINVAL` for an unknown restriction opcode or too many restrictions.
pub fn io_uring_register_restrictions(ring: *Ring, res: *Restriction) py.Error!i32 {
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, RestrictionType.object(res));
    defer setu.c.PyCriticalSection_End(&cs);
    return support.register(
        "IORING_REGISTER_RESTRICTIONS",
        c.io_uring_register_restrictions(
            try ring.checkedPtr(),
            res._io_uring_restriction orelse return py.raiseValueError(
                "`Restriction()` is empty: `add()` what is allowed",
                .{},
            ),
            @intCast(res._len),
        ),
    );
}

/// Enable a ring set up with `IORING_SETUP_R_DISABLED`.
///
/// Example
///     >>> ring = Ring()
///     >>> param = Param()
///     >>> param.flags = IORING_SETUP_R_DISABLED
///     >>> io_uring_queue_init_params(8, ring, param)
///     0
///     >>> io_uring_enable_rings(ring)
///     0
///     >>> io_uring_queue_exit(ring)
///
/// Note
///     - Linux 5.10+. Returns `0`; `OSError: EBADFD` when the ring is not disabled. Nothing can be submitted
///       before it; registrations before it are unrestricted, after it they (and submissions) are checked
///       against the restrictions registered (`io_uring_register_restrictions`).
pub fn io_uring_enable_rings(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_ENABLE_RINGS", c.io_uring_enable_rings(try ring.checkedPtr()));
}

/// Register the ring's own file descriptor, so `io_uring_enter` calls skip the fd lookup (`1` on success).
///
/// Example
///     >>> io_uring_register_ring_fd(ring)
///     1
///
/// Note
///     - Linux 5.18+. Worth it in a threaded process (its file table is shared, so the lookup costs more).
///     - The registration is per thread: a ring shared between threads (one submits, another reaps) can not
///       use it, as each thread would have its own index. At most 16 ring fds per thread.
///     - Not undone when the thread outlives the ring: `io_uring_queue_exit` unregisters it, else
///       `io_uring_unregister_ring_fd` frees the slot.
pub fn io_uring_register_ring_fd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_REGISTER_RING_FDS", c.io_uring_register_ring_fd(try ring.checkedPtr()));
}

/// Unregister the ring's registered file descriptor (`1` on success).
///
/// Example
///     >>> io_uring_register_ring_fd(ring)
///     1
///     >>> io_uring_unregister_ring_fd(ring)
///     1
///
/// Note
///     - Linux 5.18+. `io_uring_queue_exit` does it too; call it to free one of the 16 slots earlier.
pub fn io_uring_unregister_ring_fd(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_RING_FDS", c.io_uring_unregister_ring_fd(try ring.checkedPtr()));
}

/// Close the ring's real file descriptor, keeping only the registered one (`io_uring_register_ring_fd` first).
///
/// Example
///     >>> io_uring_register_ring_fd(ring)
///     1
///     >>> io_uring_close_ring_fd(ring)
///     1
///
/// Note
///     - Needs `IORING_FEAT_REG_REG_RING` (Linux 6.3+). Returns `1`. The ring stays open, reachable only through
///       the registered index: every liburing call keeps working, and nothing (`os.close`, `close_range`) can
///       close it by mistake. Only the thread that registered the fd can use the ring then.
pub fn io_uring_close_ring_fd(ring: *Ring) py.Error!i32 {
    return py.checkErrno(c.io_uring_close_ring_fd(try ring.checkedPtr()));
}

/// Register the buffer ring `reg` (`io_uring_setup_buf_ring` does this for you).
///
/// Note
///     - Linux 5.19+. Returns `0`. `reg.ring_entries` must be a power of 2, at most 32768; `reg.ring` at least
///       `ring_entries * 16` bytes, page aligned. `reg.flags`: `IOU_PBUF_RING_INC` (Linux 6.12+) lets a buffer
///       be consumed over several completions (`IORING_CQE_F_BUF_MORE` while more are to come), `reg.min_left`
///       the least left for it to be handed out again (`1` byte if `0`).
///     - A request with `IOSQE_BUFFER_SELECT` and `buf_group = reg.bgid` takes a buffer when its data arrives;
///       its CQE has `IORING_CQE_F_BUFFER` set and the buffer id in `flags >> IORING_CQE_BUFFER_SHIFT`.
///     - The ring keeps `reg.ring` locked until `io_uring_unregister_buf_ring` or its exit.
pub fn io_uring_register_buf_ring(ring: *Ring, reg: *BufReg, flags: ?u32) py.Error!i32 {
    const _flags: u32 = if (flags) |f| f else 0;
    const r = try ring.checkedPtr();
    try ring.reserveMemory(1);
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, BufRegType.object(reg));
    defer setu.c.PyCriticalSection_End(&cs);
    var view = try reg.lockViews();
    const res = c.io_uring_register_buf_ring(r, &reg._io_uring_buf_reg, _flags);
    if (res == 0) ring.keepMemory(view, reg._io_uring_buf_reg.bgid) else releaseView(&view);
    return support.register("IORING_REGISTER_PBUF_RING", res);
}

/// Unregister the buffer ring of group `bgid`.
///
/// Note
///     - Linux 5.19+. Returns `0`; `FileNotFoundError` (`ENOENT`) when `bgid` has no buffer ring.
///     - Drops the ring's `BufRing` of `bgid` (from `io_uring_setup_buf_ring`), with the buffers added to it.
pub fn io_uring_unregister_buf_ring(ring: *Ring, bgid: i32) py.Error!i32 {
    const res = c.io_uring_unregister_buf_ring(try ring.checkedPtr(), bgid);
    if (res == 0) ring.dropBufRing(bgid);
    return support.register("IORING_UNREGISTER_PBUF_RING", res);
}

/// The kernel's current head of the buffer ring `buf_group` (how many buffers it has used).
///
/// Example
///     >>> br = io_uring_setup_buf_ring(ring, 8, 1, 0)  # group 1
///     >>> io_uring_buf_ring_head(ring, 1)
///     0
///
/// Note
///     - Linux 6.8+ (`IORING_REGISTER_PBUF_STATUS`). `FileNotFoundError` (`ENOENT`) when `buf_group` has no
///       buffers, `OSError: EINVAL` when it has legacy provided buffers (`io_uring_prep_provide_buffers`) and
///       not a ring.
pub fn io_uring_buf_ring_head(ring: *Ring, buf_group: i32) py.Error!u16 {
    var head: u16 = 0;
    _ = try support.register(
        "IORING_REGISTER_PBUF_STATUS",
        c.io_uring_buf_ring_head(try ring.checkedPtr(), buf_group, &head),
    );
    return head;
}

/// Cancel requests as described by `reg` and wait (up to `reg.timeout`) for it.
///
/// Note
///     - Linux 6.0+. Like `io_uring_prep_cancel`, but the result comes back here instead of in a CQE: `0` when
///       the request was found, or with a flag matching several (`IORING_ASYNC_CANCEL_ALL`, ...) how many.
///       The cancelled requests still post their own CQEs (their `res` raises `OSError: ECANCELED`).
///     - `OSError`: `ENOENT` (`FileNotFoundError`) when nothing matches (completed already, or a wrong `addr`),
///       `EALREADY` when the request is too far along to cancel (it completes shortly on its own), `ETIME`
///       when `reg.timeout` ran out first.
///     - `reg.addr` is the `user_data` you gave the request (the kernel's is its in-flight entry, looked up here).
pub fn io_uring_register_sync_cancel(ring: *Ring, reg: *SyncCancelReg) py.Error!i32 {
    const r = try ring.checkedPtr();
    var arg = reg._io_uring_sync_cancel_reg; // a copy: `reg.addr` keeps the user's value
    if (Ring.cancelsByUserData(arg.flags)) arg.addr = ring.findUserData(arg.addr, Ring.no_match);
    const res = callReleased(c.io_uring_register_sync_cancel, .{ r, &arg }); // waits up to `reg.timeout`
    return support.register("IORING_REGISTER_SYNC_CANCEL", res);
}

/// Send the `IORING_OP_MSG_RING` request prepared in `sqe` to another ring at once, needs no ring of its own.
///
/// Note
///     - Linux 6.13+. Returns `0` (the result comes back here, not in a CQE); the target ring, which may be any
///       the caller can reach (even its own), gets the CQE as for a submitted `io_uring_prep_msg_ring`.
///     - `sqe` must come from `io_uring_prep_msg_ring` or `io_uring_prep_msg_ring_cqe_flags`: data messages
///       only, not an fd (`io_uring_prep_msg_ring_fd`).
pub fn io_uring_register_sync_msg(sqe: *Sqe) py.Error!i32 {
    return support.register("IORING_REGISTER_SEND_MSG_RING", c.io_uring_register_sync_msg(&sqe._io_uring_sqe.?[0]));
}

/// Limit the direct descriptor slots the kernel allocates (`IORING_FILE_INDEX_ALLOC`) to `len` slots from `off`.
///
/// Note
///     - Linux 6.0+. Returns `0`. Needs a registered file table (`io_uring_register_files`,
///       `io_uring_register_files_sparse`) first; by default the kernel allocates from the whole table. The
///       slots outside the range stay for explicit indexes.
pub fn io_uring_register_file_alloc_range(ring: *Ring, off: u32, len: u32) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_FILE_ALLOC_RANGE",
        c.io_uring_register_file_alloc_range(try ring.checkedPtr(), off, len),
    );
}

/// Register the busy polling settings `napi`; the old settings are written back into it.
///
/// Note
///     - Linux 6.9+. Returns `0`; `OSError` on a kernel without `CONFIG_NET_RX_BUSY_POLL`. Busy polling the
///       network device (as the `SO_PREFER_BUSY_POLL` socket option) lowers the round trip time.
pub fn io_uring_register_napi(ring: *Ring, napi: *Napi) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_NAPI",
        c.io_uring_register_napi(try ring.checkedPtr(), &napi._io_uring_napi),
    );
}

/// Unregister busy polling; the old settings are written back into `napi`.
///
/// Note
///     - Linux 6.9+. Returns `0`.
pub fn io_uring_unregister_napi(ring: *Ring, napi: *Napi) py.Error!i32 {
    return support.register(
        "IORING_UNREGISTER_NAPI",
        c.io_uring_unregister_napi(try ring.checkedPtr(), &napi._io_uring_napi),
    );
}

/// Register a zero-copy receive queue as described by `reg`; its `zcrx_id` is set.
///
/// Note
///     - Linux 6.15+. Returns `0`. The ring must be set up with `IORING_SETUP_DEFER_TASKRUN` and
///       `IORING_SETUP_CQE32` or `IORING_SETUP_CQE_MIXED`; the caller needs `CAP_NET_ADMIN`.
///     - Not tested with a real device. Refer to `help(ZcrxIfqReg)`.
///     - The ring keeps `reg.area` and `reg.region` locked until its exit.
pub fn io_uring_register_ifq(ring: *Ring, reg: *ZcrxIfqReg) py.Error!i32 {
    const r = try ring.checkedPtr();
    try ring.reserveMemory(2);
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, ZcrxIfqRegType.object(reg));
    defer setu.c.PyCriticalSection_End(&cs);
    var views = try reg.lockViews();
    const res = c.io_uring_register_ifq(r, ifqReg(reg));
    for (&views) |*view| if (res == 0) ring.keepMemory(view.*, null) else releaseView(view);
    return support.register("IORING_REGISTER_ZCRX_IFQ", res);
}

/// Fill `query.data` with what the kernel supports.
///
/// Example
///     >>> io_uring_register_query(Query(IO_URING_QUERY_SCQ))
///     0
///
/// Note
///     - Returns `0` (the call worked); `query.result` is the kernel's answer for the query itself.
///       `UnsupportedError` on a kernel without `IORING_REGISTER_QUERY`.
///     - Needs no ring. Refer to `help(Query)`.
pub fn io_uring_register_query(query: *Query) py.Error!i32 {
    // `query_data` is an address: set it at each call.
    query._hdr.query_data = @intFromPtr(&query._data);
    query._hdr.size = @sizeOf(@TypeOf(query._data));
    query._hdr.next_entry = 0;
    return support.register("IORING_REGISTER_QUERY", c.io_uring_register_query(&query._hdr));
}

/// Control a zero-copy receive instance as described by `ctrl`.
///
/// Note
///     - Returns `0`. `ZCRX_CTRL_FLUSH_RQ` flushes the buffers pending in the refill queue; `ZCRX_CTRL_EXPORT`
///       sets `ctrl.zcrx_fd`, a file descriptor another ring can take the instance over with.
///     - Not tested with a real device. Refer to `help(ZcrxCtrl)`.
pub fn io_uring_register_zcrx_ctrl(ring: *Ring, ctrl: *ZcrxCtrl) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_ZCRX_CTRL",
        c.io_uring_register_zcrx_ctrl(try ring.checkedPtr(), &ctrl._zcrx_ctrl),
    );
}

/// Set the clock the ring uses for waiting with timeouts.
///
/// Note
///     - Linux 6.12+. Returns `0`. `arg.clockid`: `time.CLOCK_MONOTONIC` (the default) or `time.CLOCK_BOOTTIME`
///       (counts suspend too); `OSError: EINVAL` for any other.
///     - Only waits with a timeout (`io_uring_wait_cqe_timeout`, ...) use it; with `IORING_ENTER_ABS_TIMER`
///       the timeout is an absolute time of this clock.
pub fn io_uring_register_clock(ring: *Ring, arg: *ClockRegister) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_CLOCK",
        c.io_uring_register_clock(try ring.checkedPtr(), &arg._io_uring_clock_register),
    );
}

/// Add the BPF filter `bpf` to the ring.
///
/// Note
///     - Returns `0`. The filter runs for each request of `bpf.opcode` submitted through this ring: a non-zero
///       result allows it, `0` denies it (the request fails with `EACCES`). Several filters for one opcode
///       stack: all must allow. `IO_URING_BPF_FILTER_DENY_REST` in `bpf.flags` denies every opcode without a
///       filter (an allowlist).
///     - `OSError`: `EACCES` unless the caller has `CAP_SYS_ADMIN` or `no_new_privs` (`prctl`
///       `PR_SET_NO_NEW_PRIVS`, as for `seccomp`); `EMSGSIZE` when `bpf.pdu_size` is over the kernel's size for
///       the opcode, or differs from it with `IO_URING_BPF_FILTER_SZ_STRICT` (the kernel writes its size into
///       `bpf.pdu_size` then: read it and retry); `EINVAL` for a bad filter, opcode or flags.
pub fn io_uring_register_bpf_filter(ring: *Ring, bpf: *Bpf) py.Error!i32 {
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, BpfType.object(bpf));
    defer setu.c.PyCriticalSection_End(&cs);
    return support.register(
        "IORING_REGISTER_BPF_FILTER",
        c.io_uring_register_bpf_filter(try ring.checkedPtr(), &bpf._io_uring_bpf),
    );
}

/// Add the BPF filter `bpf` to the calling task (and its children) instead of a ring.
///
/// Note
///     - Returns `0`; the filter, errors and privileges of `io_uring_register_bpf_filter`.
///     - Applies to every ring the task creates afterwards (not to existing ones) and is inherited by
///       `fork` children, who may add filters but not loosen these; it can not be removed.
pub fn io_uring_register_bpf_filter_task(bpf: *Bpf) py.Error!i32 {
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, BpfType.object(bpf));
    defer setu.c.PyCriticalSection_End(&cs);
    return support.register("IORING_REGISTER_BPF_FILTER", c.io_uring_register_bpf_filter_task(&bpf._io_uring_bpf));
}

/// `reg` with `region_uptr` pointing at its description (which lives in the same object).
fn regionReg(reg: *MemRegionReg) *c.io_uring_mem_region_reg {
    reg._io_uring_mem_region_reg.region_uptr = @intFromPtr(&reg._desc);
    return &reg._io_uring_mem_region_reg;
}

/// `reg` with `area_ptr` and `region_ptr` pointing at their descriptions (in the same object).
fn ifqReg(reg: *ZcrxIfqReg) *c.io_uring_zcrx_ifq_reg {
    reg._io_uring_zcrx_ifq_reg.area_ptr = @intFromPtr(&reg._area);
    reg._io_uring_zcrx_ifq_reg.region_ptr = @intFromPtr(&reg._region);
    return &reg._io_uring_zcrx_ifq_reg;
}

/// Register the memory region `reg` with the ring.
///
/// Note
///     - Linux 6.13+. Returns `0`. With `IORING_MEM_REGION_REG_WAIT_ARG` in `reg.flags` (wait arguments for
///       `io_uring_submit_and_wait_reg`, see `RegWait`) the ring must still be disabled
///       (`IORING_SETUP_R_DISABLED`, before `io_uring_enable_rings`).
///     - `reg.region = None`: the kernel allocates the region and sets `reg.region_mmap_offset`, the offset
///       to `mmap` it from the ring's fd at.
///     - The ring keeps `reg.region` locked until its exit.
pub fn io_uring_register_region(ring: *Ring, reg: *MemRegionReg) py.Error!i32 {
    const r = try ring.checkedPtr();
    try ring.reserveMemory(1);
    var cs: setu.c.CriticalSection = undefined; // free-threaded: a set from another thread waits
    setu.c.PyCriticalSection_Begin(&cs, MemRegionRegType.object(reg));
    defer setu.c.PyCriticalSection_End(&cs);
    var view = try reg.lockViews();
    const res = c.io_uring_register_region(r, regionReg(reg));
    if (res == 0) ring.keepMemory(view, null) else releaseView(&view);
    return support.register("IORING_REGISTER_MEM_REGION", res);
}

/// Releases a view `lock` took for a register the kernel refused.
fn releaseView(view: *?setu.c.Buffer) void {
    if (view.*) |*v| setu.c.PyBuffer_Release(v);
    view.* = null;
}

/// Set up and register a buffer ring of `nentries` for group `bgid`, and give its `BufRing`.
///
/// Type
///     return: BufRing
///
/// Flags
///     IOU_PBUF_RING_INC     # Linux 6.12+: a buffer may be consumed over several completions.
///
/// Note
///     - Linux 5.19+. `nentries` must be a power of 2, at most 32768. The `BufRing` is initialized
///       (`io_uring_buf_ring_init`) and registered (`io_uring_register_buf_ring`): add buffers with
///       `io_uring_buf_ring_add` and `io_uring_buf_ring_advance`.
///     - A request with `IOSQE_BUFFER_SELECT` and `buf_group = bgid` takes a buffer when its data arrives (its
///       `res` raises `OSError: ENOBUFS` when none is left); its CQE has `IORING_CQE_F_BUFFER` set and the id in
///       `flags >> IORING_CQE_BUFFER_SHIFT`. With `IOU_PBUF_RING_INC`, `IORING_CQE_F_BUF_MORE` says the buffer
///       is not used up yet.
///     - `OSError` if the kernel refuses (C liburing's `err` out-parameter is the error number).
///     - The ring holds the `BufRing` (and the buffers added to it) until `io_uring_free_buf_ring`,
///       `io_uring_unregister_buf_ring` or its exit.
pub fn io_uring_setup_buf_ring(ring: *Ring, nentries: u32, bgid: i32, flags: u32) py.Error!*Object {
    var err: c_int = 0;
    const r = try ring.checkedPtr();
    if (c.io_uring_setup_buf_ring(r, nentries, bgid, flags, &err)) |br| {
        const obj = BufRingType.new(.{ ._io_uring_buf_ring = br, ._bgid = bgid }) catch |fail| {
            // coverage-off: out of memory only
            _ = c.io_uring_free_buf_ring(r, br, nentries, bgid);
            return fail;
            // coverage-on
        };
        // coverage-off: out of memory only
        errdefer py.decref(obj);
        // coverage-on
        try ring.keepBufRing(obj);
        return obj;
    }
    _ = try py.checkErrno(if (err < 0) err else -err);
    // coverage-off: liburing sets `err` whenever it fails
    return py.raiseRuntimeError("`io_uring_setup_buf_ring` - could not be initialized!", .{});
    // coverage-on
}

/// Unregister and free the buffer ring `br` (`nentries` and `bgid` as for `io_uring_setup_buf_ring`).
///
/// Note
///     - Returns `0`; `FileNotFoundError` (`ENOENT`) when `bgid` is not registered any more. The ring's exit
///       does it too.
pub fn io_uring_free_buf_ring(ring: *Ring, br: *BufRing, nentries: u32, bgid: i32) py.Error!i32 {
    const res = c.io_uring_free_buf_ring(try ring.checkedPtr(), br._io_uring_buf_ring.?, nentries, bgid);
    if (res == 0) ring.dropBufRing(bgid);
    return py.checkErrno(res);
}

/// Limits the cpus the ring's async workers (`io-wq`) may run on to those set in `mask` (`bytes` / `bytearray`
/// in the `cpu_set_t` layout, bit `n` of byte `n // 8` for cpu `n`).
///
/// Example
///     >>> io_uring_register_iowq_aff(ring, bytes([0b11]))  # cpus 0 and 1
///     0
///
/// Note
///     - Linux 5.14+. Returns `0`; `OSError: EINVAL` for an empty `mask`. By default the workers inherit the
///       cpu mask of the task that made the ring. A worker already running moves at its next schedule point.
pub fn io_uring_register_iowq_aff(ring: *Ring, mask: py.Buffer) py.Error!i32 {
    return support.register(
        "IORING_REGISTER_IOWQ_AFF",
        c.io_uring_register_iowq_aff(try ring.checkedPtr(), mask.data.len, @ptrCast(@alignCast(mask.data.ptr))),
    );
}

/// Remove the cpu limit set by `io_uring_register_iowq_aff`.
///
/// Note
///     - Linux 5.14+. Returns `0`.
pub fn io_uring_unregister_iowq_aff(ring: *Ring) py.Error!i32 {
    return support.register("IORING_UNREGISTER_IOWQ_AFF", c.io_uring_unregister_iowq_aff(try ring.checkedPtr()));
}

/// Sets the most `io-wq` workers the ring may run: `bounded` (regular files) and `unbounded` (sockets, ...);
/// `0` leaves one as is. Gives the previous `(bounded, unbounded)`.
///
/// Example
///     >>> io_uring_register_iowq_max_workers(ring, 0, 0)  # (bounded, unbounded)
///     (96, 1048576)
///
/// Note
///     - Linux 5.15+. Defaults: `bounded` the ring's SQ entries or 4 times the online cpus, whichever is less;
///       `unbounded` the task limit (`RLIMIT_NPROC`). The limits are per NUMA node, and maxima: idle workers
///       are reaped. `OSError: EINVAL` for a value over the kernel's maximum.
pub fn io_uring_register_iowq_max_workers(ring: *Ring, bounded: u32, unbounded: u32) py.Error!struct { u32, u32 } {
    var values = [2]c_uint{ bounded, unbounded };
    _ = try support.register(
        "IORING_REGISTER_IOWQ_MAX_WORKERS",
        c.io_uring_register_iowq_max_workers(try ring.checkedPtr(), &values),
    );
    return .{ values[0], values[1] };
}

/// The mask for a buffer ring of `ring_entries` (for `io_uring_buf_ring_add`).
pub fn io_uring_buf_ring_mask(ring_entries: u32) i32 {
    return c.io_uring_buf_ring_mask(ring_entries);
}

/// Initialize the buffer ring `br` (zero its tail) before the first `io_uring_buf_ring_add`.
///
/// Note
///     - `io_uring_setup_buf_ring` has done this already for the `BufRing` it gives.
pub fn io_uring_buf_ring_init(br: *BufRing) void {
    c.io_uring_buf_ring_init(br._io_uring_buf_ring.?);
}

/// Add the buffer `addr` with id `bid` to `br`, `buf_offset` (default `0`) entries after the tail; not visible to
/// the kernel until `io_uring_buf_ring_advance`.
///
/// Note
///     - `mask` is `io_uring_buf_ring_mask(nentries)`. `buf_offset` is `0` for one buffer; adding several
///       before one `io_uring_buf_ring_advance`, it goes up by `1` for each (`0`, `1`, `2`, ...).
///     - `bid` comes back in the CQE (`flags >> IORING_CQE_BUFFER_SHIFT`), and may name a different buffer each
///       time it is added: only you track which. A request writes at most `INT_MAX` bytes into a buffer.
///     - `addr` must be writable (the kernel fills it); `br` holds it (locked: no resize) until `bid` is added
///       again or the buffer ring is freed (the ring holds `br` until then).
pub fn io_uring_buf_ring_add(
    br: *BufRing,
    addr: py.OwnedWritableBuffer,
    bid: u16,
    mask: i32,
    buf_offset: ?i32,
) py.Error!void {
    const len = py.narrow(c_uint, addr.data.len, "`io_uring_buf_ring_add(addr)` length") catch |err| {
        return releaseFailed(addr, err);
    };
    try br.keepView(bid, addr.view); // owns the view from here (released if it fails)
    c.io_uring_buf_ring_add(br._io_uring_buf_ring.?, addr.data.ptr, len, bid, mask, buf_offset orelse 0);
}

/// Make `count` added buffers visible to the kernel.
///
/// Note
///     - This hands the buffers over to the ring: do not write into them until a CQE gives them back.
pub fn io_uring_buf_ring_advance(br: *BufRing, count: i32) void {
    c.io_uring_buf_ring_advance(br._io_uring_buf_ring.?, count);
}

/// Like `io_uring_buf_ring_advance`, and advance the completion queue by `count` too.
///
/// Note
///     - For handling a batch of CQEs that each give a buffer back: one memory barrier instead of the two of
///       `io_uring_buf_ring_advance` + `io_uring_cq_advance`.
pub fn io_uring_buf_ring_cq_advance(ring: *Ring, br: *BufRing, count: i32) py.Error!void {
    c.io_uring_buf_ring_cq_advance(try ring.checkedPtr(), br._io_uring_buf_ring.?, count);
}

/// The number of buffers in `br` the kernel has not used yet.
///
/// Note
///     - Linux 6.8+ (asks the kernel for its head, `io_uring_buf_ring_head`). The count is of that moment: with
///       requests in flight that may take buffers, it is already stale.
///     - Returns a negative error number, not an exception: `-ENOENT` when `bgid` has no buffers, `-EINVAL`
///       when it is not a buffer ring or the kernel lacks the call.
pub fn io_uring_buf_ring_available(ring: *Ring, br: *BufRing, bgid: u16) py.Error!i32 {
    return c.io_uring_buf_ring_available(try ring.checkedPtr(), br._io_uring_buf_ring.?, bgid);
}
