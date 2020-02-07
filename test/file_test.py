import os
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

    # prepare for writing two separate writes.
    one = bytearray(b'hello')
    two = bytearray(b'world')
    vec_one = liburing.iovec(one)
    vec_two = liburing.iovec(two)

    try:
        # initialization
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        # write "hello"
        sqe = liburing.io_uring_get_sqe(ring)  # get sqe (submission queue entry) to fill
        liburing.io_uring_prep_writev(sqe, fd, vec_one, 1, 0)

        # write "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_writev(sqe, fd, vec_two, 1, 5)

        # submit both writes
        assert liburing.io_uring_submit(ring) == 2

        cqes = liburing.io_uring_cqes()
        # wait for cqe (completion queue entry)
        liburing.io_uring_wait_cqes(ring, cqes, 2)

        # clear old query ?
        cqe = liburing.io_uring_cqe()
        liburing.io_uring_cqe_seen(ring, cqe)

        # read "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec_one, 1, 5)

        # read "hello"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec_two, 1, 0)

        # submit both reads
        assert liburing.io_uring_submit(ring) == 2

        # wait for the cqe to complete
        cqes = liburing.io_uring_cqes()
        liburing.io_uring_wait_cqes(ring, cqes, 2)

        cqe = liburing.io_uring_cqe()
        liburing.io_uring_cqe_seen(ring, cqe)

        # use same as write buffer to read but switch values so the change is detected
        assert two == b'hello'
        assert one == b'world'
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)
