import os
import pytest
from liburing import *


def test_files_read_write(tmp_dir, ring, cqe):
    write = b"hi... bye!"
    read = bytearray(10)
    fd = os.open(tmp_dir / "test_files_read_write.txt", O_RDWR | O_CREAT, 0o660)
    try:
        # write
        sqe = io_uring_get_sqe(ring)  # get sqe (submission queue entry) to fill
        io_uring_prep_write(sqe, fd, write)
        sqe.user_data = 1

        # submit
        assert io_uring_submit(ring) == 1
        assert io_uring_wait_cqes(ring, cqe, 1) == 0

        # write completion check
        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 1
        io_uring_cqe_seen(ring, entry)

        # read
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, read)
        sqe.user_data = 2

        # submit
        assert io_uring_submit(ring) == 1
        assert io_uring_wait_cqe(ring, cqe) == 0

        # read completion check
        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 2
        io_uring_cq_advance(ring, 1)

        # check
        assert read == write
    finally:
        os.close(fd)


def test_readv_writev(ring, cqe, tmp_dir):
    fd = os.open(tmp_dir / "test_readv_writev.txt", O_RDWR | O_CREAT, 0o660)
    try:
        # Write
        # -----
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_writev(sqe, fd, [b"hi...", b" bye!"])
        sqe.user_data = 0

        # submit  & wait
        io_uring_submit(ring)
        io_uring_wait_cqe(ring, cqe)

        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 0
        io_uring_cqe_seen(ring, entry)

        # Read
        # ----
        buffer = [bytearray(2), bytearray(8)]
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv(sqe, fd, buffer)
        sqe.user_data = 1

        # submit  & wait
        io_uring_submit(ring)
        io_uring_wait_cqe(ring, cqe)

        entry = cqe[0]
        assert entry.res == 10
        assert entry.user_data == 1
        io_uring_cqe_seen(ring, entry)

        # switch position and check.
        assert buffer == [b"hi", b"... bye!"]

    finally:
        os.close(fd)


def test_rwf_nowait_flag(ring, cqe, tmp_dir):
    # note: file needs to be local as files in memory can't use `RWF_NOWAIT`
    path1 = "./test_rwf_nowait_flag.txt"
    path2 = "./test_rwf_nowait_flag_empty_file.txt"
    # note: `RWF_NOWAIT` will raise `OSError: [Errno 95] Operation not supported`
    #       if the file is not in disk or file is located in ram this includes `/tmp`
    _onwait_flag(ring, cqe, path1)
    _onwait_flag_empty_file(ring, cqe, path2, RWF_NOWAIT)
    _onwait_flag_empty_file(ring, cqe, path2, 0)  # no flag

    # one of the ways to tell if `RWF_NOWAIT` flag is working is to catch its error
    with pytest.raises(OSError):
        path = "/dev/shm/test_rwf_nowait_flag.txt"
        _onwait_flag(ring, cqe, path)


def _onwait_flag(ring, cqe, path):
    fd = os.open(path, O_RDWR | O_CREAT | O_NONBLOCK, 0o660)
    one = bytearray(6)
    two = bytearray(4)
    iovec = [one, two]
    try:
        # write
        # -----
        os.write(fd, b"hi... bye!")
        os.fsync(fd)

        # read
        # ----
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv(sqe, fd, iovec, 0, RWF_NOWAIT)
        sqe.user_data = 1

        assert io_uring_submit(ring) == 1

        while True:
            try:
                io_uring_peek_cqe(ring, cqe)
            except BlockingIOError:
                pass  # print("test_rwf_nowait_flag BlockingIOError", flush=True)
            else:
                entry = cqe[0]
                assert entry.res == 10
                assert entry.res == 6 + 4
                assert entry.user_data == 1
                assert one == b"hi... "
                assert two == b"bye!"
                io_uring_cqe_seen(ring, entry)
                break
    finally:
        os.close(fd)
        os.unlink(path)


def _onwait_flag_empty_file(ring, cqe, path, flag):
    fd = os.open(path, O_RDWR | O_CREAT | O_NONBLOCK, 0o660)
    read = [bytearray(5)]
    iovec = read
    try:
        # read empty file
        # ---------------
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv(sqe, fd, iovec, 0, flag)
        sqe.user_data = 1

        assert io_uring_submit(ring) == 1
        io_uring_peek_cqe(ring, cqe)
        assert cqe[0].res == 0
        io_uring_cqe_seen(ring, cqe[0])
        assert read == [bytearray(b"\x00\x00\x00\x00\x00")]
    finally:
        os.close(fd)
        os.unlink(path)


def test_readv_writev_inline_iovec(ring, cqe, tmp_dir):
    # the request holds the buffers itself: no separate variable for them
    fd = os.open(tmp_dir / "iovec_inline.txt", O_RDWR | O_CREAT, 0o660)
    try:
        for prep, iov in (
            (io_uring_prep_writev, [b"hi... ", b"bye!"]),
            (io_uring_prep_readv, [bytearray(6), bytearray(4)]),
        ):
            sqe = io_uring_get_sqe(ring)
            prep(sqe, fd, iov, 0)
            io_uring_submit(ring)
            io_uring_wait_cqe(ring, cqe)
            entry = cqe[0]
            assert entry.res == 10
            io_uring_cqe_seen(ring, entry)
        assert iov == [b"hi... ", b"bye!"]
    finally:
        os.close(fd)
