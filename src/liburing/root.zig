//! Liburing: the `liburing` extension module (PEP 793 export, Setu).
const std = @import("std");
const setu = @import("setu");
const build_options = @import("build_options");

const sc = setu.c;
const py = setu.py;
const Object = sc.Object;

const class = @import("class.zig");
const @"const" = @import("const.zig");
const @"enum" = @import("enum.zig");
const @"error" = @import("error.zig");
const helper = @import("helper.zig");
const uring = @import("uring.zig");
const statx = @import("statx.zig");
const futex = @import("futex.zig");
const socket = @import("socket.zig");

/// Setu settings, read by `setu.Class` from the root file.
pub const setu_options: setu.Options = .{ .module = "liburing" };

/// Every class, in creation order (a base before its subclasses).
const classes = .{
    class.IovecType,         class.TimespecType,      class.RingType,         class.CQEType,
    class.CqeType,           class.CqeIterType,       class.SQEType,          class.SqeType,
    class.ProbeType,         class.ParamType,         class.RegWaitType,      class.RestrictionType,
    class.BufRegType,        class.SyncCancelRegType, class.NapiType,         class.ZcrxIfqRegType,
    class.ClockRegisterType, class.BpfType,           class.SigsetTType,      class.MemRegionRegType,
    class.BufRingType,       class.CmsghdrType,       class.MsghdrType,       class.EpollEventType,
    class.RecvmsgOutType,    class.OpenHowType,       helper.FileIndexType,   statx.StatxType,
    futex.FUTEXType,         futex.FutexType,         socket.SockaddrType,
};

/// The files whose UPPER_CASE `pub const` ints are module constants.
const constant_files = .{ @"const", statx, futex, socket };

/// The files whose `pub fn`s are module functions.
const module_methods = py.exportFns(@"error", @embedFile("error.zig")) ++
    py.exportFns(helper, @embedFile("helper.zig")) ++
    py.exportFns(uring, @embedFile("uring.zig")) ++
    py.exportFns(socket, @embedFile("socket.zig")) ++
    [_]sc.MethodDef{py.method_end};

/// `Py_mod_exec`: creates the classes, constants and enums.
fn exec(module: *Object) callconv(.c) c_int {
    initModule(module) catch return -1;
    return 0;
}

fn initModule(module: *Object) py.Error!void {
    inline for (classes) |C| try C.create(module);
    inline for (constant_files) |F| try py.addConstants(module, F);
    if (sc.PyModule_AddStringConstant(module, "LIBURING_HAVE_DATA64", "") < 0) return error.PythonError;
    try addIntEnum(module, @"enum".io_uring_op);
    try addIntEnum(module, @"enum".io_uring_socket_op);
}

/// Adds the Zig enum `E` to `module` as an `enum.IntEnum` of the same name.
fn addIntEnum(module: *Object, comptime E: type) py.Error!void {
    const enum_mod = sc.PyImport_ImportModule("enum") orelse return error.PythonError;
    defer py.decref(enum_mod);
    const int_enum = sc.PyObject_GetAttrString(enum_mod, "IntEnum") orelse return error.PythonError;
    defer py.decref(int_enum);

    const fields = @typeInfo(E).@"enum".field_names;
    const members = sc.PyList_New(0) orelse return error.PythonError;
    defer py.decref(members);
    inline for (fields) |f| {
        const item = try py.new(.{ f, @as(i64, @backingInt(@field(E, f))) });
        defer py.decref(item);
        if (sc.PyList_Append(members, item) < 0) return error.PythonError;
    }

    const name = comptime shortName(@typeName(E));
    py.incref(members); // the tuple takes this reference
    const args = try py.new(.{ name, members });
    defer py.decref(args);
    const kwargs = sc.PyDict_New() orelse return error.PythonError;
    defer py.decref(kwargs);
    const module_name = try py.new("liburing");
    defer py.decref(module_name);
    const key = try py.new("module");
    defer py.decref(key);
    if (sc.PyDict_SetItem(kwargs, key, module_name) < 0) return error.PythonError;

    const cls = sc.PyObject_Call(int_enum, args, kwargs) orelse return error.PythonError;
    defer py.decref(cls);
    if (sc.PyModule_AddObjectRef(module, name, cls) < 0) return error.PythonError;
}

/// `io_uring_op` for `enum.io_uring_op`.
fn shortName(comptime full: []const u8) [:0]const u8 {
    const i = std.mem.lastIndexOfScalar(u8, full, '.') orelse return full ++ "";
    const s = full[i + 1 ..];
    return (s ++ "\x00")[0..s.len :0];
}

const abi_info: sc.ABIInfo = .{
    .flags = if (build_options.free_threaded) sc.PyABIInfo_FREETHREADED else sc.PyABIInfo_GIL,
    .build_version = sc.version_3_15,
    .abi_version = sc.version_3_15,
};

const module_slots = [_]sc.Slot{
    sc.Slot.data(sc.Py_mod_abi, &abi_info),
    sc.Slot.data(sc.Py_mod_name, "liburing"),
    sc.Slot.data(sc.Py_mod_doc, "Python + Zig wrapper around C liburing."),
    sc.Slot.static(sc.Py_mod_methods, &module_methods),
    sc.Slot.func(sc.Py_mod_exec, @ptrCast(&exec)),
    // A `Ring` is not safe to share across threads (plan.md decision 4).
    sc.Slot.uint(sc.Py_mod_gil, 0), // `Py_MOD_GIL_USED`: not in Setu's `capi.zig` yet
    sc.Slot.uint(sc.Py_mod_multiple_interpreters, sc.Py_MOD_MULTIPLE_INTERPRETERS_NOT_SUPPORTED),
    sc.Slot.end,
};

/// PEP 793 entry point: CPython 3.15 looks up `PyModExport_<name>`.
export fn PyModExport_liburing() callconv(.c) [*]const sc.Slot {
    return &module_slots;
}
