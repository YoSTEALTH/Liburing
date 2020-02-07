import os
import pytest
import liburing


# Setup init & exit
# -----------------
def test_setup():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    assert liburing.io_uring_queue_exit(ring) is None


def test_setup_polling_io():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_IOPOLL) == 0
    assert liburing.io_uring_queue_exit(ring) is None


@pytest.mark.skipif(os.getuid() != 0, reason='`IORING_SETUP_SQPOLL` must be run as "root" user.')
def test_setup_kernel_side_polling():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_SQPOLL) == 0
    assert liburing.io_uring_queue_exit(ring) is None
