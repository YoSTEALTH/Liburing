# How it works

What you need to know to use Liburing: the three objects, the life of a request, buffers, completions, errors and threads. Every function named here is in the [API reference](api/index.md) with its docstring.

## Three objects

| Object | What it is | C liburing |
|:--|:--|:--|
| `Ring` | An `io_uring` instance: its submission queue, completion queue and file descriptor. Empty until `io_uring_queue_init`. | `struct io_uring` |
| `SQE` | A submission queue entry, the request you describe. `io_uring_get_sqe(ring)` gives one that points into the ring; `Sqe()` makes one of your own (see [Four ways to fill the submission queue](guide.md#four-ways-to-fill-the-submission-queue)). | `struct io_uring_sqe *` |
| `Cqe` | Your view of the completion queue. A wait or peek sets it to the oldest ready completion, `cqe[0]`; the ones behind it are `cqe[1]`, `cqe[2]`, ... Each `cqe[i]` is a `CQE` with `user_data`, `res` and `flags`. | `struct io_uring_cqe *` |

Make one `Ring` and one `Cqe` per thread and keep them for the thread's lifetime.

## The life of a request

```python
import os
from liburing import *

ring = Ring()
cqe = Cqe()
io_uring_queue_init(8, ring)  # 1. a ring with room for 8 requests
try:
    fd = os.open("/etc/hostname", os.O_RDONLY)
    buffer = bytearray(64)
    sqe = io_uring_get_sqe(ring)  # 2. take an entry
    io_uring_prep_read(sqe, fd, buffer)  # 3. describe the request
    sqe.user_data = 1  # 4. tag it
    io_uring_submit(ring)  # 5. hand everything queued to the kernel
    io_uring_wait_cqe(ring, cqe)  # 6. wait for a completion
    print(cqe[0].user_data, cqe[0].res, bytes(buffer[: cqe[0].res]))  # 7. read it
    io_uring_cqe_seen(ring, cqe[0])  # 8. give the slot back
    os.close(fd)
finally:
    io_uring_queue_exit(ring)  # 9. tear down
```

1. **Set up.** `io_uring_queue_init(entries, ring, flags)` creates the queues. `entries` is how many requests can wait in the submission queue at once (the completion queue gets twice that); `flags` are `IORING_SETUP_*`. A ring that is set up again, or used before setup or after exit, raises `RuntimeError`.
2. **Take an entry.** `io_uring_get_sqe(ring)` returns the next free entry, or `None` when the queue is full: submit, then take again. `Ring(auto_submit=True)` does that for you (see below).
3. **Prepare.** One `io_uring_prep_*` call per operation, with the same arguments as the C function minus the pointer-and-length pairs: a buffer is one Python object, a path a `str`, a time a `Timespec`. The prep returns `True` (`False` only on a full `Sqe(ring)`). Flags that modify the request go on the entry afterwards: `sqe.flags = IOSQE_IO_LINK`, `io_uring_sqe_set_buf_group(sqe, bgid)`, ...
4. **Tag.** `sqe.user_data` is any 64-bit integer; it comes back unchanged in `cqe.user_data`, which is how you tell completions apart. It may be `0` and it may repeat. The ring keeps the value in a table of in-flight requests and gives the kernel the table index, so the kernel never sees your value (an `SQE` read after the submit shows the index).
5. **Submit.** `io_uring_submit(ring)` is one syscall for every entry taken since the last submit and returns how many it sent. `io_uring_submit_and_wait(ring, n)` submits and waits for `n` completions in the same syscall.
6. **Wait.** `io_uring_wait_cqe(ring, cqe)` blocks until one completion is ready; `io_uring_wait_cqes(ring, cqe, n, ts)` waits for `n` with an optional timeout (`OSError` with `errno.ETIME` when it runs out); `io_uring_peek_cqe(ring, cqe)` does not block (`BlockingIOError` when nothing is ready). Every wait releases the GIL, so other Python threads run meanwhile.
7. **Read.** `cqe[0].res` is the operation's result: bytes read or written, the new file descriptor of an open or accept, `0` for a close. A negative result is an error and reading `res` raises the matching `OSError` subclass (`FileNotFoundError`, `ConnectionResetError`, ...) instead. `cqe[0].flags` are `IORING_CQE_F_*`: `IORING_CQE_F_MORE` says a multishot request is still armed, `IORING_CQE_F_BUFFER` that the kernel chose a provided buffer (its id is `flags >> IORING_CQE_BUFFER_SHIFT`).
8. **Consume.** `io_uring_cqe_seen(ring, cqe[0])` frees that slot; `io_uring_cq_advance(ring, n)` frees the first `n`. Until then `cqe[i]` is valid and the request's buffers are held; afterwards neither is.
9. **Tear down.** `io_uring_queue_exit(ring)` cancels and waits for anything still in flight, releases what the requests held, unmaps the queues and closes the ring's file descriptor. A `with`-less `try` / `finally` is the usual shape; the ring's garbage collection also exits it.

## Buffers

A request that reads or writes memory takes the buffer object itself, not an address and a length:

- **Reads** need a writable buffer: `bytearray`, `memoryview`, `mmap`, an `array`, a NumPy array, ... `bytes` is refused with `TypeError`. The whole buffer is the request's length; slice a `memoryview` for part of it.
- **Writes and sends** take any bytes-like object, `bytes` included.
- **Vectored** operations (`io_uring_prep_readv`, `io_uring_prep_writev`) take a list of buffers; the message operations (`io_uring_prep_sendmsg`, `io_uring_prep_recvmsg`) take a `Msghdr` built from one.

The request **holds** the buffer from the prep until its completion is consumed: the object stays alive even if you drop your reference, and a `bytearray` is locked against resizing. You never have to keep buffers alive yourself. The hold also means a buffer handed to a request that is never submitted stays locked until the ring exits.

Registered buffers (`io_uring_register_buffers`) and the buffers of a provided buffer ring (`io_uring_buf_ring_add`) are held by the ring until they are unregistered, replaced or the ring exits.

## Reading completions in batches

Waiting for one completion at a time is simple but slow. A loop that handles many requests submits them together and reads every completion that is ready:

```python
io_uring_submit_and_wait(ring, 1)  # submit what is queued, wait for at least one completion
io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest one
ready = io_uring_cq_ready(ring)  # how many are ready
for i in range(ready):
    entry = cqe[i]
    handle(entry.user_data, entry.res, entry.flags)
io_uring_cq_advance(ring, ready)  # done with all of them
```

`cqe.user_data_at(i)` and `cqe.res_at(i)` read the two fields without creating a `CQE` object, which matters in a hot loop. `CqeBatch` + `io_uring_peek_batch_cqe` and `CqeIter` are the other two shapes; the [echo server](guide.md#tcp-echo-server-multishot-accept-and-receive-a-buffer-ring) shows the loop above in full.

## When the submission queue is full

The queue holds `entries` requests between submits. When it is full, `io_uring_get_sqe` returns `None`, a prep on `Sqe(ring)` returns `False` and `put_sqe` returns `False`: call `io_uring_submit` and try again. With `Ring(auto_submit=True)` the ring submits by itself in that case and the call succeeds, except when the last queued request links on to the next one (`IOSQE_IO_LINK` / `IOSQE_IO_HARDLINK`): a submit there would end the chain, so you get the full-queue answer and decide.

## Linking, draining, skipping

`sqe.flags` takes the `IOSQE_*` flags:

- `IOSQE_IO_LINK`: the next entry starts only when this one has finished successfully; a failure cancels the rest of the chain (`ECANCELED`). The [file copy](guide.md#copy-a-file-with-linked-requests) links each read to its write. `IOSQE_IO_HARDLINK` keeps the chain going on failure.
- `IOSQE_IO_DRAIN`: wait for every earlier request to complete first.
- `IOSQE_ASYNC`: always go through the kernel's worker threads instead of trying inline first.
- `IOSQE_BUFFER_SELECT`: the kernel picks the buffer from the group set with `io_uring_sqe_set_buf_group`.
- `IOSQE_CQE_SKIP_SUCCESS`: no completion on success. Allowed inside a link chain; on the last request of a chain, or alone with a buffer or path to release, the submit raises `ValueError`.
- `IOSQE_FIXED_FILE`: `fd` is an index into the registered files (`io_uring_register_files`), not a descriptor.

`io_uring_prep_link_timeout(sqe, ts, flags)` right after a linked request limits how long it may take.

## Errors

| Raised | When |
|:--|:--|
| `OSError` and its subclasses | Reading a negative `cqe.res`; a setup or register call the kernel refuses; a wait whose timeout ran out (`errno.ETIME`); a peek with nothing ready (`BlockingIOError`). |
| `UnsupportedError` (an `OSError`) | The running kernel lacks the feature: a setup flag, a register call, a wait variant. An operation the kernel lacks does not raise at the prep; its completion fails with `EINVAL` or `EOPNOTSUPP`. Ask first with `probe()` (a `dict` of every `IORING_OP_*` name and whether it is supported) or `io_uring_opcode_supported`. |
| `RuntimeError` | A ring used before setup or after exit, or from a thread other than the one that set it up; an `SQE` of a ring that has exited. |
| `ValueError`, `TypeError`, `OverflowError` | Bad arguments, checked before anything reaches the kernel: a read into `bytes`, a `len` larger than its buffer, a negative time, a value that does not fit the field. |

Kernel versions differ in what they support. The docstrings say which Linux version an operation or flag needs; [Install](install.md) says what Liburing is tested on.

## Threads

A `Ring` belongs to the thread that called `io_uring_queue_init` on it; so does every `SQE` taken from it. A `Cqe` belongs to the thread of its first wait or peek, an `Sqe` template to the thread of its first prep or `put_sqe`. Using any of them from another thread raises `RuntimeError`. The rule is one ring, one `Cqe` and (if you use them) one `Sqe` per thread.

Threads talk to each other's rings in two ways:

- `io_uring_prep_msg_ring(sqe, other.ring_fd, len, data)` posts a completion on another ring, with `data` as its `user_data` and `len` as its `res`. `data` must be below `2**63`.
- A `Futex` shared between the threads, with `io_uring_prep_futex_wait` on the receiving ring and `io_uring_prep_futex_wake` on the sending one, carries any Python object through a queue next to it: see [Messages between threads](guide.md#messages-between-threads-through-a-futex).

The waits release the GIL, so a thread blocked in `io_uring_wait_cqe` costs the others nothing. On the free-threaded builds (3.14t, 3.15t) the same per-thread rule applies and nothing else changes.

## Timeouts and time

Times are `Timespec` objects; `timespec(1.5)` makes one from seconds. They go to `io_uring_prep_timeout` (a request that completes after a time or after `count` other completions), `io_uring_prep_link_timeout`, and the waits with a time limit (`io_uring_wait_cqe_timeout`, `io_uring_wait_cqes`, `io_uring_submit_and_wait_timeout`). The time flags are `IORING_TIMEOUT_*` (`IORING_TIMEOUT_ABS`, `IORING_TIMEOUT_MULTISHOT`, ...).
