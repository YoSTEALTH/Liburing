import os
import tempfile
from liburing import *


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

        # a list of buffers: the request holds them (locked) until its completion
        print("written:", run(ring, cqe, io_uring_prep_writev, fd, [b"hello ", b"vector ", b"world"], 0))

        bufs = [bytearray(6), bytearray(7), bytearray(5)]
        print("read:", run(ring, cqe, io_uring_prep_readv, fd, bufs, 0))
        print(bufs)  # [bytearray(b'hello '), bytearray(b'vector '), bytearray(b'world')]
        print(bytes(bufs[1]))  # b'vector '

        run(ring, cqe, io_uring_prep_close, fd)
    finally:
        io_uring_queue_exit(ring)
        os.remove(path)


if __name__ == "__main__":
    main()
