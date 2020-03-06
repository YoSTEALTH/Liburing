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
        liburing.io_uring_prep_writev(sqe, fd, vec_one, len(vec_one), 0)

        # write "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_writev(sqe, fd, vec_two, len(vec_two), 5)

        # submit both writes
        assert liburing.io_uring_submit(ring) == 2

        # submits and wait for cqe (completion queue entry)
        liburing.io_uring_wait_cqes(ring, cqes, 2)

        cqe = cqes[0]
        liburing.io_uring_cqe_seen(ring, cqe)

        cqe = cqes[1]
        liburing.io_uring_cqe_seen(ring, cqe)

        # read "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec_one, len(vec_one), 5)

        # read "hello"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_readv(sqe, fd, vec_two, len(vec_two), 0)

        # submit both reads
        assert liburing.io_uring_submit(ring) == 2

        # submit and wait for the cqe to complete, reuse `cqes` again.
        liburing.io_uring_wait_cqes(ring, cqes, 2)

        cqe = cqes[0]
        liburing.io_uring_cqe_seen(ring, cqe)

        cqe = cqes[1]
        liburing.io_uring_cqe_seen(ring, cqe)

        # use same as write buffer to read but switch values so the change is detected
        assert two == b'hello'
        assert one == b'world'
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)
