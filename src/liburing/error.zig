const setu = @import("setu");

const py = setu.py;

/// Trap Error: `errno` as is when it is `>= 0`, else raises the `OSError` for `-errno`.
///
/// Type
///     errno  int
///     return int
///
/// Example
///     >>> trap_error(1)
///     1
///
///     >>> trap_error(-11)
///     BlockingIOError: [Errno 11] Resource temporarily unavailable
///
///     >>> trap_error(-1)
///     PermissionError: [Errno 1] Operation not permitted
///
/// Note
///     - any `errno >= 0` is considered safe and is returned.
///     - the C `errno` variable is not looked at: `-1` raises `PermissionError` (`EPERM`), as `-N` raises errno `N`.
pub fn trap_error(errno: i32) py.Error!i32 {
    return py.checkErrno(errno);
}

/// `MemoryError` (Setu's `capi.zig` does not declare it).
extern var PyExc_MemoryError: *setu.c.Object;

/// Raises `MemoryError` with a message.
pub fn raiseMemoryError(comptime msg: []const u8) py.Error {
    return py.raise(PyExc_MemoryError, msg, .{});
}
