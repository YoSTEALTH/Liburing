import os
import pytest
import ctypes
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
def test_file(tmpdir):
    ring = liburing.io_uring()
    # ring = (liburing.io_uring*1)()
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    fd1 = os.open(os.path.join(tmpdir, '1.txt'), os.O_CREAT)
    fd2 = os.open(os.path.join(tmpdir, '2.txt'), os.O_CREAT)
    try:
        files = liburing.files_fds(fd1, fd2)
        # register file
        assert liburing.io_uring_register_files(ring, files, len(files)) == 0
        # unregister all file(s)
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        os.close(fd1)
        os.close(fd2)
        liburing.io_uring_queue_exit(ring)


# TODO: Working on
def test_file_2(tmpdir):
    ring = liburing.io_uring()
    ts = liburing.kernel_timespec(1, 0)
    # assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_IOPOLL) == 0
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    fd = os.open(os.path.join(tmpdir, '1.txt'), os.O_RDWR | os.O_CREAT)
    os.write(fd, b'test1tt2t3t5t6t6t8')
    cqe = ctypes.pointer(liburing.io_uring_cqe())  # completion queue
    try:
        # get an sqe and fill in a READV operation
        sqe = liburing.io_uring_get_sqe(ring)

        buffer = bytearray(5)
        vecs = liburing.prep.iovec_read(buffer)

        liburing.prep.io_uring_prep_readv(sqe, fd, vecs, 1, 0)

        # tell the kernel we have an sqe ready for consumption
        result = liburing.io_uring_submit(ring)

        if result != 1:
            raise ValueError(f'submit got {result}, wanted 1')

        # wait for the sqe to complete
        no = liburing.io_uring_wait_cqes(ring, cqe, 1, ts, None)
        if no:
            raise OSError(-no, os.strerror(-no))

        assert b'test1' == buffer
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)


# TODO
def test_file_polling_io(tmpdir):
    ring = liburing.io_uring()
    sqe = liburing.io_uring_sqe()  # submission queue
    cqe = liburing.io_uring_cqe()  # completion queue

    assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_IOPOLL) == 0
    fd1 = os.open(os.path.join(tmpdir, '1.txt'), os.O_CREAT)
    fd2 = os.open(os.path.join(tmpdir, '2.txt'), os.O_CREAT)
    try:
        files = liburing.files_fds(fd1, fd2)
        # register file
        assert liburing.io_uring_register_files(ring, files, len(files)) == 0

        # unregister all file(s)
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        os.close(fd1)
        os.close(fd2)
        liburing.io_uring_queue_exit(ring)


# TODO
def test_file_kernel_side_polling(tmpdir):
    pass
