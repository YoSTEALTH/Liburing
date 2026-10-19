//! Phase 2 spike (plan.md): a one-function Setu extension that links C liburing compiled by
//! `build.zig` and uses the headers from `b.addTranslateC`. Throwaway; not part of the port.
//!
//!     zig build spike [-Dfree-threaded=false]
//!     python3.15t -c "import sys; sys.path.insert(0, 'spike'); import liburing_spike; print(liburing_spike.init_exit(8))"

const setu = @import("setu");
const c = @import("c");
const build_options = @import("build_options");

const sc = setu.c;
const py = setu.py;

/// The `exportFns` functions.
pub const fns = struct {
    /// Set up a ring with `entries` entries on the stack, tear it down, and return its SQ size.
    pub fn init_exit(entries: u32) py.Error!u32 {
        var ring: c.io_uring = undefined;
        const res = c.io_uring_queue_init(entries, &ring, 0);
        if (res < 0) return py.raiseErrno(-res);
        defer c.io_uring_queue_exit(&ring);
        return ring.sq.ring_entries;
    }
};

const module_methods = py.exportFns(fns, @embedFile("spike.zig")) ++ [_]sc.MethodDef{py.method_end};

const abi_info: sc.ABIInfo = .{
    .flags = if (build_options.free_threaded) sc.PyABIInfo_FREETHREADED else sc.PyABIInfo_GIL,
    .build_version = sc.version_3_15,
    .abi_version = sc.version_3_15,
};

const module_slots = [_]sc.Slot{
    sc.Slot.data(sc.Py_mod_abi, &abi_info),
    sc.Slot.data(sc.Py_mod_name, "liburing_spike"),
    sc.Slot.data(sc.Py_mod_doc, "Liburing phase 2 spike."),
    sc.Slot.static(sc.Py_mod_methods, &module_methods),
    sc.Slot.uint(sc.Py_mod_gil, 0), // Py_MOD_GIL_USED (plan.md decision 4)
    sc.Slot.uint(sc.Py_mod_multiple_interpreters, sc.Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED),
    sc.Slot.end,
};

/// PEP 793 entry point: CPython 3.15 looks up `PyModExport_<name>`.
export fn PyModExport_liburing_spike() callconv(.c) [*]const sc.Slot {
    return &module_slots;
}
