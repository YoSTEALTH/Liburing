import pytest
import liburing


def test_io_uring_init_exit():
    ring = liburing.Ring()
    assert ring.flags == 0
    assert ring.ring_fd == 0
    assert ring.features == 0
    assert ring.enter_ring_fd == 0
    assert ring.int_flags == 0

    with pytest.raises(TypeError):
        liburing.io_uring_queue_init(-1, ring, 0)

    with pytest.raises(TypeError):
        liburing.io_uring_queue_init(8, ring, -1)

    assert liburing.io_uring_queue_init(1, ring, 0) == 0
    assert ring.ring_fd > -1
    assert ring.enter_ring_fd > -1
    with pytest.raises(RuntimeError):  # Trying to init again
        liburing.io_uring_queue_init(4, ring, 0)
    assert liburing.io_uring_queue_exit(ring) is None
    # Trying to exit again
    with pytest.raises(RuntimeError):
        liburing.io_uring_queue_exit(ring) is None  # will not call internally but

    ring = liburing.Ring()
    with pytest.raises(RuntimeError):
        liburing.io_uring_queue_exit(ring)


def test_setup_iopoll_sqpoll():
    for i, setup in enumerate((liburing.IORING_SETUP_IOPOLL, liburing.IORING_SETUP_SQPOLL), 1):
        ring = liburing.Ring()
        assert liburing.io_uring_queue_init(1, ring, setup) == 0
        assert liburing.io_uring_queue_exit(ring) is None


def test_max_entries_plus():
    max_plus = 32768 + 1
    ring = liburing.Ring()
    with pytest.raises(OSError):  # OSError: [Errno 22] Invalid argument
        liburing.io_uring_queue_init(max_plus, ring)
    with pytest.raises(RuntimeError):
        liburing.io_uring_queue_exit(ring)


def test_init_max():
    ring = liburing.Ring()
    cqe = liburing.Cqe()
    maximum = 32768
    liburing.io_uring_queue_init(maximum, ring)

    for i in range(maximum - 1):
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.flags = liburing.IOSQE_IO_LINK | liburing.IOSQE_ASYNC
        sqe.user_data = i + 1  # `sqe.user_data` can not be `0`
    else:  # last
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.flags = liburing.IOSQE_ASYNC
        sqe.user_data = i + 1 + 1

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, maximum) == maximum

    for i in range(maximum):
        assert cqe[i].user_data == i + 1

    liburing.io_uring_cq_advance(ring, maximum)
    with pytest.raises(BlockingIOError):
        liburing.io_uring_peek_cqe(ring, cqe)
    liburing.io_uring_queue_exit(ring)


def test_io_uring_submit_and_wait(ring, cqe):
    sqe = liburing.io_uring_get_sqe(ring)
    sqe.user_data = 123
    assert liburing.io_uring_sq_ready(ring) == 1
    assert liburing.io_uring_submit_and_wait(ring, 1) == 1
    assert liburing.io_uring_sq_ready(ring) == 0
    liburing.io_uring_peek_cqe(ring, cqe)
    assert cqe[0].user_data == 123
