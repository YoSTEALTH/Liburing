import os
import pytest
import liburing
import liburing.prep


# Setup init & exit
# -----------------
def test_setup():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    liburing.io_uring_queue_exit(ring)


def test_setup_polling_io():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_IOPOLL) == 0
    liburing.io_uring_queue_exit(ring)


@pytest.mark.skipif(os.getuid() != 0, reason='`IORING_SETUP_SQPOLL` must be run as "root" user.')
def test_setup_kernel_side_polling():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_SQPOLL) == 0
    liburing.io_uring_queue_exit(ring)


# File
# ----
def test_file_registration(tmpdir):
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    fd1 = os.open(os.path.join(tmpdir, '1.txt'), os.O_CREAT)
    fd2 = os.open(os.path.join(tmpdir, '2.txt'), os.O_CREAT)
    try:
        files = liburing.files_fds(fd1, fd2)
        assert liburing.io_uring_register_files(ring, files, len(files)) == 0
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        os.close(fd1)
        os.close(fd2)
        liburing.io_uring_queue_exit(ring)


def test_file_write_read(tmpdir):
    fd = os.open(os.path.join(tmpdir, '1.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    ring = liburing.io_uring()
    # prepare for writing and reading
    vecs_write = liburing.prep.iovec_write(b'hello', b'world')
    hello = bytearray(5)
    world = bytearray(5)
    vecs_read = liburing.prep.iovec_read(hello, world)
    try:
        # initialization
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        sqe = liburing.io_uring_get_sqe(ring)
        liburing.prep.io_uring_prep_writev(sqe, fd, vecs_write[0], 1, 0)

        sqe = liburing.io_uring_get_sqe(ring)
        liburing.prep.io_uring_prep_writev(sqe, fd, vecs_write[1], 1, 5)

        # submit both writes
        assert liburing.io_uring_submit(ring) == 2

        # read "hello"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.prep.io_uring_prep_readv(sqe, fd, vecs_read[0], 1, 0)

        # read "world"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.prep.io_uring_prep_readv(sqe, fd, vecs_read[1], 1, 5)

        # submit both reads
        assert liburing.io_uring_submit(ring) == 2
        assert hello == b'hello'
        assert world == b'world'
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)
