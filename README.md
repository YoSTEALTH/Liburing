# Liburing

[![PyPI](https://img.shields.io/pypi/v/liburing)](https://pypi.org/project/liburing/)
[![Downloads](https://img.shields.io/pypi/dm/liburing)](https://pypi.org/project/liburing/)
[![Python](https://img.shields.io/badge/python-3.14%20%7C%203.14t%20%7C%203.15%20%7C%203.15t-blue)](https://www.python.org/)
[![Linux](https://img.shields.io/badge/linux-6.17%2B-yellow)](https://kernel.org/)
[![liburing](https://img.shields.io/badge/liburing-2.15-lightgrey)](https://github.com/axboe/liburing/releases/tag/liburing-2.15)
[![Zig](https://img.shields.io/badge/zig-0.17.0-orange)](https://ziglang.org/)
[![License](https://img.shields.io/badge/license-CC0--1.0-green)](https://github.com/YoSTEALTH/Liburing/blob/main/LICENSE.txt)
[![Test status](https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml)
[![Docs](https://github.com/YoSTEALTH/Liburing/actions/workflows/docs.yml/badge.svg)](https://yostealth.github.io/Liburing/)

Fast, asynchronous Linux I/O for Python: a Zig-built wrapper around C liburing and the kernel's io_uring interface.

- **One syscall, many requests.** Queue reads, writes, accepts, sends and timeouts in a shared ring, submit them in one call, collect results as they finish. Fewer syscalls and context switches, so lower latency and higher throughput.
- **Storage and networking in one loop.** Unlike epoll, io_uring does the work for regular files too: open, read, write, statx, rename, sockets, timers and futexes all go through the same queues.
- **Mirrors the C API.** Same function names and argument order as liburing, so the man pages and C examples carry over almost line for line. All 92 `io_uring_prep_*` operations are covered, plus `probe()` to ask the kernel what it supports.
- **Pythonic where it matters.** Failed completions raise the matching `OSError`, type stubs pass `mypy --strict`, every function has a docstring.
- **One binary, no dependencies.** Built on CPython's stable ABI: one wheel loads on Python 3.14, 3.14t, 3.15 and 3.15t. Bundles C liburing 2.15.

| | |
|---|---|
| Documentation | https://yostealth.github.io/Liburing/ |
| Benchmarks | https://yostealth.github.io/Liburing/bench.html |
| Source | https://github.com/YoSTEALTH/Liburing |

## Requirements

- Linux 6.17 or newer. A newer kernel enables more `io_uring` features.
- Python 3.14 or newer, regular or free-threaded.
- pip: any version for 3.14, 3.14t, 3.15 and 3.15t; 26.2 or newer for 3.16t and later (`abi3t`).

On Python 3.10 to 3.13, `pip install liburing` installs the last release that supports them.

## Install

Use [pip](https://pip.pypa.io/en/stable/getting-started/) to install, upgrade and uninstall:

```bash
python3 -m pip install liburing             # install
python3 -m pip install --upgrade liburing   # upgrade
python3 -m pip uninstall liburing           # uninstall
```

### Build from source

Needs Zig 0.17.0 on the system (or set `ZIG=/path/to/zig`). There are no other build dependencies.

```bash
git clone --recurse-submodules https://github.com/YoSTEALTH/Liburing
cd Liburing
python3 -m pip install .        # builds the wheel with `zig build` (tools/setu_build.py)
```

### Development

```bash
zig build develop                       # `__init__.so` + `__init__.pyi` into src/liburing/ (one binary, 3.14+)
python3.15t -m pytest                   # tests run from the checkout (`pythonpath = ["src"]`)
tools/check.sh                          # zig fmt, pytest on all four, docstring examples, mypy --strict, stubtest

python3.15t tools/setu_build.py --all   # release wheels into dist/ (x86_64 + aarch64)
```

## Usage

### Explore the API

```python
import liburing

# To see all the importable names
print(dir(liburing))

# To see all the help docs
help(liburing)
```

### Which `io_uring` operations does the kernel support?

```python
# example/probe.py
from liburing import *

for k, v in probe().items():
    print(k, v)
```

### Open, write, read and close a file

The basic pattern: get a submission queue entry, prepare the request on it, submit, wait for the completion,
read its result. Here one request at a time.

```python
# example/open_write_read_close.py
"""Open, write, read and close a file: every step a request on the ring, one at a time."""

import os
import tempfile
from liburing import *


def submit_and_wait(ring, cqe):
    io_uring_submit(ring)  # hand the queued request to the kernel
    io_uring_wait_cqe(ring, cqe)  # wait for its completion
    entry = cqe[0]
    result = entry.res  # raises the matching `OSError` if the operation failed
    io_uring_cqe_seen(ring, entry)  # done with this entry
    return result


def main():
    path = os.path.join(tempfile.mkdtemp(), "example.txt")
    ring = Ring()
    cqe = Cqe()  # a completion queue entry
    io_uring_queue_init(8, ring)  # a ring with room for 8 requests
    try:
        sqe = io_uring_get_sqe(ring)  # a submission queue entry
        io_uring_prep_open(sqe, path, O_CREAT | O_RDWR)
        sqe.user_data = 1  # comes back in `cqe.user_data`, to tell completions apart
        fd = submit_and_wait(ring, cqe)
        print("fd:", fd)

        data = b"Hello, io_uring!"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, data)
        sqe.user_data = 2
        print("wrote:", submit_and_wait(ring, cqe))  # bytes written

        buffer = bytearray(len(data))  # held by the request until the read completes
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, buffer, 0)  # from the start of the file
        sqe.user_data = 3
        print("read:", submit_and_wait(ring, cqe), buffer)  # bytes read

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        sqe.user_data = 4
        submit_and_wait(ring, cqe)  # no error means closed
        print("closed.")
    finally:
        io_uring_queue_exit(ring)
        os.unlink(path)
        os.rmdir(os.path.dirname(path))


if __name__ == "__main__":
    main()
```

### Copy a file with linked requests

C liburing's `examples/link-cp.c`. Each chunk is two requests in the ring at once: a read, and a write of the same
buffer that the kernel starts only when the read is done (`IOSQE_IO_LINK`). With 64 pairs in flight, one submit hands
the kernel up to 128 requests, and no data passes through Python. The file size, the opens and the closes go through
the ring too.

```python
# example/copy_file.py
"""Copy a file with linked requests: C liburing's `examples/link-cp.c`.

Every chunk is a pair of requests in the ring at once: a read into a buffer, and (`IOSQE_IO_LINK`) the write of
that buffer at the same offset, which the kernel starts only after the read is done. Up to `QD` pairs are in
flight, so one `io_uring_submit` hands the kernel many reads and writes; nothing is copied through Python.
The size comes from `io_uring_prep_statx`, the files from `io_uring_prep_open`: every step goes through the ring.

    python3 example/copy_file.py <source> <destination>
"""

import sys
from liburing import *

QD = 64  # pairs in flight at most
BS = 32 * 1024  # bytes per pair

READ, WRITE = 0, 1  # the low bit of `user_data`; the rest is the offset of the pair's chunk


def one(ring, cqe, prep, *args):
    """Submit one request on its own and give its result."""
    sqe = io_uring_get_sqe(ring)
    prep(sqe, *args)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    result = cqe[0].res  # raises the matching `OSError` if it failed
    io_uring_cqe_seen(ring, cqe[0])
    return result


def queue_pair(ring, src, dst, offset, size):
    """A read linked to a write of the same buffer: the two requests of one chunk."""
    buffer = bytearray(size)  # both requests hold it until their completions
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, src, buffer, offset)
    sqe.flags = IOSQE_IO_LINK  # the next entry starts when this one has finished, and only if it succeeded
    sqe.user_data = offset << 1 | READ
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, dst, buffer, offset)
    sqe.user_data = offset << 1 | WRITE


def copy_file(ring, cqe, src, dst, size):
    offset = inflight = 0
    while offset < size or inflight:
        queued = inflight
        while offset < size and inflight < 2 * QD:  # fill the queue: as many pairs as fit
            chunk = min(BS, size - offset)
            queue_pair(ring, src, dst, offset, chunk)
            offset += chunk
            inflight += 2
        if inflight != queued:
            io_uring_submit(ring)  # one syscall for every pair queued above

        depth = 2 * QD if offset < size else 1  # collect until a pair fits again (at the end: everything)
        while inflight >= depth:
            io_uring_wait_cqe(ring, cqe)
            entry = cqe[0]
            try:
                _ = entry.res  # the read's bytes, or the write's; a failed read also cancels its write (`ECANCELED`)
            finally:
                io_uring_cqe_seen(ring, entry)
            inflight -= 1


def main(source, destination):
    ring = Ring()
    cqe = Cqe()
    stat = Statx()
    io_uring_queue_init(2 * QD, ring)  # a read and a write per pair
    try:
        one(ring, cqe, io_uring_prep_statx, stat, source)
        src = one(ring, cqe, io_uring_prep_open, source, O_RDONLY)
        dst = one(ring, cqe, io_uring_prep_open, destination, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        copy_file(ring, cqe, src, dst, stat.size)
        one(ring, cqe, io_uring_prep_close, src)
        one(ring, cqe, io_uring_prep_close, dst)
        print(f"copied {stat.size} bytes")
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <source> <destination>")
    main(*sys.argv[1:])
```

### TCP echo server: multishot accept and receive, a buffer ring

C liburing's `examples/echo-server.c`, the modern `io_uring` networking pattern. One accept request stays armed for
every new connection, one receive request per connection stays armed for every chunk of data, and the kernel picks
the receive buffer from a shared pool, which gets it back once the echo has been sent. `Sqe(ring)` preps straight
into the ring's next free entry, so a busy loop creates no object per request.

```python
# example/echo_server.py
"""TCP echo server: C liburing's `examples/echo-server.c`, the modern io_uring networking pattern.

- Multishot accept: armed once, one completion per new connection.
- Multishot receive: armed once per connection, one completion per chunk of data.
- A provided buffer ring: the kernel picks a buffer from a shared pool for each receive, so no buffer is
  allocated or held per connection; the buffer goes back into the pool when its send has completed.

One thread, one ring, no object per request: `Sqe(ring)` preps straight into the next free entry, and
`Ring(auto_submit=True)` submits by itself when the queue is full. Linux 6.0+.

    python3 example/echo_server.py [port=8000]
    nc localhost 8000
"""

import errno
import os
import socket
import sys
from liburing import *

QD = 64  # submission queue entries
BUF_SIZE = 4096  # bytes per provided buffer
BUFFERS = 256  # buffers in the pool (a power of 2)
BGID = 0  # the pool's buffer group id

# `user_data`: bits 63-56 the event, 31-16 the buffer id (a send: which buffer to recycle), 15-0 the fd
ACCEPT, RECV, SEND = 1, 2, 3


def encode(event, fd, bid=0):
    return event << 56 | bid << 16 | fd


def main(port):
    ring = Ring(auto_submit=True)  # a full submission queue submits itself
    cqe = Cqe()
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", port))
    listener.listen(QD)
    listen_fd = listener.fileno()
    # `DEFER_TASKRUN`: completions are processed only when this thread waits for them (needs `SINGLE_ISSUER`).
    io_uring_queue_init(QD, ring, IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN)
    sqe = Sqe(ring)  # each prep takes the ring's next free entry

    # the buffer pool: `BUFFERS` buffers the kernel picks from when a receive needs one
    bufs = [bytearray(BUF_SIZE) for _ in range(BUFFERS)]
    mask = io_uring_buf_ring_mask(BUFFERS)
    br = io_uring_setup_buf_ring(ring, BUFFERS, BGID, 0)
    for bid, buf in enumerate(bufs):
        io_uring_buf_ring_add(br, buf, bid, mask, bid)
    io_uring_buf_ring_advance(br, BUFFERS)
    conns = set()  # open connections
    starved = set()  # connections whose receive stopped because the pool was empty (`ENOBUFS`)

    def add_accept():
        io_uring_prep_multishot_accept(sqe, listen_fd)
        sqe.user_data = encode(ACCEPT, listen_fd)

    def add_recv(fd):
        io_uring_prep_recv_multishot(sqe, fd)  # no buffer: the kernel picks one from group `BGID`
        sqe.flags = IOSQE_BUFFER_SELECT
        io_uring_sqe_set_buf_group(sqe, BGID)
        sqe.user_data = encode(RECV, fd)

    def add_send(fd, bid, length):
        io_uring_prep_send(sqe, fd, memoryview(bufs[bid])[:length])  # held until the completion
        sqe.user_data = encode(SEND, fd, bid)

    def recycle(bid):
        io_uring_buf_ring_add(br, bufs[bid], bid, mask, 0)
        io_uring_buf_ring_advance(br, 1)

    def close(fd):
        if fd in conns:  # once: a send may fail after its connection's receive closed it
            conns.discard(fd)
            starved.discard(fd)
            os.close(fd)

    print(f"echo server on 127.0.0.1:{port}", flush=True)
    add_accept()
    try:
        while True:
            io_uring_submit_and_wait(ring, 1)
            io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest completion
            ready = io_uring_cq_ready(ring)
            for i in range(ready):
                entry = cqe[i]
                flags, data = entry.flags, entry.user_data
                event, fd = data >> 56, data & 0xFFFF
                try:
                    res = entry.res  # raises the matching `OSError` for a failed request
                except OSError as e:
                    res = -e.errno
                more = flags & IORING_CQE_F_MORE  # the multishot request is still armed

                if event == ACCEPT:
                    if res >= 0:
                        conns.add(res)  # the new connection's fd
                        add_recv(res)
                    if not more:
                        add_accept()
                elif event == RECV:
                    if res > 0:
                        add_send(fd, flags >> IORING_CQE_BUFFER_SHIFT, res)  # echo from the buffer the kernel picked
                        if not more:
                            starved.add(fd)
                    elif res == -errno.ENOBUFS:
                        starved.add(fd)  # the pool is empty: arm again when a send gives a buffer back
                    else:
                        close(fd)  # `0`: the peer closed; else an error
                else:  # SEND
                    recycle(data >> 16 & 0xFFFF)  # back into the pool, sent or not
                    if res < 0:
                        close(fd)
                    while starved:  # a buffer is free again
                        add_recv(starved.pop())
            io_uring_cq_advance(ring, ready)  # done with all of them
    finally:
        io_uring_queue_exit(ring)  # frees the buffer ring too
        listener.close()


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 8000)
```

More under [`example/`](https://github.com/YoSTEALTH/Liburing/tree/main/example): the four ways to fill the
submission queue (`sqe_styles.py`), vectored reads and writes, messages between threads' rings through a futex,
and the HTTP servers of the [benchmark](https://yostealth.github.io/Liburing/bench.html) (`bench/`).

## Note

This release moves the back end from Cython to Zig, with breaking changes from earlier releases. See the
[documentation](https://yostealth.github.io/Liburing/) for the current API.

## License

Free, Public Domain (CC0). [Read more](https://github.com/YoSTEALTH/Liburing/blob/main/LICENSE.txt)
