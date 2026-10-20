//! What the `liburing` module exports, for `root.zig` (the module) and `stubgen.zig` (its stubs).
const setu = @import("setu");

const class = @import("class.zig");
const helper = @import("helper.zig");
const statx = @import("statx.zig");
const futex = @import("futex.zig");
const socket = @import("socket.zig");

/// Setu settings, read by `setu.Class` from the root file.
pub const setu_options: setu.Options = .{ .module = "liburing" };

/// Every class, in creation order (a base before its subclasses).
pub const classes = .{
    class.IovecType,      class.TimespecType,      class.RingType,          class.CQEType,
    class.CqeType,        class.CqeIterType,       class.SQEType,           class.SqeType,
    class.ProbeType,      class.ParamType,         class.RegWaitType,       class.RestrictionType,
    class.BufRegType,     class.SyncCancelRegType, class.NapiType,          class.ZcrxIfqRegType,
    class.QueryType,      class.ZcrxCtrlType,      class.ClockRegisterType, class.BpfType,
    class.SigsetTType,    class.MemRegionRegType,  class.BufRingType,       class.CmsghdrType,
    class.MsghdrType,     class.EpollEventType,    class.RecvmsgOutType,    class.OpenHowType,
    helper.FileIndexType, statx.StatxType,         futex.FUTEXType,         futex.FutexType,
    socket.SockaddrType,
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
    .{ .M = @import("uring.zig"), .source = @embedFile("uring.zig") },
    .{ .M = socket, .source = @embedFile("socket.zig") },
};
