import math
import liburing


def test_time_convert():
    # int test
    assert liburing.time_convert(1) == (1, 0)
    # float test
    assert liburing.time_convert(1.5) == (1, 500_000_000)
    assert liburing.time_convert(1.05) == (1, 50_000_000)
    # float weirdness test
    result = liburing.time_convert(1.005)
    assert result[0] == 1
    assert math.isclose(result[1], 5_000_000, abs_tol=1)

    result = liburing.time_convert(1.0005)
    assert result[0] == 1
    assert math.isclose(result[1], 500_000, abs_tol=1)


def test_probe():
    op = liburing.probe()
    for name, bo in op.items():
        assert isinstance(name, str)
        assert isinstance(bo, bool)

    assert op['IORING_OP_NOP'] is True
    assert op.get('IORING_OP_LAST') is None


def test_get_sqes():
    ring = liburing.io_uring()
    try:
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        for sqe in liburing.get_sqes(ring, 2):
            liburing.io_uring_prep_nop(sqe)
            liburing.io_uring_sqe_set_flags(sqe, liburing.IOSQE_IO_LINK)

        assert liburing.io_uring_submit_and_wait(ring, 2) == 2
        liburing.io_uring_cq_advance(ring, 2)

    finally:
        liburing.io_uring_queue_exit(ring)

    # TODO:
    #   - need to catch `ValueError`
    #   - need to test if `io_uring_submit` is working right if count > free sqes available


def test_get_sqe():
    ring = liburing.io_uring()
    try:
        assert liburing.io_uring_queue_init(1, ring, 0) == 0
        sqe = liburing.get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)

        assert liburing.io_uring_submit_and_wait(ring, 1) == 1
        liburing.io_uring_cq_advance(ring, 1)
    finally:
        liburing.io_uring_queue_exit(ring)

    # TODO:
    #   - need to test if `io_uring_submit` is working right if there is no free sqe available
