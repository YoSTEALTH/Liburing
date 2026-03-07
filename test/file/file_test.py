import os
import pytest
import liburing


def test_files_read_write(tmp_dir, ring, cqe):
    write = b"hi... bye!"
    read = bytearray(10)
    fd = os.open(tmp_dir / "test_files_read_write.txt", liburing.O_RDWR | liburing.O_CREAT, 0o660)
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


def test_readv_writev(ring, cqe, tmp_dir):
    fd = os.open(tmp_dir / "test_readv_writev.txt", liburing.O_RDWR | liburing.O_CREAT, 0o660)
    try:
        # Write
        # -----
        buffer = [b"hi...", b" bye!"]
        iovec = liburing.Iovec(buffer)

        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_writev(sqe, fd, iovec)
        sqe.user_data = 0

        # submit  & wait
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)

        entry = cqe[0]
        liburing.trap_error(entry.res)
        assert entry.user_data == 0
        liburing.io_uring_cqe_seen(ring, entry)

        # Read
        # ----
        buffer = [bytearray(2), bytearray(8)]
        iovec = liburing.Iovec(buffer)

        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, iovec)
        sqe.user_data = 1

        # submit  & wait
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)

        entry = cqe[0]
        liburing.trap_error(entry.res)
        assert entry.user_data == 1
        liburing.io_uring_cqe_seen(ring, entry)

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
    _onwait_flag_empty_file(ring, cqe, path2, liburing.RWF_NOWAIT)
    _onwait_flag_empty_file(ring, cqe, path2, 0)  # no flag

    # one of the ways to tell if `RWF_NOWAIT` flag is working is to catch its error
    with pytest.raises(OSError):
        path = "/dev/shm/test_rwf_nowait_flag.txt"
        _onwait_flag(ring, cqe, path)


def _onwait_flag(ring, cqe, path):
    fd = os.open(path, liburing.O_RDWR | liburing.O_CREAT | liburing.O_NONBLOCK, 0o660)
    one = bytearray(6)
    two = bytearray(4)
    iovec = liburing.Iovec([one, two])
    try:
        # write
        # -----
        os.write(fd, b"hi... bye!")
        os.fsync(fd)

        # read
        # ----
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, iovec, 0, liburing.RWF_NOWAIT)
        sqe.user_data = 1

        assert liburing.io_uring_submit(ring) == 1

        while True:
            try:
                liburing.io_uring_peek_cqe(ring, cqe)
            except BlockingIOError:
                pass  # print("test_rwf_nowait_flag BlockingIOError", flush=True)
            else:
                entry = cqe[0]
                liburing.trap_error(entry.res)
                assert entry.res == 6 + 4
                assert entry.user_data == 1
                assert one == b"hi... "
                assert two == b"bye!"
                liburing.io_uring_cqe_seen(ring, entry)
                break
    finally:
        os.close(fd)
        os.unlink(path)


def _onwait_flag_empty_file(ring, cqe, path, flag):
    fd = os.open(path, liburing.O_RDWR | liburing.O_CREAT | liburing.O_NONBLOCK, 0o660)
    read = [bytearray(5)]
    iovec = liburing.Iovec(read)
    try:
        # read empty file
        # ---------------
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, iovec, 0, flag)
        sqe.user_data = 1

        assert liburing.io_uring_submit(ring) == 1
        liburing.io_uring_peek_cqe(ring, cqe)
        assert cqe[0].res == 0
        liburing.io_uring_cqe_seen(ring, cqe[0])
        assert read == [bytearray(b"\x00\x00\x00\x00\x00")]
    finally:
        os.close(fd)
        os.unlink(path)
