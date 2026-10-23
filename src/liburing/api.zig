//! What the `liburing` module exports, for `root.zig` (the module) and `stubgen.zig` (its stubs).
const setu = @import("setu");
const class = @import("class.zig");
const ring = @import("ring.zig");
const cqe = @import("cqe.zig");
const sqe = @import("sqe.zig");
const register = @import("register.zig");
const msghdr = @import("msghdr.zig");
const helper = @import("helper.zig");
const statx = @import("statx.zig");
const futex = @import("futex.zig");
const socket = @import("socket.zig");

/// Setu settings, read by `setu.Class` from the root file.
pub const setu_options: setu.Options = .{ .module = "liburing" };

/// Every class, in creation order (a base before its subclasses).
pub const classes = .{
    class.TimespecType,       ring.RingType,              cqe.CQEType,
    cqe.CqeType,              cqe.CqeBatchType,           cqe.CqeBatchIterType,
    cqe.CqeIterType,          sqe.SQEType,                sqe.SqeType,
    class.ProbeType,          class.ParamType,            register.RegWaitType,
    register.RestrictionType, register.BufRegType,        register.SyncCancelRegType,
    register.NapiType,        register.ZcrxIfqRegType,    register.QueryType,
    register.ZcrxCtrlType,    register.ClockRegisterType, register.BpfType,
    class.SigsetTType,        class.SiginfoTType,         register.MemRegionRegType,
    register.BufRingType,     msghdr.CmsghdrType,         msghdr.MsghdrType,
    msghdr.EpollEventType,    msghdr.RecvmsgOutType,      class.OpenHowType,
    helper.FileIndexType,     helper.FileIndexIterType,   statx.StatxType,
    futex.FUTEXType,          futex.FutexType,            socket.SockaddrType,
};

/// The files whose UPPER_CASE `pub const` ints are module constants.
pub const constant_files = .{ @import("const.zig"), statx, futex, socket };

/// The enums exported as `enum.IntEnum` classes of the same name.
pub const enums = .{ @import("enum.zig").io_uring_op, @import("enum.zig").io_uring_socket_op };

/// A file whose `pub fn`s are module functions, with its source (for docs and parameter names).
pub const File = struct { M: type, source: []const u8 };

/// The files whose `pub fn`s are module functions.
pub const files = [_]File{
    .{ .M = @import("error.zig"), .source = @embedFile("error.zig") },
    .{ .M = helper, .source = @embedFile("helper.zig") },
    .{ .M = @import("queue.zig"), .source = @embedFile("queue.zig") },
    .{ .M = @import("complete.zig"), .source = @embedFile("complete.zig") },
    .{ .M = @import("register.zig"), .source = @embedFile("register.zig") },
    .{ .M = @import("prep_file.zig"), .source = @embedFile("prep_file.zig") },
    .{ .M = @import("prep_net.zig"), .source = @embedFile("prep_net.zig") },
    .{ .M = @import("prep_ctl.zig"), .source = @embedFile("prep_ctl.zig") },
    .{ .M = socket, .source = @embedFile("socket.zig") },
};
