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
