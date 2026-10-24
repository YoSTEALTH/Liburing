# Install

```bash
python3 -m pip install liburing             # install
python3 -m pip install --upgrade liburing   # upgrade
python3 -m pip uninstall liburing           # uninstall
```

## Build from GitHub

Needs [Zig](https://ziglang.org/) 0.17.0 on `PATH` (or set `ZIG=/path/to/zig`).

```bash
git clone --recurse-submodules https://github.com/YoSTEALTH/Liburing
cd Liburing
python3 -m pip install .
```

## Development

```bash
zig build develop       # liburing.so + liburing.pyi into src/liburing/
python3 -m pytest       # tests run from the checkout
tools/check.sh          # every check
```
