//! Post-processes `b.addTranslateC` output: a translated function whose body could not be
//! translated (it holds a `@compileError`, like liburing's atomics in `__io_uring_peek_cqe`) becomes
//! an `extern` declaration. `ffi.c` (compiled into `liburing-ffi.a`) exports every liburing inline
//! function, so the symbol exists.
//!
//!     c_externs <translated.zig> <out.zig>
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const cwd = std.Io.Dir.cwd();
    const src = try cwd.readFileAlloc(init.io, args[1], arena, .unlimited);

    var out: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, src, '\n');
    while (lines.next()) |line| {
        // A top-level function: `pub fn name(...) callconv(.c) T {` ... `}`, one line each end.
        if (std.mem.startsWith(u8, line, "pub fn ") and std.mem.endsWith(u8, line, " {")) {
            const start = out.items.len;
            try out.appendSlice(arena, line);
            try out.append(arena, '\n');
            var failed = false;
            while (lines.next()) |body| {
                try out.appendSlice(arena, body);
                try out.append(arena, '\n');
                if (std.mem.find(u8, body, "@compileError") != null) failed = true;
                if (std.mem.eql(u8, body, "}")) break;
            }
            if (failed) {
                out.shrinkRetainingCapacity(start);
                try out.appendSlice(arena, "pub extern fn ");
                try out.appendSlice(arena, line["pub fn ".len .. line.len - " {".len]);
                try out.appendSlice(arena, ";\n");
            }
            continue;
        }
        try out.appendSlice(arena, line);
        if (lines.index != null) try out.append(arena, '\n');
    }
    try cwd.writeFile(init.io, .{ .sub_path = args[2], .data = out.items });
}
