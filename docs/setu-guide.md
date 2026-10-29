# Writing a Setu extension

Setu turns ordinary Zig into a CPython module: you write `pub fn`s and structs, Setu writes the C-ABI
trampolines, the type objects, the docstrings and the `.pyi` stub. One binary loads on CPython 3.14, 3.14t,
3.15, 3.15t and later. This guide is the working reference for a session that writes bindings with Setu
(in Setu's own `test/`, in Liburing, in Shakti). Read section 1 first; the rest is lookup. Every signature
here is Setu's current one; Setu refuses what it can not express with a `@compileError` that says why
(section 10), so compile early.

Where things are: `setu.py` (the one namespace to use: references, conversions, raising, the module),
`setu.c` (the C API, hand-declared, every object opaque), `setu.Class`, `setu.Exception`, `setu.Module`,
`setu.From`, `setu.CallArgs`, `setu.Visit`, `setu.Send`, `setu.Poll`. The test extension `test/` of Setu
has one class per hook family (`test/classes.zig`), one function per parameter type (`test/functions.zig`)
and the model root file (`test/setu_classes.zig`); `test/class_test.py` shows what each does from Python.

## 1. The ten rules

1. One root file declares `pub const module: setu.Module = .{ .name, .version, .from = &.{...}, .init }`
   and ends with `comptime { py.exportModule(module); }`. Nothing else registers anything; `build.zig`
   writes the `.pyi` from the same declaration (`addStubs`).
2. A lowercase `pub fn` in a `from` file is a Python function under that name (`prep_recv`, `get_label`).
   camelCase `pub fn`s are Zig-only helpers. There is no opt-out: the case picks the audience.
3. Give an int parameter the exact type the kernel or callee takes (`fd: i32`, `flags: u32`): Setu raises
   `OverflowError` naming the parameter. A value no parameter type can bound goes through
   `` py.narrow(T, v, "`f(x)`") ``. Every `@intCast` / `@truncate` carries a `// cast: <why it fits>` comment
   on its line or the line above (`tools/check.sh` checks).
4. `?T` is optional: omitted or `None` gives `null`. A positional parameter after one with a default needs a
   default too (compile error); make it keyword-only after `_: py.KwOnly`.
5. Return `Error!R` and raise with `return py.raise*(...)`. `error.PythonError` means "an exception is
   set"; any other Zig error becomes `RuntimeError` (`error.OutOfMemory` becomes `MemoryError`).
6. Buffers: `py.Buffer` / `py.WritableBuffer` are locked for the call and released after it. To keep one
   past the call, `try buf.take()` (a second view, released by your `deinit`) or take `py.OwnedBuffer` /
   `py.OwnedWritableBuffer` (yours to `deinit`). Never store a plain `Buffer`.
7. A struct becomes a type with `pub const XType = setu.Class(X, @embedFile("x.zig"))`. Fields are the
   instance data and need defaults; a `?*Object` field is an owned reference Setu traverses and clears.
8. Hooks are `pub fn __name__` with the signatures of section 5. `__init__` / `__new__` / `__call__` take
   named parameters or one `setu.CallArgs`, never `py.Rest` / `py.Kwargs` (compile error).
9. Docs are `///` lines above the declaration: a description, then sections (`Type`, `Example`, `Note`,
   `Flags`, ...) as a header on its own line with content indented 4 spaces. `Type` entries override the
   stub's types (`return: Iterator[T]`); `Example` is a real `>>>` session, each result on the next line.
10. Hot paths: generated code must benchmark like hand-written code. Fill arguments in place, keep slow
    paths out of line, measure before and after with `tools/bench.py` (section 9).

## 2. The module

The root file (`test/setu_classes.zig` is the model):

```zig
const setu = @import("setu");
const py = setu.py;

pub const module: setu.Module = .{
    .name = "liburing", // the import name: `liburing/__init__.so` (or `liburing.so`)
    .version = build_options.version, // `__version__`
    .from = &.{
        .{ .ns = @import("ring.zig") }, // classes only: no `source` needed
        .{ .ns = @import("prep.zig"), .source = @embedFile("prep.zig") }, // functions need the source
        .{ .ns = @import("sqe.zig"), .functions = false }, // lowercase Zig helpers there
        .{ .ns = kernel, .prefixes = &.{ "IOSQE_", "IORING_OP_" } }, // constants by prefix
        .{ .ns = @import("enums.zig"), .enums = .int_enum }, // `enum.IntEnum` classes
    },
    .init = init, // after Setu's part of `Py_mod_exec`
};

/// The project's own setup: classes exist, constants are set.
fn init(mod: *setu.c.Object) py.Error!void {
    _ = mod;
}

comptime {
    py.exportModule(module);
}
```

`setu.Module` fields: `name`, `doc` (default: the `//!` doc of the first `from` entry with a `source`),
`version`, `from`, `init`, `stub_extra` (lines the stub gets for what `init` adds by hand), `methods` (a
hand-written `c.MethodDef` table; a name there replaces the scanned function of that name), `exec` (runs
after `init`), `gil` (`true`: the free-threaded build enables the GIL on import), `multiple_interpreters`
(default `false`: Setu keeps state in globals).

What a `from` entry (`setu.From`) takes from its `ns`: lowercase `pub fn`s (functions; need `.source`),
`setu.Class` declarations (Python name: the struct's), `setu.Exception` declarations (Python name: the
`pub const`'s), `pub const E = enum` (its UPPER_CASE fields as int constants, or the `IntEnum` `E` with
`.enums = .int_enum`), UPPER_CASE `pub const` ints / floats / `bool`s / strings. Skipped: `_` names,
camelCase functions, plain structs, lowercase values, `pub var`s. Filters take Python names: `.only`,
`.exclude` (not together; each name must exist), `.prefixes`, `.functions = false`. Classes are created
bases first; a Python name found twice is a compile error naming both places.

`build.zig` of the project (`setu` in its `build.zig.zon`):

```zig
const setu_dep = b.dependency("setu", .{ .target = target, .optimize = optimize });
ext.root_module.addImport("setu", setu_dep.module("setu"));
const pyi = @import("setu").addStubs(b, setu_dep, .{
    .root_source_file = b.path("src/liburing/root.zig"),
    .imports = &.{.{ .name = "build_options", .module = options.createModule() }}, // what the root imports
});
b.getInstallStep().dependOn(&b.addInstallFileWithDir(pyi, .lib, "__init__.pyi").step); // next to __init__.so
@import("setu").addSetuBuildSteps(b, setu_dep); // tools/setu_build.py: setu-build-sync / -check
@import("setu").addSetuDocsSteps(b, setu_dep); // tools/setu_docs.py: setu-docs-sync / -check, docs-web
@import("setu").addSetuGuideSteps(b, setu_dep); // docs/setu-guide.md: setu-guide-sync / -check
@import("setu").addCoverageSteps(b, setu_dep, ext, .{ // zig build coverage: kcov over pytest (see 11.)
    .module_name = "liburing", // the name the tests import the extension by
    .package = true, // it is `liburing/__init__.so`
    .include = &.{ b.path("src/liburing"), setu_dep.path("src") }, // the sources to report
    .stub = pyi, // for tests that read the .pyi next to the extension
    .python = b.option([]const u8, "python", "Python for `coverage`") orelse "python3",
});
@import("setu").addProfileSteps(b, setu_dep, ext, .{ // zig build profile: callgrind over the cases (see 11.)
    .module_name = "liburing",
    .package = true,
    .cases = b.path("tools/bench_cases.py"), // `CASES` + `namespace(module)`, as Setu's tools/bench.py
});
```

The extension is the package itself, `<name>/__init__.so` next to `__init__.pyi` and `py.typed` (section 7), or a
plain `<name>.so` (`@import("setu").ext_suffix`); the wheel `cp314.cp315-abi3.abi3t.cp314t.cp315t`
(`tools/setu_build.py`, a PEP 517 backend each project keeps a byte-identical copy of).

## 3. Functions

A lowercase `pub fn` in a `from` file. Arguments are positional or keyword, by the Zig parameter name;
`inspect.signature` and the stub show the names and defaults. Below: Zig parameter type (what Python accepts): notes.

- `i32`, `u64`, `u8`, ... (up to 64 bits) (`int`, `__index__`): `` OverflowError: `f(x)` = 300 is out of range 0..255 ``
- `?u32` (`int`, `None`, omitted): `None` / omitted give `null`; stub `int | None = None`
- `bool` (anything): truthiness, like `if x:`
- `f64`, `f32` (`float`, `int`)
- `[]const u8`, `[:0]const u8` (`str`): UTF-8, borrowed for the call
- `py.Bytes` (`bytes`): `.data`, borrowed
- `py.Path` (`str`, `bytes`, `os.PathLike`): `.path` is `[:0]const u8` (`os.fsencode`); released after the call
- `py.Buffer` / `py.WritableBuffer` (bytes-like / writable bytes-like): `.data`; locked for the call, then released
- `py.OwnedBuffer` / `py.OwnedWritableBuffer` (the same): yours: `defer data.deinit()` or store it
- `py.Sequence(T)` (any sequence (`list`, `tuple`, `range`, ...)): `.items: []T`, each converted like a `T`; released
  after
- `*T`, `*const T`, `?*T` (an instance of `setu.Class(T)` or a subclass): `TypeError` otherwise; `XType.object(d)` is
  the object
- `*Object`, `?*Object` (anything): raw, borrowed; `None` is passed through as a value
- `rest: py.Rest` (`*args`): first (after `self`); `.items`, `try rest.tuple()`; parameters before it: positional-only
- `_: py.KwOnly` (`*`): the parameters after it are keyword-only
- `extra: py.Kwargs` (`**kwargs`): last parameter; `.dict` is `null` when none; functions and methods only
- `a: struct { x: i64 = 0, _: py.KwOnly = .{}, fd: i32 = AT_FDCWD }` (named arguments): an argument struct, see below

An argument struct's field defaults are the Python defaults, shown as written (`null` -> `None`, `a.b.NAME` ->
`NAME`, so the module must export `NAME`); a field without a default is required.

Return types: `void` (`None`), `bool`, ints, floats, `?T` (`null` -> `None`), `Error!T`, `[]const u8` /
a literal (`str`), `py.Bytes` (`bytes`), `*Object` (a new reference, taken), tuples `.{ a, b }` (`tuple`),
other slices (`list`). `py.toPython(value)` does this conversion by hand (`null` with an exception set on
failure); `try py.new(value)` the same as `Error!*Object`.

From here on the examples are Setu's test extension `setu_classes` (`test/`): a Zig block is its code, the Python
block after it a session with it, which `test/guide_test.py` runs on every interpreter. The sessions call the module
`pkg`, standing for your package (`from pkg import read`).

```zig
/// Reads up to `n` bytes (default: all of `buf`) from `fd` into `buf` at `offset`; returns how many.
///
/// Example
///     >>> import os
///     >>> fd = os.open('a.txt', os.O_RDWR | os.O_CREAT)
///     >>> os.write(fd, b'hello world')
///     11
///     >>> b = bytearray(8)
///     >>> read(fd, b, 4, offset=6)
///     4
///     >>> b
///     bytearray(b'worl\x00\x00\x00\x00')
///     >>> os.close(fd)
pub fn read(fd: i32, buf: py.WritableBuffer, n: ?usize, _: py.KwOnly, offset: i64) Error!usize {
    const want = @min(n orelse buf.data.len, buf.data.len);
    const res: isize = @bitCast(std.os.linux.pread(fd, buf.data.ptr, want, offset)); // cast: a signed word
    return @intCast(try py.checkErrno(res)); // cast: `checkErrno` gave >= 0
}
```

Stub: `def read(fd: int, buf: Buffer, n: int | None = None, *, offset: int) -> int:`. In Python:

```pycon
>>> import os
>>> from pkg import read
>>> fd = os.open('a.txt', os.O_RDWR | os.O_CREAT)
>>> os.write(fd, b'hello world')
11
>>> b = bytearray(8)
>>> read(fd, b, 4, offset=6)  # n = 4
4
>>> b
bytearray(b'worl\x00\x00\x00\x00')
>>> read(fd, b, offset=0)  # n omitted: all of b
8
>>> b
bytearray(b'hello wo')
>>> read(fd, b, 4, 0)  # offset is keyword-only
Traceback (most recent call last):
  ...
TypeError: read() takes at most 3 positional arguments (4 given)
>>> read(fd, b, -1, offset=0)  # n is a usize
Traceback (most recent call last):
  ...
OverflowError: `read(n)` = -1 is out of range 0..18446744073709551615
>>> read(-1, b, offset=0)  # py.checkErrno
Traceback (most recent call last):
  ...
OSError: [Errno 9] Bad file descriptor
>>> os.close(fd)
```

## 4. Raising

Every helper sets the exception and returns `error.PythonError`, so a binding writes `return py.raise...`. Below: the
call: what it raises.

- `py.raiseTypeError(fmt, args)`, `raiseValueError`, `raiseIndexError`, `raiseRuntimeError`: that built-in, with a
  formatted message
- `raiseOverflowError`, `raiseNotImplementedError`, `raiseAttributeError` (the same): (up to 511 bytes, cut after that)
- `py.raise(c.PyExc_ZeroDivisionError, fmt, args)`: any `c.PyExc_*`
- `py.raiseErrno(errno)`: `OSError(errno, strerror)`; CPython picks the subclass (`FileNotFoundError`, ...)
- `try py.checkErrno(res)`: `res` when `>= 0`, else `OSError` for the errno `-res`; `res` is any signed int
- `py.raiseOSError(errno, fmt, args)`: `OSError(errno, msg)` with your message
- `py.raiseWith(exc, .{ errno, "msg" })`: `exc(*args)`, each item converted like a result
- `py.raiseNoMemory()`: `MemoryError` (a failed Zig allocation)
- `MyError.raise(fmt, args)`, `MyError.raiseWith(.{...})`: an exception class of the extension (below)
- `py.setError(err)`: any Zig error as a Python exception (what the trampolines do for you)

An exception class of the extension, found by the scan under the `pub const`'s name, `__module__` the
extension's:

```zig
/// An `OSError` of the extension's own: `ExtraError(errno, msg)` sets `.errno` / `.strerror`.
pub const ExtraError = setu.Exception(.{
    .doc = "An `OSError` of the extension's own: `ExtraError(errno, msg)` sets `.errno` / `.strerror`.",
    .base = .OSError, // a `c.PyExc_*` name; default `.Exception`
});

/// A plain `Exception` subclass.
pub const PlainError = setu.Exception(.{ .doc = "A plain `Exception` subclass." });

/// Raises `ExtraError(errno, msg)` (`raiseWith`).
pub fn raise_extra(errno: i32, msg: []const u8) Error!void {
    return ExtraError.raiseWith(.{ errno, msg }); // `.errno` set, like `OSError`
}

/// Raises `PlainError` with a formatted message (`raise`).
pub fn raise_plain(n: i64) Error!void {
    return PlainError.raise("plain {d}", .{n});
}

/// Is `exc` a `PlainError` (an instance or the class, or a subclass)? (`matches`)
pub fn is_plain(exc: *c.Object) bool {
    return PlainError.matches(exc);
}
```

In Python:

```pycon
>>> from pkg import ExtraError, PlainError, is_plain, raise_extra, raise_plain
>>> raise_extra(95, 'not here')
Traceback (most recent call last):
  ...
pkg.ExtraError: [Errno 95] not here
>>> try:
...     raise_extra(2, 'gone')
... except OSError as e:  # the base catches it
...     e.errno, e.strerror
(2, 'gone')
>>> raise_plain(3)
Traceback (most recent call last):
  ...
pkg.PlainError: plain 3
>>> is_plain(PlainError('x')), is_plain(ValueError())
(True, False)
```

Two `setu.Exception`s with the same `doc` and `base` are one Zig type: give each its own `doc`.

## 5. Classes

```zig
/// A 2D vector with integer coordinates: comparisons, hashing, numbers, pickling.
pub const Vec = struct {
    x: i64 = 0, // instance data: every field has a default
    y: i64 = 0,

    pub const basetype = true; // Python may subclass it
    /// How many coordinates a `Vec` has.
    pub const DIMS = 2; // UPPER_CASE: a class attribute

    /// Sets the coordinates.
    pub fn __init__(self: *Vec, a: struct { x: i64 = 0, y: i64 = 0 }) void {
        self.x = a.x;
        self.y = a.y;
    }

    /// `Vec(x, y)`.
    pub fn __repr__(self: *const Vec) Error!*Object {
        var buf: [64]u8 = undefined; // fits 2 x 20 digits
        const text = std.mem.print(&buf, "Vec({d}, {d})", .{ self.x, self.y }) catch unreachable;
        return py.new(text);
    }

    /// The squared length.
    pub fn norm2(self: *const Vec) i64 {
        return self.x * self.x + self.y * self.y;
    }

    /// A new vector of the class `cls` (a subclass too).
    pub fn from_pair(cls: *c.TypeObject, x: i64, y: i64) Error!*Object {
        const obj = c.PyObject_CallNoArgs(@ptrCast(cls)) orelse return error.PythonError;
        VecType.data(obj).* = .{ .x = x, .y = y };
        return obj;
    }

    /// The dot product of two vectors.
    pub fn dot(a: *const Vec, b: *const Vec) i64 {
        return a.x * b.x + a.y * b.y;
    }
};
pub const VecType = setu.Class(Vec, @embedFile("classes.zig")); // declare once, use this name

/// A `Vec` with a label: a Setu subclass, pickled with its base's fields.
pub const Labeled = struct {
    label: ?*Object = null, // owned reference: traversed, cleared, dropped by Setu

    pub const base = VecType;

    /// Sets the label (the coordinates stay 0).
    pub fn __init__(self: *Labeled, label: ?*Object) void {
        if (label) |l| py.incref(l);
        py.decref(self.label);
        self.label = label;
    }

    /// The label.
    pub fn get_label(self: *const Labeled) *Object {
        const l = self.label orelse py.none();
        py.incref(l);
        return l;
    }

    /// Sets the label; `None` is refused (a plain Zig error: `RuntimeError: NoLabel`).
    ///
    /// Type
    ///     value: object
    pub fn set_label(self: *Labeled, value: *Object) error{NoLabel}!void {
        if (value == py.none()) return error.NoLabel;
        py.incref(value);
        py.decref(self.label);
        self.label = value;
    }
};
pub const LabeledType = setu.Class(Labeled, @embedFile("classes.zig"));
```

(Cut from `test/classes.zig`, which gives `Vec` more hooks.) Stub: `@disjoint_base\nclass Vec:` with
`DIMS: ClassVar[int]`, `def __init__(self, x: int = ..., y: int = ...) -> None:`, `def norm2(self) -> int:`,
`@classmethod def from_pair(cls, x: int, y: int) -> Any:`, `@staticmethod def dot(a: Vec, b: Vec) -> int:`;
`@final\nclass Labeled(Vec):` with the property `label`. In Python:

```pycon
>>> from pkg import Labeled, Vec
>>> v = Vec(3, y=4)  # __init__'s argument struct: positional or keyword
>>> v, v.norm2(), Vec.DIMS
(Vec(3, 4), 25, 2)
>>> Vec(x='a')
Traceback (most recent call last):
  ...
TypeError: 'str' object cannot be interpreted as an integer
>>> Vec.from_pair(1, 2), Vec.dot(Vec(1, 2), Vec(3, 4))  # a class method, a static method
(Vec(1, 2), 11)
>>> class Vec3(Vec):  # basetype
...     pass
>>> type(Vec3.from_pair(1, 2)).__name__
'Vec3'
>>> l = Labeled('home')
>>> l.label, isinstance(l, Vec)
('home', True)
>>> l.label = 'work'  # set_label
>>> l.label
'work'
>>> l.label = None
Traceback (most recent call last):
  ...
RuntimeError: NoLabel
```

Settings (`pub const` in the struct): `name` (`"pkg.Name"`; default `<module>.<struct name>`), `base`
(another `Class`, created first), `basetype`, `instantiable = false` (only Zig creates instances, with
`new`), `getset` / `slots` (extra `c.GetSetDef`s / `c.Slot`s, with `stub` lines for them), `weakref`,
`dict` (a `__dict__`), `pickle` (generated `__getstate__` / `__setstate__` over ints, floats, `bool`s and
`?*Object`s of the type and its bases), `plain_methods` (`.{"get_nowait"}`: methods named like accessors),
`type_params` (`"T"`: `Name[int]` works, the stub says `class Name[T]:`), `hidden` (created, not added to
the module, `Any` in the stub), and UPPER_CASE consts as class attributes.

Methods: a lowercase `pub fn` whose first parameter is named `self` (an instance method), `cls: *c.TypeObject`
(a class method, `@classmethod`), anything else (a static method, `@staticmethod`). `self` is `*T`,
`*const T` or `*Object`. `get_x` / `set_x(self, value: U)` are the property `x`. Parameters and results as in
section 3; a `py.Rest` right after `self` is `*args`.

What the `Class` gives Zig: `VecType.tp` (the type object, after creation), `VecType.data(obj)` (the
`*Vec` of an instance or subclass instance), `VecType.object(d)` (the object back from its data),
`VecType.check(obj)`, `try VecType.new(.{ .x = 1 })` (a new instance, also of a type Python can not
instantiate), `setu.Instance(Vec).from(obj)` (`*Vec` or `TypeError`).

Hooks, by name (the full list is at the top of `src/class.zig`; `R` is the hook's Zig result, `Error!R` is
fine everywhere; a hook parameter is converted like a method argument, `*Object` keeps it raw, and a
`Path` / buffer / `Sequence` parameter is a compile error since nothing would release it). Below: the hook (its slot):
behaviour.

- `__new__(self, ...)` (`tp_new`): after allocation and the field defaults; named parameters or one `setu.CallArgs`
- `__init__(self, ...)` (`tp_init`): the same; gives the type's `__text_signature__`
- `__call__(self, ...)` (`tp_call`): arguments parsed like a method's
- `__traverse__(self, v: *setu.Visit) setu.Visit.Error!void` (`tp_traverse`): `try v.add(obj)` beyond the `?*Object`
  fields
- `__clear__(self)`, `__del__(self)` (`tp_clear`, `tp_dealloc`): extra GC / dealloc work, after Setu's
- `__finalize__(self)` (`tp_finalize`): once, fields still set; may call Python; must not raise
  (`PyErr_WriteUnraisable`)
- `__send__(self, arg: *Object) setu.Send` (`am_send`, `tp_iternext`, `tp_iter`): `.{ .next = v }` yields, `.{ .done = v
  }` ends (new refs)
- `__poll__(self, sent: ?*Object) setu.Poll` (generated `__await__` / `__send__`): `.pending` yields `self`; `.{ .ready
  = v }` ends; see below
- `__await__(self) *Object` (`am_await`): the iterator `await obj` drives
- `__iter__(self) R`, `__next__(self) ?R` (`tp_iter`, `tp_iternext`): `null` ends it; without `__iter__` the iterator is
  its own
- `__len__(self) usize` (`mp_length`)
- `__getitem__(self, key: K) R` (`mp_subscript`): `key` converted like an argument
- `__setitem__(self, key: K, value: V)`, `__delitem__(self, key: K)` (`mp_ass_subscript`): a missing one raises
  `TypeError`
- `__contains__(self, item: I) bool` (`sq_contains`): an `item` of another type is not contained
- `__bool__(self) bool`, `__repr__(self) R`, `__str__(self) R`, `__hash__(self) <int>` (`nb_bool`, `tp_repr`, `tp_str`,
  `tp_hash`): -1 hashes as -2
- `__eq__`, `__ne__`, `__lt__`, `__le__`, `__gt__`, `__ge__` `(self, other: O) bool` (`tp_richcompare`): another type:
  `NotImplemented`; see below
- `__add__`, `__sub__`, `__mul__`, `__truediv__`, `__floordiv__`, `__mod__`, `__divmod__` `(self, other: O) R` (`nb_*`):
  see below
- `__pow__`, `__lshift__`, `__rshift__`, `__and__`, `__or__`, `__xor__`, `__matmul__` `(self, other: O) R` (`nb_*`): see
  below
- `__r<op>__(self, other: O) R`, `__i<op>__(self, other: O) R` for each of those (`nb_*`): reflected, in place; see
  below
- `__neg__`, `__pos__`, `__abs__`, `__invert__` `(self) R` (`nb_*`)
- `__int__`, `__index__` `(self) <int>`; `__float__(self) <float>` (`nb_*`): an int / a float result, checked at compile
  time
- `__getattr__(self, name: []const u8) R` (`tp_getattro`): after normal lookup raised `AttributeError`
- `__setattr__(self, name, value: V)`, `__delattr__(self, name)` (`tp_setattro`): every assignment / deletion; a missing
  one: the default
- `__get__(self, instance: ?*Object, owner: ?*Object) R` (`tp_descr_get`): `instance` is `null` when read on the class
- `__set__(self, instance: *Object, value: V)`, `__delete__(self, instance: *Object)` (`tp_descr_set`)

Comparisons: `!=` is `not __eq__` without `__ne__`; `__eq__` without `__hash__` makes the type unhashable, as in Python.
Number operators: `__r<op>__` runs when the instance is on the right, `__i<op>__` in place (a `void` result returns
`self`); `pow` with a modulus raises `TypeError`. A `__poll__`'s `sent` is `null` on the first send, then what the loop
sent in. The reflected and in-place names in full, for searching: `__radd__`, `__rsub__`, `__rmul__`, `__rtruediv__`,
`__rfloordiv__`, `__rmod__`, `__rdivmod__`, `__rpow__`, `__rlshift__`, `__rrshift__`, `__rand__`, `__ror__`, `__rxor__`,
`__rmatmul__`; `__iadd__`, `__isub__`, `__imul__`, `__itruediv__`, `__ifloordiv__`, `__imod__`, `__ipow__`,
`__ilshift__`, `__irshift__`, `__iand__`, `__ior__`, `__ixor__`, `__imatmul__` (`__idivmod__` is a compile error: Python
has no in-place `divmod`).

A `__send__` / `__poll__` type may not also declare `__iter__` / `__next__` (generated); `__poll__` and
`__send__` exclude each other. After `.ready` or an error, awaiting a `__poll__` object again raises
`RuntimeError`.

## 6. Buffers and ownership

Type (locked; released by): use.

- `py.Buffer`, `py.WritableBuffer` (for the call; Setu, after the call): use during the call; `try b.take()` for a view
  of your own
- `py.OwnedBuffer`, `py.OwnedWritableBuffer` (until your `deinit`; you (store it, `defer deinit`)): memory the kernel
  uses later; one `GetBuffer`
- `py.Sequence(T)` (for the call; Setu, after the call): `try s.take()` copies the items (each `take`n), keeps the tuple
- `py.Path` (n/a (a `bytes` it holds); Setu, after the call): `try p.take()` keeps it

```zig
/// What `own` keeps.
var owned: struct {
    buf: ?py.OwnedWritableBuffer = null,
    data: ?py.OwnedBuffer = null,
} = .{};

/// Releases what the last call kept, then keeps `buf` and `data` as they come (`py.OwnedWritableBuffer` /
/// `py.OwnedBuffer`, no second view): locked until the next call. `own()` only releases; with
/// `drop=True` the function releases them itself before returning.
pub fn own(buf: ?py.OwnedWritableBuffer, data: ?py.OwnedBuffer, drop: ?bool) void {
    if (owned.buf) |b| b.deinit();
    if (owned.data) |d| d.deinit();
    owned = .{};
    if (drop orelse false) {
        if (buf) |b| b.deinit();
        if (data) |d| d.deinit();
        return;
    }
    owned = .{ .buf = buf, .data = data };
}
```

In Python, a kept `bytearray` is locked (it can not be resized) until the extension releases it:

```pycon
>>> from pkg import own
>>> b = bytearray(3)
>>> own(b)  # kept
>>> b.append(1)
Traceback (most recent call last):
  ...
BufferError: Existing exports of data: object cannot be re-sized
>>> b[0] = 7  # writing is fine
>>> own()  # released
>>> b.append(1)
>>> b
bytearray(b'\x07\x00\x00\x01')
```

Rules: when a later argument fails to convert, the function is not called and Setu releases everything,
owned buffers included; once the function runs, an owned buffer is its own, on error paths too. A
`Sequence` of an owned buffer type is a compile error (use `Sequence(Buffer)` and `take`), `take` of an owned
buffer too. `take` asks the argument itself for the second view, so an object with a Python `__buffer__` can be
kept too. A buffer whose view has no object (`PyBuffer_FillInfo(NULL)`) raises `BufferError` on `take`.
On 3.14t / 3.15t a `bytearray` argument costs 10-15 ns more: CPython's own critical section.

## 7. Docs and the stub

`///` above a declaration (the `//!` block at the top of the first `from` file with a `source` is the module
docstring). Format: a description, a blank `///` line, then sections, each a header on its own line with
its content indented 4 spaces:

```zig
/// `path` encoded like `os.fsencode` (`py.Path`).
///
/// Type
///     return: bytes
///
/// Example
///     >>> path_bytes('/tmp/x')
///     b'/tmp/x'
///     >>> path_bytes(b'/tmp')
///     b'/tmp'
///     >>> path_bytes(3)
///     TypeError: expected str, bytes or os.PathLike object, not int
pub fn path_bytes(path: py.Path) Error!*Object {
    return py.new(py.Bytes{ .data = path.path });
}
```

In Python the doc is the function's `__doc__` (what `help()` shows), the stub's docstring and the site's entry;
`Type` changed the stub's return type from `Any` (a `*Object`) to `bytes`:

```pycon
>>> import inspect
>>> from pkg import path_bytes
>>> path_bytes('/tmp/x'), path_bytes(b'/tmp')
(b'/tmp/x', b'/tmp')
>>> path_bytes.__doc__.splitlines()[:4]  # what help() shows
['`path` encoded like `os.fsencode` (`py.Path`).', '', 'Type', '    return: bytes']
>>> inspect.signature(path_bytes)
<Signature (path)>
```

The stub: `def path_bytes(path: str | bytes | os.PathLike[str] | os.PathLike[bytes]) -> bytes:` with that docstring.

`Type` entries (`name: type  # note` or `name: type - note`; `return:` for the result) replace the Zig-derived
type in the stub; bare generics get their arguments (`os.PathLike` -> `os.PathLike[str] | os.PathLike[bytes]`,
`list` -> `list[Any]`, `Coroutine` -> `Coroutine[Any, Any, Any]`). Without one, the stub maps the Zig type:
ints -> `int`, floats -> `float`, `[]const u8` -> `str`, `py.Bytes` -> `bytes`, `py.Path` -> `str | bytes |
os.PathLike[...]`, buffers -> `Buffer`, `py.Sequence(T)` -> `Sequence[T]`, slices -> `list[T]`, tuples ->
`tuple[T, U]`, `void` -> `None`, `?T` -> `T | None = None`, `*T` -> the class name (`Any` if hidden),
`*Object` -> `Any`. A method parameter that would stub as `Any` without a `Type` entry is a compile error
(rename a Zig helper camelCase, or add the entry). The stub imports only the names it uses, is laid out as
`ruff format` would, leaves out `__repr__` / `__str__` (`object` declares them), and passes `mypy --strict`,
`stubtest` and ruff's flake8-pyi rules (`PYI`, apart from `PYI021`: the docstrings stay) in Setu's checks.
`tools/setu_docs.py` turns the same docstrings into a static HTML site (and `llms.txt` / `llms-full.txt` for AI
readers), and runs every `Example` to check that its output is what the doc says (`setu_docs.py check`). A
repeated `Example` header starts another block (one per call form: `Sqe()`, then `Sqe(2)`), shown with its own
Run and run on its own, in a new namespace. Setu numbers repeated headers in the docstring: `help()`, the stub and
the site show `Example #1`, `Example #2`, ... (`setu_docs.py run Sqe:2` runs `Example #2`); write plain `Example`,
a hand-written `Example #<n>` is a compile error. A `Flags` section lists one name per line, optionally with a
note (`IORING_TIMEOUT_ABS  # ts is a point in time`): the site links the name and shows the note as text. A bare
`https://` URL anywhere in a docstring (outside backticks) becomes a link that opens in a new tab; a trailing `.`,
`,` or `)` stays text unless the `)` closes a `(` in the URL.
In the site's Markdown pages an `@@path@@` line includes a project file as a code block (an example script, as tested);
the header's ◐ button opens the theme menu (Nord Day, Nord Night, Tokyo Day, Tokyo Night; until one is picked,
Tokyo Day, or Nord Night when the system is dark); `coverage =
'zig-out/coverage.json'` and `profile = 'zig-out/profile.json'` in `[tool.setu_docs]` add the Coverage and Profile pages
(section 11); the Profile page is local only: `setu_docs.py serve` makes it from the file as it is, `build` (CI, the
published site) leaves it out, so nothing outside your machine needs `zig build profile`. The site builds from
`setu_docs.py` alone: no wrapper script, no copied CSS (a `css` file only for the project's own colors).

Ship the extension as its package's `__init__.so`, with the stub as `__init__.pyi` and a `py.typed` (PEP 561 marks
packages only, so a bare top-level `liburing.so` gets no typing): `import liburing` loads the extension itself, a
package (`__path__`), on every supported interpreter; `from liburing import *` gives its public names, and its
classes' `__module__` is the import name. No `__init__.py`: next to an `__init__.so` it never runs (extensions are
found first), and `tools/setu_build.py` refuses to ship one. Python code goes in submodules (`liburing/util.py`).
The stub must be `__init__.pyi`: a `liburing.pyi` next to `__init__.so` types a `liburing.liburing` that is not
there, and `liburing` itself gets no types. Moving from the
submodule layout below: `liburing.liburing` no longer exists (use `liburing`), delete the old `liburing.so` /
`liburing.pyi` copies in `src/liburing/` (`setu_build.py` refuses them: `import liburing.liburing` would load a stale
extension), and pass `.package = true` to `addCoverageSteps`.

Only a package with Python code at its top level needs the extension as a submodule (`pkg/ext.so` next to `ext.pyi`,
`.name = "ext"`) re-exported from `__init__.py`. To keep the submodule out of `from pkg import *`, give the package
an `__all__`, not a `del ext` (that breaks `import pkg.ext; pkg.ext.Ring`). Hide the computed `__all__` from type
checkers: they cannot evaluate it and would then see none of the stub's names (`mypy --strict` reports every one
`name-defined`):

```python
from . import ext
from .ext import *

TYPE_CHECKING = False
if not TYPE_CHECKING:
    __all__ = [name for name in dir(ext) if not name.startswith("_")]
del TYPE_CHECKING
```

## 8. Ints and casts

`fromPython` reads any int (`__index__` too) and raises `OverflowError` with the parameter's name and the
type's range, also past 64 bits. So the parameter type is the check: `fd: i32`, `len: u32`, `offset: u64`.
When one value is read as two types or checked against state, `const index = try py.narrow(u32, fd,
"`close(fd)` with `direct=True`");`. `@intCast` / `@truncate` are for values the code itself bounds, each
with a `// cast: <why it fits>` comment (`tools/check.sh` rejects one without). Constants wider than
`c_long` are fine (`pub const ALL_ONES: u64 = maxInt(u64)`).

## 9. Performance

Measured facts from Setu's notes (ns per call, `tools/bench.py`, A/B interleaved, best of several runs, on
all four interpreters):

- Most per-call cost was store-forwarding stalls: a value written in small parts (CPython filling a
  `Py_buffer`, an inlined `Error!T`, an optional's tag) then read with one wider load. So arguments are
  filled in place in the arguments tuple (`BufferArg.fill`), big argument structs are not copied, and slow
  paths stay out of line (`intArg`, `outOfRange`, `notWritable`: `@branchHint(.cold)`).
- Whether a copy happens depends on LLVM's inlining, so identical source can run 2x apart between builds:
  compare A/B builds with `objdump -d`, interleaved, best of several runs.
- `inline` changes nothing in `fast` builds (`-Doptimize=fast`): LLVM inlines the call path anyway. A moved
  trampoline can read ~1 ns slower with identical code (placement). `tools/bench.py --so a --so b` can read the
  second build 1-1.5 ns slower on the cheapest call (`bench_nop`): swap the order before believing such a gap.
- A flag on an argument (marking a `take`n copy) cost 6-8 ns per buffer argument; `take` takes a second view
  instead. `OwnedBuffer` saves that view (24-43 ns in Liburing's buffer preps).
- Reference points: Shakti's `loop_bench` nop serial ~204 ns, batch ~129 ns, `SQE()` ~48 ns; Liburing's
  `prep_recv(sqe, -1, bytearray)` ~22 ns.

When touching `src/class.zig` / `src/export.zig` / `src/convert.zig` / `src/args.zig`: `python3 tools/bench.py
--ref HEAD` before claiming a change is neutral, and `zig build profile` (section 11) before and after: instructions
per call are exact on every run, so a change of one instruction shows, and `--lines` says which line it is on. Time
and instructions together tell a change that saves work from one that only moves it (a stall costs time, not
instructions).

## 10. Compile errors Setu raises

What the message says: the cause.

- `anytype` parameters are not supported: a `pub fn` with an `anytype` parameter is exported
- only plain required parameters can come before `py.Rest`: a default / `?T` / struct / `KwOnly` before `*args`
- `py.Kwargs` must be the last parameter
- more than one `py.KwOnly`
- the required parameter `b` comes after `a`, which has a default: section 1, rule 4
- `py.KwOnly` after `py.Rest` is redundant: after `*args` everything is keyword-only already
- `py.Rest` / `py.Kwargs` are not supported here; take one `setu.CallArgs` parameter: `__new__` / `__init__` /
  `__call__`
- no default for `x` in the source: the argument struct's default is not in the file (`structBody`)
- the argument struct `Opts` must be declared in the same file
- can't show the default `...` in Python; use a literal, `null` or a constant: a default the stub can not render
- no `pub fn name(` in source / no `const Name = struct {` in source: the `@embedFile` is not the declaration's file
- `pub fn x` needs the entry's `.source = @embedFile(...)`: a function in a `from` entry without `source`
- `.only` and `.exclude` together / `.only` names `x`, which it does not declare
- `x` is in the module twice: `a.x` and `b.x`: one Python name from two declarations
- `A.T` and `B.T` are the same type: one `setu.Class` / `setu.Exception` type under two names
- its base `pkg.Base` is in no `Module.from` entry
- `Module.methods` must end with `py.method_end` (or set `from`, `version` or `init`): a table without its terminator
- unsupported parameter type / result type `T`: an int over 64 bits, a non-slice pointer, a plain struct result, ...
- `checkErrno` takes a signed int
- `Sequence(OwnedBuffer)`: the items are released with the sequence: use `Sequence(Buffer)` and `take`
- `take` of an owned buffer: it is the function's already
- a `py.Buffer` hook parameter is never released; take `*Object` and convert it in the hook: a buffer / `Path` /
  `Sequence` hook parameter
- `__poll__` generates `__send__`; give one / `__send__` / `__poll__` generate `__iter__` and `__next__`
- `pickle` needs an instantiable type / `T.f`: a `U` can not be pickled: `pickle = true` with `instantiable = false` or
  a bad field
- `cls` must be `*c.TypeObject`: a class method's first parameter
- `__hash__` must return an int / `__len__` an unsigned int / `__next__` `?R` / `__int__` an int / `__float__` a float:
  result types
- `__get__` takes `instance: ?*Object, owner: ?*Object`
- needs `pub const module: setu.Module` in the root file, for the module name: a `setu.Class` with no `module` in the
  root
- method `m`: parameter `p` stubs as `Any`; if it is a Zig-only helper rename it camelCase, else add a `Type` entry: 7
- not in the 3.15 stable ABI (abi3t), which Setu builds for: a `c.*` tombstone; use the replacement it names

## 11. Checks

    zig build test                          # type-check every declaration + comptime unit tests
    zig build develop                       # test/setu_classes.so (every interpreter) + setu_classes.pyi
    /opt/python/3.15t/bin/python3 -m pytest # then 3.15, 3.14t, 3.14: the same .so
    tools/check.sh                          # everything, offline, on all four interpreters
    python3 tools/bench.py --ref HEAD       # per-call cost A/B against a commit
    zig build profile -Doptimize=fast -Dcpu=x86_64_v3   # instructions per call, per line (callgrind);
                                                        # -Drelease with a preferred optimize mode

A project using Setu runs its own `tools/check.sh`, which includes `zig build setu-build-check`,
`setu-docs-check` and `setu-guide-check` (its copies of Setu's script, docs helpers and this guide match the
Setu it pins). After a Setu bump: `zig build setu-build-sync setu-docs-sync setu-guide-sync`.

Line coverage: `zig build coverage [-Dpython=...] [-- --missed --partial pytest args]` (`addCoverageSteps`; kcov 43)
prints a per-file table, with `--missed` the lines that never ran, with `--partial` the yellow ones, and writes the
numbers to `zig-out/coverage.json` (totals, per interpreter, per file and line, each file's CRC-32; the format is in
`tools/check_coverage.py`). Files are named relative to the project, a dependency's as `<package>/<path>`
(`setu/src/args.zig`), wherever it lives. kcov's own output (an HTML report, XML, JSON: some 70 files per interpreter)
goes to a temporary directory, removed after the run; `-- --html DIR` keeps its HTML report. On the docs site (`coverage
= 'zig-out/coverage.json'`) the Coverage page has a section per owner (the project, then each dependency), and a click
on a file shows its source, Zig highlighted, the missed lines red; a source changed since the run (its CRC-32) is
flagged `changed`. `.badge = "docs/coverage-badge.json"` also writes the total as a shields.io endpoint file; committed,
it is a README badge: the image `https://img.shields.io/endpoint?url=<URL>`, `<URL>` the file's
`raw.githubusercontent.com` address, percent-encoded (run with every `--python` first: the badge shows the merged
total). `.history = "docs/coverage-history.json"` also keeps the totals per project version (`build.zig.zon`'s
`.version`; a run sets its version's entry, one line each); committed, with `coverage_history =
'docs/coverage-history.json'` in `[tool.setu_docs]` the Coverage page charts them next to the project's donut. In CI it
needs kcov, packaged for Ubuntu 25.04+: on GitHub's `ubuntu-26.04` runner the apt package `kcov`, then the step with
every `--python`; Setu's `.github/workflows/ci.yml` also fails when the committed badge or history differs from the
run's (`git diff --exit-code docs/coverage-badge.json docs/coverage-history.json`). Notes:

- It measures the extension as built, in Debug. The default Debug backend (self-hosted x86_64) pads its line
  tables with ops kcov (elfutils) misreads, so kcov runs a copy with the padding rewritten (the build is not
  changed). That backend gives each line its own code, so every red line is code that never ran; an LLVM build
  (`.use_llvm = true`, aarch64) folds a line like `orelse return ...` into the one above (its error path shows as
  run) and marks some comment and `fn` lines red (a jump nothing takes).
- kcov records nothing from a shared library loaded once about 24 are mapped, and `import pytest` maps more, so
  `tools/check_coverage.py` loads the extension first, as `.module_name`; a test importing another copy fails.
- Zig compiles only referenced code: a function nothing calls is not counted as missed.
- kcov's colours (`--html`; the runner's terms too): green ran, red never ran, yellow ran at some of its addresses
  only (counted as covered). In Zig, yellow is mostly a generic line (`fromPython(T)`, a trampoline) whose instance
  for some type never ran: `hits` of `possible` addresses, e.g. 48 of 56 int conversions.
- Code the tests are not meant to run (benchmark helpers, out-of-memory branches) goes between `// coverage-off`
  and `// coverage-on` comments and is not counted, so every red line is a gap.
- `coverage` needs pytest in the interpreter it runs (and in each `--python`), else it stops with that error.
- The tests' child processes (a test running `python3 example.py`) are not measured: they import the normal build,
  and kcov parsing its self-hosted-backend DWARF grew to 25 GB in one of Liburing's runs, so the runner keeps kcov's
  preload out of them. A run is stopped once kcov and the tests use more than `-- --max-memory GB` (default 8).
- `-- --python /opt/python/3.14/bin/python3` (repeatable) runs the tests under that interpreter too; the table
  merges the runs (a line ran if it ran in any), so code only one interpreter reaches (3.14's `PyInit_` entry)
  counts. `--html DIR` then keeps one report per interpreter, `DIR/<3.15t, 3.14, ...>/index.html`; there is no
  merged HTML report (`kcov --merge` counts the `coverage-off` lines again).

Zig unit tests (code that does not call libpython) get the same through `addZigTestCoverage`: kcov over a
`b.addTest` executable as built, the same table, options after `--` (`--missed`, `--html DIR`, the
rest to the executable) and JSON format, in `zig-out/coverage-zig.json`:

```zig
const tests = b.addTest(.{ .root_module = core });
@import("setu").addZigTestCoverage(b, setu_dep, tests, .{ // zig build coverage-zig
    .include = &.{b.path("src/core")}, // the sources to report
    .step_name = "coverage-zig", // the default; the result is zig-out/<step_name>.json
});
```

Instructions per call: `zig build profile -Doptimize=fast -Dcpu=x86_64_v3 [-- -k TEXT --lines K --python PATH
--baseline FILE]` (`addProfileSteps`; valgrind 3.25) runs each case of `.cases` under callgrind, N and 2N times
(the difference over N is one call, Python's startup and the loop taken out), and prints a table per interpreter:
`total` (everything one call costs) and `ext` (the part in the extension's `.so`: its code, Setu's and std's,
inlined there); `--lines K` lists each case's K costliest lines with their source. The numbers go to
`zig-out/profile.json` (per case, file and line; the format is in `tools/check_profile.py`). Setu's own cases
include `bench_nop` / `bench_recv` written by hand against the C API (`test/hand.zig`, `hand: ...`): generated
code costs 4-26 fewer instructions per call than those on every interpreter (2026-10-28).

    zig build profile -Doptimize=fast -Dcpu=x86_64_v3 -- --lines 8 -k recv
    cp zig-out/profile.json /tmp/before.json      # then change the code
    zig build profile -Doptimize=fast -Dcpu=x86_64_v3 -- --baseline /tmp/before.json   # Δ per case

- `ext` is the same on every run, `total` within about 0.3 per call: `--baseline` fails when either grew by more
  than `--tolerance` (default 2).
- The build must be optimized, with debug info, for a CPU valgrind runs (no AVX-512): the step fails otherwise.
- `.cases` is a Python file with `CASES`, a list of `(label, statement)`, and `namespace(module)`, which returns
  the names the statements use; Setu's `tools/bench.py` is one, so `bench.py` times the cases `profile` counts.
- A line `0` is code the compiler added (no source line).
- `profile = 'zig-out/profile.json'` in `[tool.setu_docs]` adds a Profile page to the docs site: a row per case with
  a bar per interpreter (the extension's part dark); a click on a case shows its files' sources, each costly line
  with its instructions per call, shaded by them.

Memory errors and leaks: valgrind memcheck over the project's pytest, by hand (no build step):

    zig build develop -Dcpu=x86_64_v3       # valgrind can not run AVX-512 (SIGILL, exit 132)
    PYTHONMALLOC=malloc valgrind --leak-check=full --errors-for-leak-kinds=definite --error-exitcode=99 \
        python3 -m pytest -q
    zig build develop                       # the native build back

- Clean is "0 errors" and "definitely lost: 0 bytes". "Possibly lost" 56-byte blocks from module init
  (`PyType_FromMetaclass`, one per class and exception) are the type objects kept for the process: valgrind sees
  them only through a pointer past CPython's GC header.
- The default Debug backend's line table is partly unreadable to valgrind ("Badly formed extended line op"): build
  through LLVM (`.use_llvm = true` on the extension's library) for full source lines in its stacks.
