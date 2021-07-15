from os import getuid
from pytest import mark, raises, skip
from liburing import IORING_SETUP_IOPOLL, IORING_SETUP_SQPOLL, lib, \
                     io_uring, io_uring_queue_init, io_uring_queue_exit, skip_os


# Setup init & exit
# -----------------
def test_setup():
    ring = io_uring()
    assert io_uring_queue_init(1, ring, 0) == 0
    assert io_uring_queue_exit(ring) is None

    ring = io_uring()
    with raises(ValueError):
        assert io_uring_queue_init(0, ring, 0) == 0

    # check `ring.ring_fd` test
    ring = io_uring()
    try:
        assert lib.io_uring_queue_init(0, ring, 0) == -22
    finally:
        assert io_uring_queue_exit(ring) is None


def test_setup_polling_io():
    ring = io_uring()
    assert io_uring_queue_init(1, ring, IORING_SETUP_IOPOLL) == 0
    assert io_uring_queue_exit(ring) is None


@mark.skipif(getuid() != 0, reason='`IORING_SETUP_SQPOLL` must be run as "root" user.')
def test_setup_kernel_side_polling_by_root():
    ring = io_uring()
    assert io_uring_queue_init(1, ring, IORING_SETUP_SQPOLL) == 0
    assert io_uring_queue_exit(ring) is None


@mark.skipif(skip_os('5.11'), reason='`IORING_SETUP_SQPOLL` Linux version is `< 5.11`')
def test_setup_kernel_side_polling_by_user():
    try:
        ring = io_uring()
        assert io_uring_queue_init(1, ring, IORING_SETUP_SQPOLL) == 0
        assert io_uring_queue_exit(ring) is None
    except PermissionError:
        skip('CAP_SYS_NICE not enabled!')
