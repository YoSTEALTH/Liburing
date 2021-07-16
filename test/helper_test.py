import math
from liburing import IOSQE_IO_LINK, io_uring, ffi, files, time_convert, probe, io_uring_queue_init, \
                     get_sqes, io_uring_prep_nop, io_uring_sqe_set_flags, io_uring_submit_and_wait, \
                     io_uring_cq_advance, io_uring_queue_exit, get_sqe


sizeof = ffi.sizeof


def test_time_convert():
    # int test
    assert time_convert(1) == (1, 0)
    # float test
    assert time_convert(1.5) == (1, 500_000_000)
    assert time_convert(1.05) == (1, 50_000_000)
    # float weirdness test
    result = time_convert(1.005)
    assert result[0] == 1
    assert math.isclose(result[1], 5_000_000, abs_tol=1)

    result = time_convert(1.0005)
    assert result[0] == 1
    assert math.isclose(result[1], 500_000, abs_tol=1)


def test_probe():
    op = probe()
    for name, bo in op.items():
        assert isinstance(name, str)
        assert isinstance(bo, bool)

    assert op['IORING_OP_NOP'] is True
    assert op.get('IORING_OP_LAST') is None


def test_get_sqes():
    ring = io_uring()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        for sqe in get_sqes(ring, 2):
            io_uring_prep_nop(sqe)
            io_uring_sqe_set_flags(sqe, IOSQE_IO_LINK)

        assert io_uring_submit_and_wait(ring, 2) == 2
        io_uring_cq_advance(ring, 2)

    finally:
        io_uring_queue_exit(ring)

    # TODO:
    #   - need to catch `ValueError`
    #   - need to test if `io_uring_submit` is working right if count > free sqes available


def test_get_sqe():
    ring = io_uring()
    try:
        assert io_uring_queue_init(1, ring, 0) == 0
        sqe = get_sqe(ring)
        io_uring_prep_nop(sqe)

        assert io_uring_submit_and_wait(ring, 1) == 1
        io_uring_cq_advance(ring, 1)
    finally:
        io_uring_queue_exit(ring)

    # TODO:
    #   - need to test if `io_uring_submit` is working right if there is no free sqe available


def test_files():
    assert sizeof(files(1)) == 4
    assert sizeof(files(1, 2, 3)) == 12
    assert sizeof(files([1, 2, 3])) == 12

    assert list(files(1)) == [1]
    assert list(files(1, 2, 3)) == [1, 2, 3]
    assert list(files([1, 2, 3])) == [1, 2, 3]
    assert list(files(-1 for _ in range(3))) == [-1, -1, -1]
    assert list(files(*(-1 for _ in range(3)))) == [-1, -1, -1]
