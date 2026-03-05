const c = oz.py.c;
const oz = @import("PyOZ");
const std = @import("std");

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
pub inline fn trap_error(errno: i32) ?i32 {
    if (errno < 0) {
        std.c._errno().* = -errno;
        _ = c.PyErr_SetFromErrno(@ptrCast(c.PyExc_OSError));
        return null;
    }
    return errno;
}
