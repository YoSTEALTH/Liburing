from errno import EINVAL
from pytest import raises
from liburing import IORING_SETUP_IOPOLL, IORING_SETUP_SQPOLL, \
                     io_uring, io_uring_queue_init, io_uring_queue_exit


def test_io_uring_init_exit():
    ring = io_uring()
    assert io_uring_queue_init(8, ring, 0) == 0
    assert ring.flags == 65_536
    assert ring.ring_fd > 0
    assert ring.features == 16_383
    assert ring.enter_ring_fd > 0
    assert ring.int_flags == 0
    assert io_uring_queue_exit(ring) is None
    assert str(ring).startswith('io_uring(flags=')

    ring = io_uring()
    with raises(OSError) as e:  # Invalid argument
        io_uring_queue_init(0, ring, 0)
    assert e.value.errno == EINVAL
    assert io_uring_queue_exit(ring) is None


def test_setup_iopoll_sqpoll():
    for i, setup in enumerate((IORING_SETUP_IOPOLL, IORING_SETUP_SQPOLL), 1):
        ring = io_uring()
        try:
            assert io_uring_queue_init(1, ring, setup) == 0
            assert ring.flags == 65_536 + i
        finally:
            assert io_uring_queue_exit(ring) is None
