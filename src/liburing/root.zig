//! Liburing
const oz = @import("PyOZ");
const enums = @import("enum.zig");
const class = @import("class.zig");
const uring = @import("uring.zig");
const statx = @import("statx.zig");
const socket = @import("socket.zig");
const consts = @import("const.zig");
const errors = @import("error.zig");
const helper = @import("helper.zig");

pub const Module = oz.module(.{
    .name = "_liburing",
    .doc = "Zig wrapper around C Liburing, which is a helper to setup and tear-down io_uring instances.",
    .funcs = &(uring.Functions ++ helper.Functions ++ errors.Functions),
    .classes = &(class.Classes ++ socket.Classes ++ statx.Classes),
    .enums = &enums.Enums,
    .consts = &(consts.Constants ++ statx.Constants),
});

// Module initialization function
// pub export fn PyInit__liburing() ?*oz.PyObject {
//     return Module.init();
// }
