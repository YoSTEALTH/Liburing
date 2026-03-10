//! Liburing
const oz = @import("PyOZ");

pub const Liburing = oz.module(.{
    .name = "liburing",
    .from = &.{
        oz.withSource(@import("class.zig"), @embedFile("class.zig")),
        oz.withSource(@import("const.zig"), @embedFile("const.zig")),
        oz.withSource(@import("enum.zig"), @embedFile("enum.zig")),
        oz.withSource(@import("error.zig"), @embedFile("error.zig")),
        oz.withSource(@import("helper.zig"), @embedFile("helper.zig")),
        oz.withSource(@import("uring.zig"), @embedFile("uring.zig")),
        oz.withSource(@import("statx.zig"), @embedFile("statx.zig")),
        oz.withSource(@import("socket.zig"), @embedFile("socket.zig")),
    },
});
