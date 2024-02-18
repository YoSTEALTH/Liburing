import os
import pytest
from liburing import O_RDWR, O_CREAT, O_NONBLOCK, \
                     io_uring, io_uring_cqe, iovec, io_uring_queue_init, io_uring_get_sqe, \
                     io_uring_prep_write, io_uring_prep_writev, io_uring_submit, \
                     io_uring_wait_cqes, io_uring_cqe_seen, io_uring_prep_readv, \
                     io_uring_prep_readv2, io_uring_queue_exit, io_uring_wait_cqe, \
                     io_uring_cq_advance, io_uring_prep_read, io_uring_peek_cqe, trap_error, \
                     io_uring_register_files, io_uring_unregister_files


def test_file_registration(tmp_dir):
    ring = io_uring()
    assert io_uring_queue_init(1, ring, 0) == 0
    fds = []
    fds.append(os.open(tmp_dir / '1.txt', O_CREAT))
    fds.append(os.open(tmp_dir / '2.txt', O_CREAT))
    try:
        assert io_uring_register_files(ring, fds) == 0
        assert io_uring_unregister_files(ring) == 0
    finally:
        for fd in fds:
            os.close(fd)
        io_uring_queue_exit(ring)


def test_files_write_read_mix(tmp_dir):
    path = tmp_dir / '1.txt'
    fd = os.open(path, O_RDWR | O_CREAT, 0o660)
    ring = io_uring()
    cqe = io_uring_cqe()

    # prepare for writing two separate writes and reads.
    one = bytearray(b'hello')
    two = bytearray(b'world')
    vec_one = iovec(one)
    vec_two = iovec(two)

    try:
        # initialization
        assert io_uring_queue_init(2, ring, 0) == 0

        # write "hello"
        sqe = io_uring_get_sqe(ring)  # get sqe (submission queue entry) to fill
        io_uring_prep_write(sqe, fd, vec_one[0].iov_base, vec_one[0].iov_len, 0)
        sqe.user_data = 1

        # write "world"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_writev(sqe, fd, vec_two, len(vec_two), 5)
        sqe.user_data = 2

        # submit both writes
        assert io_uring_submit(ring) == 2

        # wait for ``2`` entry to complete using single syscall
        assert io_uring_wait_cqes(ring, cqe, 2) == 0
        assert cqe.res == 5
        assert cqe.user_data == 1
        io_uring_cqe_seen(ring, cqe)

        # re-uses the same resources from above?!
        assert io_uring_wait_cqes(ring, cqe, 1) == 0
        assert cqe.res == 5
        assert cqe.user_data == 2
        io_uring_cqe_seen(ring, cqe)

        # Using same ``vec*`` swap so read can be confirmed.

        # read "world"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv(sqe, fd, vec_one, 5)
        sqe.user_data = 3

        assert io_uring_submit(ring) == 1
        assert io_uring_wait_cqe(ring, cqe) == 0
        assert cqe.res == 5
        assert cqe.user_data == 3
        io_uring_cq_advance(ring, 1)

        # read "hello"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, vec_two[0].iov_base, vec_two[0].iov_len, 0)
        sqe.user_data = 4

        assert io_uring_submit(ring) == 1
        assert io_uring_wait_cqe(ring, cqe) == 0
        assert cqe.res == 5
        assert cqe.user_data == 4
        io_uring_cq_advance(ring, 1)

        # use same as write buffer to read but switch values so the change is detected
        assert one == b'world'
        assert two == b'hello'
    finally:
        os.close(fd)
        io_uring_queue_exit(ring)


def test_rwf_nowait_flag():
    path1 = './test_rwf_nowait_flag.txt'
    path2 = './test_rwf_nowait_flag_empty_file.txt'
    # note: `RWF_NOWAIT` will raise `OSError: [Errno 95] Operation not supported`
    #       if the file is not in disk or file is located in ram this includes `/tmp`
    _onwait_flag(path1)
    _onwait_flag_empty_file(path2, os.RWF_NOWAIT)
    _onwait_flag_empty_file(path2, 0)  # no flag

    # one of the ways to tell if `RWF_NOWAIT` flag is working is to catch its error
    with pytest.raises(OSError):
        path = '/dev/shm/test_rwf_nowait_flag.txt'
        _onwait_flag(path)


def _onwait_flag(path):
    fd = os.open(path, O_RDWR | O_CREAT | O_NONBLOCK, 0o660)
    one = bytearray(6)
    two = bytearray(5)
    vec = iovec([one, two])

    ring = io_uring()
    cqe = io_uring_cqe()
    try:
        # WRITE
        # -----
        os.write(fd, b'hello world')
        os.fsync(fd)

        assert io_uring_queue_init(2, ring, 0) == 0

        # READ
        # ----
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv2(sqe, fd, vec, 0, os.RWF_NOWAIT)
        sqe.user_data = 1

        assert io_uring_submit(ring) == 1

        while True:
            try:
                io_uring_peek_cqe(ring, cqe)
            except BlockingIOError:
                pass  # print('test_rwf_nowait_flag BlockingIOError', flush=True)
            else:
                trap_error(cqe.res)
                assert cqe.res == 6 + 5
                assert cqe.user_data == 1
                assert one == b'hello '
                assert two == b'world'
                io_uring_cqe_seen(ring, cqe)
                break
    finally:
        io_uring_queue_exit(ring)
        os.close(fd)
        os.unlink(path)


def _onwait_flag_empty_file(path, flag):
    fd = os.open(path, O_RDWR | O_CREAT | O_NONBLOCK, 0o660)
    read = bytearray(5)
    iov = iovec(read)
    ring = io_uring()
    cqe = io_uring_cqe()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        # READ empty file
        # ---------------
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv2(sqe, fd, iov, 0, flag)
        sqe.user_data = 1

        assert io_uring_submit(ring) == 1
        io_uring_peek_cqe(ring, cqe)
        assert cqe.res == 0
        io_uring_cqe_seen(ring, cqe)
        assert iov.iov_base == bytearray(b'\x00\x00\x00\x00\x00')
        assert read == bytearray(b'\x00\x00\x00\x00\x00')
    finally:
        io_uring_queue_exit(ring)
        os.close(fd)
        os.unlink(path)
