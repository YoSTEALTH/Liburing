# Liburing
[![Python](https://img.shields.io/badge/python-3.14%20%7C%203.14t%20%7C%203.15%20%7C%203.15t-blue)](https://www.python.org/)
[![Zig](https://img.shields.io/badge/zig-0.17.0-orange)](https://ziglang.org/)
![PyPI - Downloads](https://img.shields.io/pypi/dm/liburing)
[![Test status](https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml) 

Liburing is Python + Zig wrapper around [C Liburing](https://github.com/axboe/Liburing), which is a helper to setup and tear-down io_uring instances.

- Fast & scalable asynchronous I/O (storage, networking, ...) interface.
- io_uring reduces number of syscalls overhead & context switches, thus improving speed.

Good(old) documentation [Lord of the io_uring](https://unixism.net/loti/)

## Requires
 - Linux 6.8+
 - Python 3.14+ (regular or free-threaded: 3.14, 3.14t, 3.15, 3.15t, ...)
 - pip: any for 3.14, 3.14t, 3.15, 3.15t; 26.2+ for 3.16t and later (`abi3t`)

One binary, built on CPython's stable ABI, loads on every supported version. On Python 3.10 to 3.13,
`pip install liburing` installs the last release that supports them.

## Includes (battery)
 - C liburing 2.15+

## Install, update & uninstall (Alpha)

Use [pip](https://pip.pypa.io/en/stable/getting-started/) to install, upgrade & uninstall Python wrapper

```bash
python3 -m pip install liburing             # install

python3 -m pip install --upgrade liburing   # upgrade

python3 -m pip uninstall liburing           # uninstall
```

## To compile & install directly from GitHub

```bash
# note: make sure you have Zig 0.17.0 installed on your system (or set `ZIG=/path/to/zig`).

cd /tmp
git clone --recurse-submodules https://github.com/YoSTEALTH/Liburing
cd Liburing

python3 -m pip install .        # builds the wheel with `zig build` (tools/setu_build.py), no other dependencies

# uninstall
python3 -m pip uninstall liburing
```

## Development

```bash
zig build develop                       # `liburing.so` + `liburing.pyi` into src/liburing/ (one binary, 3.14+)
python3.15t -m pytest                   # tests run from the checkout (`pythonpath = ["src"]`)
tools/check.sh                          # every check: zig fmt, 3.15t / 3.15 / 3.14t / 3.14, mypy --strict, stubtest

python3.15t tools/setu_build.py --all   # release wheels into dist/ (x86_64 + aarch64)
```

## To find out all the class, functions and definitions

```python
import liburing

# To see all the importable names
print(dir(liburing))

# To see all the help docs
help(liburing)
```

## Find out which `io_uring` operations is supported by the kernel

```python
# example/probe.py
import liburing

for k, v in liburing.probe().items():
    print(k, v)

```

## Simple File Example

```python
# example/open_write_read_close.py
from liburing import O_CREAT, O_RDWR, Ring, Cqe, io_uring_get_sqe, \
                     io_uring_prep_open, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_submit, io_uring_wait_cqe, \
                     io_uring_cqe_seen, io_uring_queue_init, io_uring_queue_exit


def open(ring, cqe, path, flags):
    sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
    io_uring_prep_open(sqe, path, flags)
    # set submit entry identifier as `1` which is returned back in `cqe.user_data`
    # so you can keep track of submit/completed entries.
    sqe.user_data = 1
    return _submit_and_wait(ring, cqe)  # returns fd


def write(ring, cqe, fd, data):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, fd, data)
    sqe.user_data = 2
    return _submit_and_wait(ring, cqe)  # returns length(s) of bytes written


def read(ring, cqe, fd, length):
    buffer = bytearray(length)  # where read data will be stored
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, fd, buffer)
    sqe.user_data = 3
    _submit_and_wait(ring, cqe)  # get actual length of file read.
    return buffer


def close(ring, cqe, fd):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 4
    _submit_and_wait(ring, cqe)  # no error means success!


def _submit_and_wait(ring, cqe):
    io_uring_submit(ring)  # submit entry
    io_uring_wait_cqe(ring, cqe)  # wait for entry to finish
    entry = cqe[0]
    try:
        result = entry.res  # auto raises appropriate exception if failed
    except Exception as e:
        raise e  # do stuff with error
    # done with current entry so clear it from completion queue.
    io_uring_cqe_seen(ring, entry)
    return result  # type: int


def main():
    ring = Ring()
    cqe = Cqe()  # completion queue entry
    try:
        io_uring_queue_init(8, ring)

        fd = open(ring, cqe, "/tmp/liburing-test-file.txt", O_CREAT | O_RDWR)
        print("fd:", fd)

        length = write(ring, cqe, fd, b"hi... bye!")
        print("wrote:", length)

        content = read(ring, cqe, fd, length)
        print("read:", content)

        close(ring, cqe, fd)
        print("closed.")
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    main()

```

## Speed: C liburing vs Liburing

The same NOP loops written with the same calls, in C (`example/bench/loop_bench.c`) and in Python
(`example/bench/loop_bench.py`), ns per operation (lower is better), best of 5:

| case                                    | C liburing | Liburing 3.15 | 3.15t | 3.14 | 3.14t |
|-----------------------------------------|-----------:|--------------:|------:|-----:|------:|
| nop serial (submit + wait each)         |         84 |           256 |   263 |  242 |   249 |
| nop batch x1024                         |         22 |            91 |    90 |   84 |    89 |
| nop batch x1024 + read `user_data, res` |         24 |           127 |   127 |  127 |   139 |
| ... + read with `cqe.res_at(i)`         |          - |           122 |   121 |  120 |   121 |
| `put_sqe` batch x1024                   |         22 |            23 |    23 |   23 |    23 |

`put_sqe` copies entries prepared once (`Sqe(1024)`) into the ring: no Python call per operation, the same
speed as C. AMD Ryzen 9 9900X (one core, `taskset -c 2`), Linux 7.2, Liburing built with `-Drelease`,
C with `-O2`, 2026-10-20. To run them:

```bash
zig build develop -Drelease
PYTHONPATH=src python3.15 example/bench/loop_bench.py
zig cc -O2 -D_GNU_SOURCE -Ilib/liburing/src/include -o zig-out/bin/loop_bench_c example/bench/loop_bench.c lib/liburing/src/{setup,queue,register,syscall,version}.c
zig-out/bin/loop_bench_c
```

## Note
 - This project has been moved to using Zig as back-end, thus leading to breaking changes from previous release.
 - Try using latest Linux if possible to enable all `io_uring` features.

<!--
## Other Projects
 - [Shakti](https://github.com/YoSTEALTH/Shakti) -->

## License
Free, Public Domain (CC0). [Read more](https://github.com/YoSTEALTH/Liburing/blob/dev/LICENSE.txt)
