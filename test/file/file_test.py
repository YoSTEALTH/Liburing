import os
import pytest
import liburing


def test_files_read_write(tmp_dir, ring, cqe):
    write = b"hi... bye!"
    read = bytearray(10)
    path = tmp_dir / "1.txt"
    fd = os.open(path, liburing.O_RDWR | liburing.O_CREAT, 0o660)
    try:
        # write
        sqe = liburing.io_uring_get_sqe(ring)  # get sqe (submission queue entry) to fill
        liburing.io_uring_prep_write(sqe, fd, write)
        sqe.user_data = 1

        # submit
        assert liburing.io_uring_submit(ring) == 1
        assert liburing.io_uring_wait_cqes(ring, cqe, 1) == 0

        # write completion check
        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 1
        liburing.io_uring_cqe_seen(ring, entry)

        # read
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_read(sqe, fd, read)
        sqe.user_data = 2

        # submit
        assert liburing.io_uring_submit(ring) == 1
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0

        # read completion check
        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 2
        liburing.io_uring_cq_advance(ring, 1)

        # check
        assert read == write
    finally:
        os.close(fd)

