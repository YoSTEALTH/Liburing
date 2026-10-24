"""Open, write, read and close a file with io_uring."""

import os
import tempfile
from liburing import *


def submit_and_wait(ring, cqe):
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    result = entry.res  # raises the matching exception if the operation failed
    io_uring_cqe_seen(ring, entry)  # done with this entry
    return result


def main():
    path = os.path.join(tempfile.mkdtemp(), "example.txt")
    ring = Ring()
    cqe = Cqe()
    io_uring_queue_init(8, ring)
    try:
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_open(sqe, path, O_CREAT | O_RDWR)
        sqe.user_data = 1  # comes back in `cqe.user_data`, to tell entries apart
        fd = submit_and_wait(ring, cqe)

        data = b"Hello, io_uring!"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, data)
        assert submit_and_wait(ring, cqe) == len(data)

        buffer = bytearray(len(data))  # keep a reference until the read completes
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, buffer)
        submit_and_wait(ring, cqe)
        print(buffer.decode())

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        submit_and_wait(ring, cqe)
    finally:
        io_uring_queue_exit(ring)
        os.unlink(path)
        os.rmdir(os.path.dirname(path))


if __name__ == "__main__":
    main()
