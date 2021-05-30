import os
import errno
import pytest
import liburing


def test_file_registration(tmpdir):
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    fd1 = os.open(os.path.join(tmpdir, '1.txt'), os.O_CREAT)
    fd2 = os.open(os.path.join(tmpdir, '2.txt'), os.O_CREAT)
    try:
        fds = liburing.files(fd1, fd2)
        assert liburing.io_uring_register_files(ring, fds, len(fds)) == 0
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        os.close(fd1)
        os.close(fd2)
        liburing.io_uring_queue_exit(ring)


def test_files_write_read(tmpdir):
    fd = os.open(os.path.join(tmpdir, '1.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    ring = liburing.io_uring()
    cqes = liburing.io_uring_cqes(2)

    # prepare for writing two separate writes and reads.
    one = bytearray(b'hello')
    two = bytearray(b'world')
    vec_one = liburing.iovec(one)
    vec_two = liburing.iovec(two)

    try:
        # initialization
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        # write "hello"
        sqe = liburing.io_uring_get_sqe(ring)  # get sqe (submission queue entry) to fill
        liburing.io_uring_prep_write(sqe, fd, vec_one[0].iov_base, vec_one[0].iov_len, 0)
        sqe.user_data = 1

        # write "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_writev(sqe, fd, vec_two, len(vec_two), 5)
        sqe.user_data = 2

        # submit both writes
        assert liburing.io_uring_submit(ring) == 2

        # wait for ``2`` entry to complete using single syscall
        assert liburing.io_uring_wait_cqes(ring, cqes, 2) == 0
        cqe = cqes[0]
        assert cqe.res == 5
        assert cqe.user_data == 1
        liburing.io_uring_cqe_seen(ring, cqe)

        # re-uses the same resources from above?!
        assert liburing.io_uring_wait_cqes(ring, cqes, 2) == 0
        cqe = cqes[0]
        assert cqe.res == 5
        assert cqe.user_data == 2
        liburing.io_uring_cqe_seen(ring, cqe)

        # Using same ``vec*`` swap so read can be confirmed.

        # read "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec_one, len(vec_one), 5)
        sqe.user_data = 3

        assert liburing.io_uring_submit(ring) == 1
        assert liburing.io_uring_wait_cqe(ring, cqes) == 0
        cqe = cqes[0]
        assert cqe.res == 5
        assert cqe.user_data == 3
        liburing.io_uring_cq_advance(ring, 1)

        # read "hello"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_read(sqe, fd, vec_two[0].iov_base, vec_two[0].iov_len, 0)
        sqe.user_data = 4

        assert liburing.io_uring_submit(ring) == 1
        assert liburing.io_uring_wait_cqe(ring, cqes) == 0
        cqe = cqes[0]
        assert cqe.res == 5
        assert cqe.user_data == 4
        liburing.io_uring_cq_advance(ring, 1)

        # use same as write buffer to read but switch values so the change is detected
        assert one == b'world'
        assert two == b'hello'
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)


def test_rwf_nowait_flag():
    path = './test_rwf_nowait_flag.txt'
    path = './test_rwf_nowait_flag_empty_file.txt'
    # note
    #   - `RWF_NOWAIT` will raise ``OSError: [Errno 95] Operation not supported`` if the file is not on disk!
    #   - ram is not supported.
    #   - `tmpdir` can be linked to ram thus using local file path
    onwait_flag(path)
    # note
    #   - `RWF_NOWAIT` will return `-11` if file reading is empty
    onwait_flag_empty_file(path, os.RWF_NOWAIT)
    # onwait_flag_empty_file(path, 0)  # TODO: lookinto why this is not working!!!

    # one of the ways to tell if `RWF_NOWAIT` flag is working is to catch its error
    with pytest.raises(OSError):
        path = '/dev/shm/test_rwf_nowait_flag.txt'
        onwait_flag(path)


def onwait_flag(path):

    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NONBLOCK, 0o660)

    one = bytearray(6)
    two = bytearray(5)
    vec = liburing.iovec(one, two)

    ring = liburing.io_uring()
    cqes = liburing.io_uring_cqes()

    # print()

    try:
        # WRITE
        # -----
        os.write(fd, b'hello world')
        os.fsync(fd)

        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        # READ
        # ----
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec, len(vec), 0, os.RWF_NOWAIT)
        sqe.user_data = 1

        assert liburing.io_uring_submit(ring) == 1

        while True:
            try:
                liburing.io_uring_peek_cqe(ring, cqes)
            except BlockingIOError:
                pass  # print('test_rwf_nowait_flag BlockingIOError', flush=True)
            else:
                cqe = cqes[0]
                liburing.trap_error(cqe.res)
                assert cqe.res == 6 + 5
                assert cqe.user_data == 1
                assert one == b'hello '
                assert two == b'world'
                liburing.io_uring_cqe_seen(ring, cqe)
                break
    finally:
        liburing.io_uring_queue_exit(ring)
        os.close(fd)
        os.unlink(path)


def onwait_flag_empty_file(path, flag):

    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NONBLOCK, 0o660)
    vec = liburing.iovec(bytearray(5))

    ring = liburing.io_uring()
    cqes = liburing.io_uring_cqes()

    try:
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        # READ empty file
        # ---------------
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec, len(vec), 0, flag)
        sqe.user_data = 1

        assert liburing.io_uring_submit(ring) == 1

        while True:
            try:
                liburing.io_uring_peek_cqe(ring, cqes)
            except BlockingIOError:
                pass  # print('test_rwf_nowait_flag BlockingIOError', flush=True)
            else:
                cqe = cqes[0]
                # empty file with `RWF_NOWAIT` flag will return `-EAGAIN` rather then `0`
                if flag & os.RWF_NOWAIT:
                    assert cqe.res == -errno.EAGAIN
                else:
                    assert cqe.res == 0
                liburing.io_uring_cqe_seen(ring, cqe)
                break
    finally:
        liburing.io_uring_queue_exit(ring)
        os.close(fd)
        os.unlink(path)
