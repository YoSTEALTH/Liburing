# Liburing

**Fast, asynchronous Linux I/O for Python, straight from the kernel's `io_uring`.** Liburing is a Python wrapper, written in Zig, around [C liburing](https://github.com/axboe/liburing): the library that sets up and tears down `io_uring` instances and fills their queues.

## What is `io_uring`?

`io_uring` is Linux's asynchronous I/O interface. You write requests (read, write, accept, send, timeout, ...) into a **submission queue** that is shared with the kernel, tell the kernel once to start on all of them, and read the results from a **completion queue**. There is no syscall per operation and no thread pool: many requests go in with one syscall, and with `IORING_SETUP_SQPOLL` none are needed. The same interface covers storage and networking, which `epoll` cannot do for regular files.

## Why this wrapper?

- **One event manager for everything.** `epoll` only tells you a socket or pipe is *ready*, and says nothing useful for regular files. `io_uring` does the work itself: file reads and writes, `open` / `close` / `statx` / `rename`, sockets, timers, futexes and more, all through the same queues, so one loop can drive storage and networking together.
- **Mirrors the C API.** Functions keep their C names and argument order (`io_uring_prep_read`, `io_uring_submit`, `io_uring_wait_cqe`, ...), so the liburing man pages and C examples carry over almost line for line.
- **Wide coverage.** All 92 `io_uring_prep_*` operations: files and directories, sockets, multishot accept and receive, zero-copy send, polling, timeouts, cancel, futex, `msg_ring`, `uring_cmd`, `epoll`, provided buffers, registered files and buffers, and `probe()` to ask the kernel what it supports.
- **Python errors.** A failed completion raises the matching `OSError` when you read `cqe.res`; something the running kernel lacks raises `UnsupportedError`.
- **Typed and documented.** It ships type stubs that pass `mypy --strict`, and every function has a docstring: see the [API reference](api/index.md).
- **One binary, no dependencies.** The extension is built on CPython's stable ABI: one wheel loads on Python 3.14, 3.14t, 3.15 and 3.15t (regular and free-threaded).
- **Fast where it counts.** One syscall can submit many requests, and file work no longer blocks the loop: with `epoll` a regular-file read either stalls the thread or goes to a thread pool, while `io_uring` queues it beside the socket work. It also reaches `epoll` from inside the ring (`io_uring_prep_epoll_wait`), so existing `epoll` code can move over step by step. On a socket-only keep-alive HTTP server it matches `select.epoll` and is about 3x faster than `asyncio` (see [Benchmarks](bench.md)); that test has no file I/O, the case `epoll` cannot help with.

## A first look

Read a file with one request:

```python
import os
from liburing import *

ring = Ring()
cqe = Cqe()  # a completion queue entry
io_uring_queue_init(8, ring)  # a ring with room for 8 requests
try:
    fd = os.open("/etc/hostname", os.O_RDONLY)
    buffer = bytearray(64)  # keep a reference until the read completes
    sqe = io_uring_get_sqe(ring)  # a submission queue entry
    io_uring_prep_read(sqe, fd, buffer)  # describe the request
    sqe.user_data = 1  # comes back in `cqe.user_data`
    io_uring_submit(ring)  # hand it to the kernel
    io_uring_wait_cqe(ring, cqe)  # wait for the result
    print(cqe[0].user_data, cqe[0].res, bytes(buffer[: cqe[0].res]))  # raises `OSError` if it failed
    io_uring_cqe_seen(ring, cqe[0])  # done with this entry
    os.close(fd)
finally:
    io_uring_queue_exit(ring)
```

[How it works](concepts.md) explains each step: the ring, entries, `user_data`, buffers, completions, errors and threads. More complete programs in the [examples](guide.md): open, write, read and close a file, copy a file with linked requests, a TCP echo server with multishot accept and receive and a buffer ring, messages between threads, and the four ways to fill the submission queue.

## Requires

- Linux 6.17+ (older kernels work for what they support; try the latest Linux for every `io_uring` feature)
- Python 3.14+ (regular or free-threaded: 3.14, 3.14t, 3.15, 3.15t, ...)
- pip: any for 3.14, 3.14t, 3.15, 3.15t; 26.2+ for 3.16t and later (`abi3t`)

```bash
python3 -m pip install liburing
```

See [Install](install.md) to build from source.

## Where next

- [Install](install.md): from PyPI, or build from GitHub; requirements.
- [How it works](concepts.md): the life of a request, buffers, completions, errors, threads.
- [Examples](guide.md): which operations the kernel supports, open / write / read / close, vectored I/O, a linked-request file copy, a multishot echo server, messages between threads, `Sqe`.
- [Coming from C liburing](from_c.md): what maps to what, side by side.
- [API reference](api/index.md): every function, class and constant, by topic.
- [Benchmarks](bench.md): HTTP server, Liburing vs `select.epoll`, asyncio and C.

## License

Free, Public Domain (CC0).
