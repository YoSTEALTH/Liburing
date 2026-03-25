const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

pub const FUTEX = extern struct {
    _state: usize,
    _vector: ?*c.futex_waitv = null,

    const Self = @This();

    // GET

    pub fn get_state(self: *const Self) u32 {
        return @as(*u32, @ptrFromInt(self._state)).*;
    }

    pub fn get_val(self: *const Self) ?u64 {
        if (self._vector) |v| return v.val;
        return oz.raiseMemoryError("Futex(vector) Memory not set!");
    }

    pub fn get_flags(self: *const Self) ?u32 {
        if (self._vector) |v| return v.flags;
        return oz.raiseMemoryError("Futex(vector) Memory not set!");
    }

    // SET

    pub fn set_state(self: *Self, value: u32) void {
        @as(*u32, @ptrFromInt(self._state)).* = value;
    }

    pub fn set_val(self: *Self, value: u64) ?void {
        if (self._vector) |v| {
            v.val = value;
        } else return oz.raiseMemoryError("Futex(vector) Memory not set!");
    }

    ///Note
    ///    - Overwrite `.flags` value.
    pub fn set_flags(self: *Self, value: u32) ?void {
        if (self._vector) |v| {
            v.val = value;
        } else return oz.raiseMemoryError("Futex(vector) Memory not set!");
    }
};

///Futex State - User Address Memory
///
///Type
///    no:     int
///    flags:  int
///    vector: bool
///    return: None
///
///Example
///    >>> futex = Futex()
///    >>> futex.state
///    0
///    >>> futex.private
///    False
///
///    >>> io_uring_prep_futex_wait(sqe, futex)
///    >>> futex.state = 1
///    >>> io_uring_prep_futex_wake(sqe, futex)
///
///    >>> futex.state = 0
///    >>> fwv = Futex()
///    >>> io_uring_prep_futex_waitv(sqe, fwv)
///
///    >>> futex = Futex(2, FUTEX2_PRIVATE | FUTEX2_SIZE_U32)
///    >>> futex.private
///    True
///
///Flags
///    FUTEX2_SIZE_U32 (default)
///    FUTEX2_PRIVATE
///
///Note
///    - By default `SHARED` memory is created, set `Futex(123, FUTEX2_PRIVATE)` to use `PRIVATE` memory.
///    - For now only `FUTEX2_SIZE_U32` is supported by Linux https://github.com/axboe/liburing/issues/1556
///    - Coded and basic test, missing real world testing
pub const Futex = extern struct {
    _parent: FUTEX,
    _len: u8,
    _futex: usize,
    _private: bool,
    _futex_waitv: ?[*]c.futex_waitv = null,

    const Self = @This();

    pub const __base__ = oz.base(FUTEX);

    pub fn __new__(no: ?u8, flags: ?u32, vector: ?bool) ?Self {
        const _no: u8 = no orelse 1;
        const _flags: u32 = flags orelse FUTEX2_SIZE_U32;
        const _vector: bool = vector orelse false;
        var waitv: []c.futex_waitv = undefined;

        if (_no == 0) return oz.raiseValueError("`Futex(no)` can not be `0`");
        if (FUTEX2_PRIVATE == 0) return oz.raiseRuntimeError(
            "`futex2` not found, please upgrade to Linux `6.7`+, uninstall & install Liburing.",
        );

        if (_no > FUTEX_WAITV_MAX) return oz.raiseValueError(oz.fmt(
            "`Futex(no)` is limited to {}, received {}, when used with `futex_waitv`",
            .{ FUTEX_WAITV_MAX, _no },
        ));

        const private: bool = switch (_flags & FUTEX2_PRIVATE) {
            FUTEX2_PRIVATE => true,
            else => false,
        };

        const size = @sizeOf(u32) * @as(u32, _no);

        const futex: usize = std.os.linux.mmap(
            null,
            size,
            std.os.linux.PROT.READ | std.os.linux.PROT.WRITE,
            .{ .TYPE = if (private) .PRIVATE else .SHARED, .ANONYMOUS = true },
            -1,
            0,
        );
        errdefer std.os.linux.munmap(@ptrCast(futex), size);

        if (_vector) {
            waitv = std.heap.c_allocator.alloc(c.futex_waitv, _no) catch return oz.raiseMemoryError("Out of memory!");
            for (0.._no, waitv) |i, *v| {
                v.val = 0;
                v.uaddr = @intFromPtr(&@as([*]u32, @ptrFromInt(futex))[i]);
                v.flags = _flags;
                v.__reserved = 0; // note: this is needed, silent bug!!!
            }
        }
        return .{
            ._parent = .{
                ._state = @intFromPtr(&@as([*]u32, @ptrFromInt(futex))[0]),
                ._vector = if (_vector) &waitv[0] else null,
            },
            ._len = _no,
            ._futex = futex,
            ._futex_waitv = if (_vector) waitv.ptr else null,
            ._private = private,
        };
    }

    pub fn __del__(self: *const Self) void {
        _ = std.os.linux.munmap(@ptrFromInt(self._futex), @sizeOf(u32) * @as(u32, self._len));
        if (self._futex_waitv) |v| std.heap.c_allocator.free(v[0..self._len]);
    }

    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    pub fn __getitem__(self: *const Self, index: usize) ?FUTEX {
        if (index < self._len) {
            return .{
                ._state = @intFromPtr(&@as([*]u32, @ptrFromInt(self._futex))[index]),
                ._vector = if (self._futex_waitv) |v| &v[index] else null,
            };
        }
        return oz.raiseIndexError("Index out of range");
    }

    pub fn get_private(self: *const Self) bool {
        return self._private;
    }
};

pub const FUTEX_WAIT = c.FUTEX_WAIT;
pub const FUTEX_WAKE = c.FUTEX_WAKE;
pub const FUTEX_FD = c.FUTEX_FD;
pub const FUTEX_REQUEUE = c.FUTEX_REQUEUE;
pub const FUTEX_CMP_REQUEUE = c.FUTEX_CMP_REQUEUE;
pub const FUTEX_WAKE_OP = c.FUTEX_WAKE_OP;
pub const FUTEX_LOCK_PI = c.FUTEX_LOCK_PI;
pub const FUTEX_UNLOCK_PI = c.FUTEX_UNLOCK_PI;
pub const FUTEX_TRYLOCK_PI = c.FUTEX_TRYLOCK_PI;
pub const FUTEX_WAIT_BITSET = c.FUTEX_WAIT_BITSET;
pub const FUTEX_WAKE_BITSET = c.FUTEX_WAKE_BITSET;
pub const FUTEX_WAIT_REQUEUE_PI = c.FUTEX_WAIT_REQUEUE_PI;
pub const FUTEX_CMP_REQUEUE_PI = c.FUTEX_CMP_REQUEUE_PI;
pub const FUTEX_LOCK_PI2 = c.FUTEX_LOCK_PI2;

pub const FUTEX_PRIVATE_FLAG = c.FUTEX_PRIVATE_FLAG;
pub const FUTEX_CLOCK_REALTIME = c.FUTEX_CLOCK_REALTIME;
pub const FUTEX_CMD_MASK = c.FUTEX_CMD_MASK;

pub const FUTEX_WAIT_PRIVATE = c.FUTEX_WAIT_PRIVATE;
pub const FUTEX_WAKE_PRIVATE = c.FUTEX_WAKE_PRIVATE;
pub const FUTEX_REQUEUE_PRIVATE = c.FUTEX_REQUEUE_PRIVATE;
pub const FUTEX_CMP_REQUEUE_PRIVATE = c.FUTEX_CMP_REQUEUE_PRIVATE;
pub const FUTEX_WAKE_OP_PRIVATE = c.FUTEX_WAKE_OP_PRIVATE;
pub const FUTEX_LOCK_PI_PRIVATE = c.FUTEX_LOCK_PI_PRIVATE;
pub const FUTEX_LOCK_PI2_PRIVATE = c.FUTEX_LOCK_PI2_PRIVATE;
pub const FUTEX_UNLOCK_PI_PRIVATE = c.FUTEX_UNLOCK_PI_PRIVATE;
pub const FUTEX_TRYLOCK_PI_PRIVATE = c.FUTEX_TRYLOCK_PI_PRIVATE;
pub const FUTEX_WAIT_BITSET_PRIVATE = c.FUTEX_WAIT_BITSET_PRIVATE;
pub const FUTEX_WAKE_BITSET_PRIVATE = c.FUTEX_WAKE_BITSET_PRIVATE;
pub const FUTEX_WAIT_REQUEUE_PI_PRIVATE = c.FUTEX_WAIT_REQUEUE_PI_PRIVATE;
pub const FUTEX_CMP_REQUEUE_PI_PRIVATE = c.FUTEX_CMP_REQUEUE_PI_PRIVATE;

pub const FUTEX2_PRIVATE = if (@hasDecl(c, "FUTEX2_PRIVATE")) c.FUTEX2_PRIVATE else 0;

pub const FUTEX2_SIZE_U32 = if (@hasDecl(c, "FUTEX2_SIZE_U32")) c.FUTEX2_SIZE_U32 else 0;
// note: not supported by linux: FUTEX2_SIZE_U8, FUTEX2_SIZE_U16, FUTEX2_SIZE_U64
pub const FUTEX2_NUMA = if (@hasDecl(c, "FUTEX2_NUMA")) c.FUTEX2_NUMA else 0;
pub const FUTEX2_MPOL = if (@hasDecl(c, "FUTEX2_MPOL")) c.FUTEX2_MPOL else 0;

pub const FUTEX_WAITV_MAX = c.FUTEX_WAITV_MAX;
pub const FUTEX_BITSET_MATCH_ANY = c.FUTEX_BITSET_MATCH_ANY;
