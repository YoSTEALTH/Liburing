const setu = @import("setu");

const py = setu.py;

///Trap Error
///
///Type
///    errno  int
///    return int
///
///Example
///    >>> trap_error(1)
///    1
///
///    >>> trap_error(-11)
///    BlockingIOError: [Errno 11] Resource temporarily unavailable
///
///    >>> trap_error(-1)
///    # dynamic error based on `errno`
///
///Note
///    - any `no >= 0` is considered safe.
///    - if `no=-1` it will check with `errno` first to see if proper error is set,
///      and raise that as exception
pub fn trap_error(errno: i32) py.Error!i32 {
    return py.checkErrno(errno);
}

/// `MemoryError` (Setu's `capi.zig` does not declare it).
extern var PyExc_MemoryError: *setu.c.Object;

/// Raises `MemoryError` with a message.
pub fn raiseMemoryError(comptime msg: []const u8) py.Error {
    return py.raise(PyExc_MemoryError, msg, .{});
}
