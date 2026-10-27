# Install

```bash
python3 -m pip install liburing             # install
python3 -m pip install --upgrade liburing   # upgrade
python3 -m pip uninstall liburing           # uninstall
```

Check it:

```bash
python3 -c 'import liburing; print(liburing.__version__)'
```

## Requirements

- **Linux 6.17 or newer** is what Liburing is tested on. Older kernels work for the operations they have; a request the kernel lacks fails in its completion, a setup or register feature it lacks raises `UnsupportedError`. `probe()` lists what the running kernel supports. Newer kernels add `io_uring` features, so run the newest you can.
- **Python 3.14 or newer**, regular or free-threaded. One wheel (`cp314.cp315-abi3.abi3t.cp314t.cp315t`) covers 3.14, 3.14t, 3.15 and 3.15t; it is built on the stable ABI, so later versions load it too.
- **pip**: any version for 3.14, 3.14t, 3.15 and 3.15t; 26.2 or newer for 3.16t and later (it understands the `abi3t` tag).
- **x86_64 or aarch64**, glibc 2.28 or newer (the two wheels on PyPI). Anything else: build from source.
- No dependencies: the wheel bundles C liburing 2.15.

On Python 3.10 to 3.13, `pip install liburing` installs the last release that supported them (a different, Cython-based code base with a different API).

## Build from source

Needs [Zig](https://ziglang.org/) 0.17.0 on `PATH` (or set `ZIG=/path/to/zig`). Nothing else: Zig compiles the bundled C liburing and the wrapper into one extension, `liburing/__init__.so` (the extension is the whole package).

```bash
git clone --recurse-submodules https://github.com/YoSTEALTH/Liburing
cd Liburing
python3 -m pip install .
```

`--recurse-submodules` fetches C liburing into `lib/liburing`; without it the build has nothing to compile (`git submodule update --init` fetches it later).

## Development

```bash
zig build develop                       # __init__.so + __init__.pyi into src/liburing/
python3 -m pytest                       # the tests import from src/ (pyproject's `pythonpath`)
tools/check.sh                          # every check, on each installed interpreter
python3 tools/setu_build.py --all       # release wheels into dist/ (x86_64 + aarch64)
```

`zig build develop` builds a Debug extension and regenerates the type stub `__init__.pyi` from the Zig source; `zig build develop -Drelease` builds the ReleaseSafe one the wheels ship (what the benchmarks use). `tools/check.sh` runs `zig fmt`, ruff, the test suite on 3.15t, 3.15, 3.14t and 3.14 (`/opt/python/<version>/bin/python3` by default; `PY_FT`, `PY_GIL`, `PY314_FT`, `PY314_GIL` point elsewhere), `mypy --strict` and `stubtest`.

This site is built by Setu's `tools/setu_docs.py` (standard library only, plus `zig` for the search's Wasm), with the settings in `pyproject.toml`'s `[tool.setu_docs]`:

```bash
python3 docs/gen_guide.py               # docs/guide.md, from docs/guide.template and example/
python3 tools/setu_docs.py              # the site into site/ (what CI runs)
python3 tools/setu_docs.py serve        # http://127.0.0.1:8000, with Run buttons on the examples
python3 tools/setu_docs.py check        # run the docstrings' >>> examples
```

The API reference is generated from `src/liburing/__init__.pyi`, so run `zig build develop` first.
