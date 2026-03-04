const c = oz.py.c;
const oz = @import("PyOZ");
const std = @import("std");

pub const Functions = .{
    oz.func("trap_error", trapError, ""),
};

// Error
pub inline fn trapError(errno: i32) ?i32 {
    if (errno < 0) {
        std.c._errno().* = -errno;
        _ = c.PyErr_SetFromErrno(@ptrCast(c.PyExc_OSError));
        return null;
    }
    return errno;
}
