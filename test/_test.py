import os
import pytest
import liburing


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
