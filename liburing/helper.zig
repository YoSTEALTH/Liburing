//! Liburing - Helper functions
const c = @import("c.zig").c;
const n = @import("enum.zig");
const oz = @import("PyOZ");
const std = @import("std");

const Timespec = @import("class.zig").Timespec;

pub const Functions = .{
    oz.func("probe", probe, probeDoc),
    oz.func("timespec", timespec, timespecDoc),
};

const probeDoc =
    \\Probe your system to find out which `io_uring` operations are available.
    \\
    \\Example
    \\    >>> probe()
    \\    {'IORING_OP_NOP': True, ...}
    \\
    \\    # or
    \\
    \\    >>> for op, supported in probe().items():
    \\    ...     op, supported
    \\    IORING_OP_NOP True
    \\
; // probe()
fn probe() ?oz.Dict([]const u8, bool) {
    const last: usize = @intFromEnum(n.io_uring_op.IORING_OP_LAST);
    const items = std.meta.fields(n.io_uring_op);
    var entries: [last]oz.Dict([]const u8, bool).Entry = undefined;

    if (c.io_uring_get_probe()) |p| {
        defer c.io_uring_free_probe(p);

        inline for (0..last) |i| {
            entries[i] = .{ .key = items[i].name, .value = (c.io_uring_opcode_supported(p, items[i].value) == 1) };
        }
        return .{ .entries = &entries };
    }
    return oz.raiseRuntimeError("Linux kernel version does not support `probe()`");
}

const timespecDoc =
    \\Kernel Timespec
    \\
    \\Example
    \\    >>> ts = timespec(1)        # int
    \\    >>> ts = timespec(1.5)      # float
    \\    >>> io_uring_prep_timeout(sqe, ts, ...)
;
pub fn timespec(second: f64) ?Timespec {
    var ts = std.heap.c_allocator.create(c.__kernel_timespec) catch {
        return oz.raiseMemoryError("`timespec()` - Out of Memory!");
    };
    // split float to second & nano second
    if (second != 0.0) {
        ts.tv_sec = @intFromFloat(second);
        const x: f64 = @floatFromInt(ts.tv_sec);
        ts.tv_nsec = @intFromFloat((second - x) * 1_000_000_000);
    } else {
        ts.* = std.mem.zeroes(c.__kernel_timespec); // set default value to `0`
    }
    return .{ ._timespec = ts };
}

// TODO:
//
// # custom prep function start >>>
// cpdef inline void io_uring_prep_setsockopt(io_uring_sqe sqe,
//                                            int sockfd,
//                                            int level,
//                                            int optname,
//                                            array optval):
//     '''
//         Example
//             >>> val = array.array('i', [0])
//             >>> sqe = io_uring_get_sqe(ring)
//             >>> io_uring_prep_setsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, val)

//             >>> val = array.array('i', [1])
//             >>> sqe = io_uring_get_sqe(ring)
//             >>> io_uring_prep_setsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, val)

//             >>> val = array.array('B', b'eth1')
//             >>> sqe = io_uring_get_sqe(ring)
//             >>> io_uring_prep_setsockopt(sqe, sockfd, SOL_SOCKET, SO_BINDTODEVICE, val)

//         Note
//             - remember to hold on to `val` reference till `sqe` has been submitted.
//             - only 'i' and 'B' format is supported.
//     '''
//     if optval.typecode not in ('i', 'B'):
//         raise ValueError('`io_uring_prep_setsockopt()` - only supports type code of "i" & "B"')
//     cdef int size = sizeof(int) if optval.typecode == 'i' else len(optval)
//     __io_uring_prep_cmd_sock(sqe.ptr, __SOCKET_URING_OP_SETSOCKOPT,
//                              sockfd, level, optname, optval.data.as_voidptr, size)

// cpdef inline void io_uring_prep_getsockopt(io_uring_sqe sqe,
//                                            int sockfd,
//                                            int level,
//                                            int optname,
//                                            array optval):
//     '''
//         Example
//             # assuming `SO_KEEPALIVE` was previous set to `1`
//             >>> val = array.array('i', [0])
//             >>> sqe = io_uring_get_sqe(ring)
//             >>> io_uring_prep_getsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, val)
//             ... # after submit and wait
//             >>> val
//             array('i', [1])
//             >>> val[0]
//             1

//         Note
//             - remember to hold on to `val` as new result will be populated into it.
//             - `cqe.res` will return `sizeof` populating data.
//             - only 'i' and 'B' format is supported.
//     '''
//     if optval.typecode not in ('i', 'B'):
//         raise ValueError('`io_uring_prep_getsockopt()` - only supports type code of "i" & "B"')
//     cdef int size = sizeof(int) if optval.typecode == 'i' else len(optval)
//     __io_uring_prep_cmd_sock(sqe.ptr, __SOCKET_URING_OP_GETSOCKOPT,
//                              sockfd, level, optname, optval.data.as_voidptr, size)
// # custom prep function end <<<
