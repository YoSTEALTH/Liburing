//! Liburing
const oz = @import("PyOZ");
const class = @import("class.zig");
// const socket = @import("socket.zig");
// const statx = @import("statx.zig");

pub const Liburing = oz.module(.{
    .name = "liburing",
    .from = &.{
        // oz.withSource(@import("enum.zig"), @embedFile("enum.zig")),
        // oz.withSource(@import("const.zig"), @embedFile("const.zig")),
        // oz.withSource(@import("error.zig"), @embedFile("error.zig")),
        // oz.withSource(@import("statx.zig"), @embedFile("statx.zig")),
        // oz.withSource(@import("helper.zig"), @embedFile("helper.zig")),

        // comment/uncomment out bottom
        oz.withSource(@import("class.zig"), @embedFile("class.zig")),
    },
    // comment/uncomment out bottom
    // .classes = &(class.Classes ++ socket.Classes),

    // .funcs = &.{},
});
