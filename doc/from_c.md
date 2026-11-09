# Coming from C liburing

Liburing keeps C liburing's names and argument order, so the [liburing man pages](https://unixism.net/loti/ref-liburing/index.html) and C examples carry over almost line for line. This page lists what changes: pointers become objects, buffers lose their lengths, errors become exceptions.

## Side by side

The heart of C liburing's `examples/link-cp.c`, a read linked to a write, and the same in Liburing's [file copy](guide.md#copy-a-file-with-linked-requests) (which uses the single-buffer `read` / `write` instead of a one-element `iovec`):

```c
struct io_uring ring;
struct io_uring_sqe *sqe;
struct io_uring_cqe *cqe;
io_uring_queue_init(QD, &ring, 0);

sqe = io_uring_get_sqe(&ring);
io_uring_prep_readv(sqe, infd, &data->iov, 1, offset);
sqe->flags |= IOSQE_IO_LINK;
io_uring_sqe_set_data(sqe, data);
sqe = io_uring_get_sqe(&ring);
io_uring_prep_writev(sqe, outfd, &data->iov, 1, offset);
io_uring_sqe_set_data(sqe, data);
io_uring_submit(&ring);

io_uring_wait_cqe(&ring, &cqe);
if (cqe->res < 0) { /* -cqe->res is the errno */ }
data = io_uring_cqe_get_data(cqe);
io_uring_cqe_seen(&ring, cqe);
io_uring_queue_exit(&ring);
```

```python
ring = Ring()
cqe = Cqe()
io_uring_queue_init(QD, ring)

buffer = bytearray(size)
sqe = io_uring_get_sqe(ring)
io_uring_prep_read(sqe, infd, buffer, offset)
sqe.flags = IOSQE_IO_LINK
sqe.user_data = offset << 1 | READ
sqe = io_uring_get_sqe(ring)
io_uring_prep_write(sqe, outfd, buffer, offset)
sqe.user_data = offset << 1 | WRITE
io_uring_submit(ring)

io_uring_wait_cqe(ring, cqe)
result = cqe[0].res  # raises the matching `OSError` for a negative `res`
data = cqe[0].user_data
io_uring_cqe_seen(ring, cqe[0])
io_uring_queue_exit(ring)
```

## What maps to what

| C liburing | Liburing | Notes |
|:--|:--|:--|
| `struct io_uring ring;` | `ring = Ring()` | Pass `ring` where C passes `&ring`. |
| `struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);` | `sqe = io_uring_get_sqe(ring)` | `None` instead of `NULL` when the queue is full. |
| `struct io_uring_cqe *cqe; io_uring_wait_cqe(&ring, &cqe);` | `cqe = Cqe()` once, then `io_uring_wait_cqe(ring, cqe)` | `cqe[0]` is the entry C's pointer points at; `cqe[1]`, `cqe[2]`, ... the ones behind it. |
| `cqe->res`, `cqe->user_data`, `cqe->flags` | `cqe[0].res`, `cqe[0].user_data`, `cqe[0].flags` | A negative `res` raises the matching `OSError` instead of being returned. |
| `sqe->user_data = x` / `io_uring_sqe_set_data64(sqe, x)` | `sqe.user_data = x` | Any 64-bit integer, `0` included. `io_uring_cqe_get_data64` and `cqe.user_data_res(i)` read it. |
| `io_uring_sqe_set_data(sqe, ptr)` + `io_uring_cqe_get_data(cqe)` | the same, with any object | The request keeps the object alive until its completion is consumed; `user_data` is its address (`id(obj)`), and `io_uring_prep_cancel(sqe, obj)` cancels by it. `cqe.data_res(i)` reads the object and `res` in one call. |
| `sqe->flags \|= IOSQE_IO_LINK` | `sqe.flags = IOSQE_IO_LINK` or `io_uring_sqe_set_flags(sqe, ...)` | Set it after the prep, as in C. |
| `buf, len` pairs (`io_uring_prep_read(sqe, fd, buf, len, offset)`) | one buffer object (`io_uring_prep_read(sqe, fd, buf, offset)`) | The object's length is the request's length; slice a `memoryview` for less. Reads need a writable buffer. |
| `struct iovec iov[n]` + `io_uring_prep_readv(sqe, fd, iov, n, offset)` | `io_uring_prep_readv(sqe, fd, [buf1, buf2], offset)` | A list of buffers. |
| `struct __kernel_timespec ts = {1, 500000000}` | `timespec(1.5)` | A `Timespec`; its `sec` and `nsec` are settable. |
| `struct sockaddr_in` + `sizeof` | `Sockaddr(AF_INET, "127.0.0.1", 8000)` | `Sockaddr()` is an empty one for `io_uring_prep_accept` to fill. |
| `struct msghdr`, `struct statx`, `struct open_how`, `struct epoll_event` | `Msghdr`, `Statx`, `OpenHow`, `EpollEvent` | The struct's fields are properties. |
| `int fds[n]` + `io_uring_register_files(&ring, fds, n)` | `io_uring_register_files(ring, FileIndex([fd1, fd2]))` | |
| `struct io_uring_buf_ring *br = io_uring_setup_buf_ring(&ring, n, bgid, 0, &err)` | `br = io_uring_setup_buf_ring(ring, n, bgid, 0)` | `OSError` instead of `err`. |
| `io_uring_for_each_cqe(&ring, head, cqe) { ... } io_uring_cq_advance(&ring, n)` | `for i in range(io_uring_cq_ready(ring)): cqe[i]`, then `io_uring_cq_advance(ring, n)` | After a wait or peek. `CqeIter` and `CqeBatch` + `io_uring_peek_batch_cqe` are the other two forms. |
| `ret < 0` from setup, register and wait calls | `OSError` (`UnsupportedError` for a missing kernel feature) | The successful return value is returned as in C (`0`, a count, an fd). |
| `io_uring_get_probe()` + `io_uring_opcode_supported(p, op)` | the same, or `probe()` | `probe()` gives a `dict` of every `IORING_OP_*` name and whether the kernel supports it. |
| `io_uring_queue_exit(&ring)` | `io_uring_queue_exit(ring)` | Cancels and waits for what is still in flight first. A collected `Ring` exits itself. |

## What has no C counterpart

- **Buffers are held for you.** From the prep to the consumed completion the request keeps its buffer, path and address objects alive and a `bytearray` unresizable. There is nothing to free and no use-after-free to avoid.
- **`user_data` is yours alone.** The ring keeps your value in a table of in-flight requests and gives the kernel the index, so there is no pointer to cast and no collision with values the kernel or liburing use (timeouts, messages).
- **`Sqe()` templates and `Sqe(ring)`.** A prepared entry you copy into the ring with `put_sqe` as often as you like, a block of them, or one object whose every prep takes the ring's next free slot: [four ways to fill the submission queue](guide.md#four-ways-to-fill-the-submission-queue).
- **`Ring(auto_submit=True)`.** Taking an entry from a full queue submits first instead of failing.
- **Thread ownership is checked.** Using a ring from a thread other than the one that set it up raises `RuntimeError` instead of corrupting the queue. The waits release the GIL.

## What is missing

- `io_uring_register_wait_reg` always fails: C liburing dropped it (use `io_uring_register_region` with a `RegWait`).
- `io_uring_for_each_cqe`, a C macro that walks the ring's memory directly, has the function and loop forms above instead.
