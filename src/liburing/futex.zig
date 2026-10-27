const c = @import("c");
const e = @import("error.zig");
const keep = @import("class.zig").keep;
const setu = @import("setu");
const std = @import("std");

const py = setu.py;
const Object = setu.c.Object;
const linux = std.os.linux;

pub const FUTEXType = setu.Class(FUTEX, @embedFile("futex.zig"));
pub const FutexType = setu.Class(Futex, @embedFile("futex.zig"));

/// One futex of a `Futex`: `futex[i]`, or the `Futex` itself (its first one).
///
/// Example
///     >>> futex = Futex(2)
///     >>> futex[1].state = 5
///     >>> futex[1].state
///     5
///
/// Note
///     - `val` and `flags` are the `futex_waitv` entry's, only for a `Futex` made with `vector=True`
///       (`MemoryError` otherwise).
pub const FUTEX = struct {
    _state: usize = 0, // address of this entry's `u32` in the `Futex` memory
    _vector: ?*c.futex_waitv = null,
    _owner: ?*Object = null, // the `Futex` whose memory this points into, for an item (`futex[1]`)

    pub const instantiable = false;
    pub const basetype = true; // `Sqe` / `Futex` subclass it

    const Self = @This();

    // GET

    /// The futex's value (a `u32`).
    pub fn get_state(self: *const Self) u32 {
        // `.seq_cst`: a cross-thread protocol keeps its order on aarch64 too (a store after a `deque` append is
        // seen after it; a load before a `deque` check stays before it)
        return @atomicLoad(u32, @as(*u32, @ptrFromInt(self._state)), .seq_cst);
    }

    /// The value the `futex_waitv` entry expects: the wait sleeps only while the futex still holds it (a
    /// different value when the request starts completes it with `OSError: EAGAIN` at once).
    pub fn get_val(self: *const Self) py.Error!u64 {
        if (self._vector) |v| return v.val;
        return e.raiseMemoryError("Futex(vector) Memory not set!");
    }

    /// The `futex_waitv` entry's `FUTEX2_*` flags (`FUTEX2_SIZE_U32`, `| FUTEX2_PRIVATE` for a futex shared by
    /// threads of one process only).
    pub fn get_flags(self: *const Self) py.Error!u32 {
        if (self._vector) |v| return v.flags;
        return e.raiseMemoryError("Futex(vector) Memory not set!");
    }

    // SET

    /// Set the futex's value (a `u32`).
    pub fn set_state(self: *Self, value: u32) void {
        @atomicStore(u32, @as(*u32, @ptrFromInt(self._state)), value, .seq_cst); // see `get_state`
    }

    /// Set the value the `futex_waitv` entry waits for.
    pub fn set_val(self: *Self, value: u64) py.Error!void {
        if (self._vector) |v| {
            v.val = value;
        } else return e.raiseMemoryError("Futex(vector) Memory not set!");
    }

    /// Set the `futex_waitv` entry's `FUTEX2_*` flags.
    ///
    /// Note
    ///     - Overwrite `.flags` value.
    pub fn set_flags(self: *Self, value: u32) py.Error!void {
        if (self._vector) |v| {
            v.flags = value;
        } else return e.raiseMemoryError("Futex(vector) Memory not set!");
    }
};

/// Futex State - User Address Memory
///
/// Type
///     no:     int
///     flags:  int
///     vector: bool
///     return: None
///
/// Example
///     >>> futex = Futex()
///     >>> futex.state
///     0
///     >>> futex.private
///     False
///
///     >>> io_uring_prep_futex_wait(sqe, futex, 0, FUTEX_BITSET_MATCH_ANY, FUTEX2_SIZE_U32)
///     True
///     >>> futex.state = 1
///     >>> io_uring_prep_futex_wake(sqe, futex, 1, FUTEX_BITSET_MATCH_ANY, FUTEX2_SIZE_U32)
///     True
///
///     >>> fwv = Futex(1, None, True)  # `vector=True` for `io_uring_prep_futex_waitv`
///     >>> io_uring_prep_futex_waitv(sqe, fwv)
///     True
///
///     >>> futex = Futex(2, FUTEX2_PRIVATE | FUTEX2_SIZE_U32)
///     >>> futex.private
///     True
///
/// Flags
///     FUTEX2_SIZE_U32 (default)
///     FUTEX2_PRIVATE
///
/// Note
///     - Defaults: `no=1`, `flags=FUTEX2_SIZE_U32`, `vector=False`.
///     - By default `SHARED` memory is created, set `Futex(123, FUTEX2_PRIVATE)` to use `PRIVATE` memory.
///     - For now only `FUTEX2_SIZE_U32` is supported by Linux https://github.com/axboe/liburing/issues/1556
///     - `no` is `1` to `FUTEX_WAITV_MAX` (`ValueError` otherwise); `RuntimeError` when built without `futex2`
///       (Linux headers before `6.7`).
///     - `len(futex)` is `no`, `futex[i]` the `i`-th futex.
///     - The requests need Linux 6.7+ (`IORING_OP_FUTEX_WAIT`, `IORING_OP_FUTEX_WAKE`, `IORING_OP_FUTEX_WAITV`).
///       `io_uring_prep_futex_wait` sleeps while `state == val` and matches wakers by `mask`
///       (`FUTEX_BITSET_MATCH_ANY`: any); `io_uring_prep_futex_wake` wakes up to `val` waiters, `cqe.res` is how
///       many; `io_uring_prep_futex_waitv` waits on every entry of a `Futex(no, vector=True)` (each entry's `val`
///       / `flags`), `cqe.res` is the index of the one woken. The wait and waitv requests take no timeout: link
///       an `io_uring_prep_link_timeout` after them (the wait then completes with `OSError: ECANCELED`).
///     - Wait, wake and waitv are tested, missing real world testing
pub const Futex = struct {
    _len: u8 = 0,
    _futex: usize = 0, // `mmap` address of `_len` `u32`s
    _private: bool = false,
    _futex_waitv: ?[*]c.futex_waitv = null,

    pub const base = FUTEXType;

    const Self = @This();

    pub fn __new__(self: *Object, no: ?u8, flags: ?u32, vector: ?bool) py.Error!void {
        const _no: u8 = no orelse 1;
        const _flags: u32 = flags orelse FUTEX2_SIZE_U32;
        const _vector: bool = vector orelse false;

        if (_no == 0) return py.raiseValueError("`Futex(no)` can not be `0`", .{});
        if (FUTEX2_PRIVATE == 0) return py.raiseRuntimeError(
            "`futex2` not found, please upgrade to Linux `6.7`+, uninstall & install Liburing.",
            .{},
        );

        if (_no > FUTEX_WAITV_MAX) return py.raiseValueError(
            "`Futex(no)` is limited to {}, received {}, when used with `futex_waitv`",
            .{ FUTEX_WAITV_MAX, _no },
        );

        const private: bool = (_flags & FUTEX2_PRIVATE) == FUTEX2_PRIVATE;
        const size = @sizeOf(u32) * @as(u32, _no);

        const futex: usize = linux.mmap(
            null,
            size,
            .{ .READ = true, .WRITE = true },
            .{ .TYPE = if (private) .PRIVATE else .SHARED, .ANONYMOUS = true },
            -1,
            0,
        );
        if (linux.errno(futex) != .SUCCESS) return py.raiseErrno(@backingInt(linux.errno(futex)));
        const states: [*]u32 = @ptrFromInt(futex);
        errdefer _ = linux.munmap(@ptrCast(states), size);

        var waitv: ?[*]c.futex_waitv = null;
        if (_vector) {
            const list = std.heap.c_allocator.alloc(c.futex_waitv, _no) catch return e.raiseMemoryError(
                "Out of memory!",
            );
            for (list, 0..) |*v, i| {
                v.val = 0;
                v.uaddr = @intFromPtr(&states[i]);
                v.flags = _flags;
                v.__reserved = 0; // note: this is needed, silent bug!!!
            }
            waitv = list.ptr;
        }
        FUTEXType.data(self).* = .{ ._state = @intFromPtr(&states[0]), ._vector = if (waitv) |v| &v[0] else null };
        FutexType.data(self).* = .{ ._len = _no, ._futex = futex, ._futex_waitv = waitv, ._private = private };
    }

    pub fn __del__(self: *const Self) void {
        if (self._futex != 0) _ = linux.munmap(@ptrFromInt(self._futex), @sizeOf(u32) * @as(u32, self._len));
        if (self._futex_waitv) |v| std.heap.c_allocator.free(v[0..self._len]);
    }

    /// How many futexes (`no`) it holds.
    pub fn __len__(self: *const Self) usize {
        return self._len;
    }

    /// `True` if it holds any futex.
    pub fn __bool__(self: *const Self) bool {
        return (self._len > 0);
    }

    /// The `index`-th futex, as a `FUTEX` (`IndexError` out of range).
    ///
    /// Type
    ///     return: FUTEX
    pub fn __getitem__(self: *Object, index: isize) py.Error!*Object {
        const d = FutexType.data(self);
        if (index >= 0 and index < d._len) {
            const i: usize = @intCast(index); // cast: checked above
            return FUTEXType.new(.{
                ._state = @intFromPtr(&@as([*]u32, @ptrFromInt(d._futex))[i]),
                ._vector = if (d._futex_waitv) |v| &v[i] else null,
                ._owner = keep(self),
            });
        }
        return py.raiseIndexError("Index out of range", .{});
    }

    /// Whether it was made with `FUTEX2_PRIVATE` (read only).
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
