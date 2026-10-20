import os
import tempfile
from liburing import (
    O_CREAT,
    O_RDWR,
    Ring,
    Cqe,
    Iovec,
    io_uring_get_sqe,
    io_uring_prep_open,
    io_uring_prep_writev,
    io_uring_prep_readv,
    io_uring_prep_close,
    io_uring_submit,
    io_uring_wait_cqe,
    io_uring_cqe_seen,
    io_uring_queue_init,
    io_uring_queue_exit,
)


def run(ring, cqe, prep, *args):
    sqe = io_uring_get_sqe(ring)
    prep(sqe, *args)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    result = entry.res  # raises if the request failed
    io_uring_cqe_seen(ring, entry)
    return result


def main():
    path = os.path.join(tempfile.mkdtemp(), "vector.txt")
    ring = Ring()
    cqe = Cqe()
    io_uring_queue_init(32, ring)
    try:
        fd = run(ring, cqe, io_uring_prep_open, path, O_CREAT | O_RDWR)

        # `Iovec` holds on to the buffers it is given: no separate variable needed to keep them alive.
        iov_write = Iovec([b"hello ", b"vector ", b"world"])
        print("written:", run(ring, cqe, io_uring_prep_writev, fd, iov_write, 0))

        iov_read = Iovec([bytearray(6), bytearray(7), bytearray(5)])
        print("read:", run(ring, cqe, io_uring_prep_readv, fd, iov_read, 0))
        print(iov_read.buffers)  # (bytearray(b'hello '), bytearray(b'vector '), bytearray(b'world'))
        print(bytes(iov_read[1]))  # b'vector '

        run(ring, cqe, io_uring_prep_close, fd)
    finally:
        io_uring_queue_exit(ring)
        os.remove(path)


if __name__ == "__main__":
    main()
