//! Liburing: the `liburing` extension module (Setu's `py.exportModule`).
const std = @import("std");
const api = @import("api.zig");
const setu = @import("setu");
const build_options = @import("build_options");

const sc = setu.c;
const py = setu.py;
const Object = sc.Object;

/// Setu settings, read by `setu.Class` from the root file.
pub const setu_options = api.setu_options;

/// The module functions, from every file in `api.files`.
const module_methods = blk: {
    var defs: []const sc.MethodDef = &.{};
    for (api.files) |f| defs = defs ++ py.exportFns(f.M, f.source);
    break :blk defs[0..].* ++ [_]sc.MethodDef{py.method_end};
};

/// `Py_mod_exec`: creates the classes, constants and enums.
fn exec(module: *Object) callconv(.c) c_int {
    initModule(module) catch return -1;
    return 0;
}

fn initModule(module: *Object) py.Error!void {
    inline for (api.classes) |C| try C.create(module);
    try @import("support.zig").init(module);
    inline for (api.constant_files) |F| try py.addConstants(module, F);
    if (sc.PyModule_AddStringConstant(module, "LIBURING_HAVE_DATA64", "") < 0) return error.PythonError;
    if (sc.PyModule_AddStringConstant(module, "__version__", build_options.version) < 0) return error.PythonError;
    inline for (api.enums) |E| try addIntEnum(module, E);
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
    const i = std.mem.findScalarLast(u8, full, '.') orelse return full ++ "";
    const s = full[i + 1 ..];
    return (s ++ "\x00")[0..s.len :0];
}

// The module: `PyModExport_liburing` (3.15+) and `PyInit_liburing` (3.14), one stable-ABI binary.
// Setu's default `gil` (`Py_MOD_GIL_NOT_USED`): the free-threaded CPython keeps the GIL off.
comptime {
    py.exportModule(.{
        .name = "liburing",
        .doc = "Python + Zig wrapper around C liburing.",
        .methods = &module_methods,
        .exec = &exec,
    });
}
