# Examples

Complete programs, included straight from the `example/` directory: the test suite runs every one of them, so the code below always matches what works. [How it works](concepts.md) explains the pieces they are made of.

## Which operations does the kernel support?

`probe()` asks the kernel which `IORING_OP_*` operations it has. Everything else in Liburing is available on every kernel; an operation the kernel lacks fails in its completion.

@@example/probe.py@@

## Open, write, read, close

The basic pattern: get a submission queue entry, prepare the request on it, submit, wait for the completion, read its result. Here one request at a time, with every step (the open and close included) a request on the ring.

@@example/open_write_read_close.py@@

## Vectored read and write

`io_uring_prep_writev` and `io_uring_prep_readv` take a list of buffers and move them in one request (`pwritev2` / `preadv2`). The request holds every buffer until its completion.

@@example/readv_writev.py@@

## Copy a file with linked requests

C liburing's `examples/link-cp.c`. Each chunk is two requests in the ring at once: a read, and a write of the same buffer that the kernel starts only when the read is done (`IOSQE_IO_LINK`). With 64 pairs in flight, one submit hands the kernel up to 128 requests, and no data passes through Python. The file size (`io_uring_prep_statx`), the opens and the closes go through the ring too.

```bash
python3 example/copy_file.py <source> <destination>
```

@@example/copy_file.py@@

## TCP echo server: multishot accept and receive, a buffer ring

C liburing's `examples/echo-server.c`, the modern `io_uring` networking pattern. One `io_uring_prep_multishot_accept` stays armed for every new connection, one `io_uring_prep_recv_multishot` per connection stays armed for every chunk of data, and the kernel picks the receive buffer from a shared pool (a buffer ring, `io_uring_setup_buf_ring`), which gets it back once the echo has been sent. `Sqe(ring)` preps straight into the ring's next free entry and `Ring(auto_submit=True)` submits by itself when the queue is full, so a busy loop creates no object per request.

```bash
python3 example/echo_server.py 8000
nc localhost 8000
```

@@example/echo_server.py@@

## Messages between threads, through a futex

Each thread has its own ring (a ring belongs to the thread that set it up). The receiver arms an `io_uring_prep_futex_wait` on its ring and the sender, after putting a message in a shared `deque`, wakes it with `io_uring_prep_futex_wake` from its own. Any Python object travels this way; `io_uring_prep_msg_ring` is the alternative when a 64-bit value is enough.

@@example/futex_messages.py@@

## Four ways to fill the submission queue

- `io_uring_get_sqe(ring)`: the C way. It hands back a new `SQE` for every request (`None` when the queue is full), which you prepare and give a `user_data`.
- `Sqe()`: prepare one entry once, then `put_sqe(ring, sqe)` copies it into the ring every time you need it. One call per request, nothing re-prepared.
- `Sqe(ring)`: one object for the ring's lifetime. Each prep takes the ring's next free entry: no `io_uring_get_sqe`, no `put_sqe`, no object per request.
- `Sqe(123)`: a block of 123 entries (`sqe[0]` ... `sqe[122]`), prepared in a loop and put into the ring with a single `put_sqe`: a whole batch per call.

The [benchmark](bench.md) measures the first three on an HTTP server.

@@example/sqe_styles.py@@
