import errno
import pytest
import liburing


def test_io_uring_init_exit():
    ring = liburing.io_uring()    
    assert ring.flags == 0
    assert ring.ring_fd == 0
    assert ring.features == 0
    assert ring.enter_ring_fd == 0
    assert ring.int_flags == 0
    assert liburing.io_uring_queue_init(8, ring, 0) == 0
    assert ring.ring_fd > 0
    assert ring.enter_ring_fd > 0
    assert liburing.io_uring_queue_exit(ring) == 0
    assert str(ring).startswith('io_uring(flags=')

    ring = liburing.io_uring()
    with pytest.raises(OSError) as e:  # Invalid argument
        liburing.io_uring_queue_init(0, ring, 0)
    assert e.value.errno == errno.EINVAL
    with pytest.raises(ValueError):
        assert liburing.io_uring_queue_exit(ring) == 0


def test_setup_iopoll_sqpoll():
    for i, setup in enumerate((liburing.IORING_SETUP_IOPOLL, liburing.IORING_SETUP_SQPOLL), 1):
        ring = liburing.io_uring()
        assert liburing.io_uring_queue_init(1, ring, setup) == 0
        assert liburing.io_uring_queue_exit(ring) == 0


def test_init_max():
    cqe = liburing.io_uring_cqe()
    ring = liburing.io_uring()
    maximum = 32768
    with pytest.raises(OSError):
        liburing.io_uring_queue_init(maximum+1, ring)
    liburing.io_uring_queue_init(maximum, ring)

    for i in range(maximum-1):
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.flags = liburing.IOSQE_IO_LINK | liburing.IOSQE_ASYNC
        sqe.user_data = i
    else:  # last
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.flags = liburing.IOSQE_ASYNC
        sqe.user_data = i+1

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, maximum) == maximum

    for i in range(maximum):
        assert cqe[i].user_data == i

    liburing.io_uring_cq_advance(ring, maximum)
    assert liburing.io_uring_peek_cqe(ring, cqe) == -errno.EAGAIN
    liburing.io_uring_queue_exit(ring)
