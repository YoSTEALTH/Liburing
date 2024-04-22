import re
import pytest
import liburing


def test_io_uring_sqe():
    sqe = liburing.io_uring_sqe(0)
    assert len(sqe) == 0
    assert bool(sqe) is False

    sqe = liburing.io_uring_sqe()
    assert len(sqe) == 1
    assert bool(sqe) is True

    sqe = liburing.io_uring_sqe(2)
    assert len(sqe) == 2
    assert sqe[0] is sqe
    assert (a := sqe[1]) is not sqe
    assert (b := sqe[1]) is a  # refernce from cache
    assert b is not sqe
    with pytest.raises(IndexError):
        assert sqe[2]

    with pytest.raises(OverflowError, match="can't convert negative value to __u16"):
        liburing.io_uring_sqe(-3)

    with pytest.raises(TypeError):
        liburing.io_uring_sqe(None)


def test_io_uring_cqe(ring, cqe):
    with pytest.raises(IndexError, match=re.escape('`io_uring_cqe()[0]` out of `cqe`')):
        cqe[0]
    with pytest.raises(IndexError, match=re.escape('`io_uring_cqe()[1]` out of `cqe`')):
        cqe[1]
    with pytest.raises(MemoryError, match=re.escape('`io_uring_cqe()` out of `cqe`')):
        cqe.user_data
    # with pytest.raises(MemoryError, match=re.escape('`io_uring_cqe()` out of `cqe`')):
    assert not (True if cqe else False)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 2

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    assert True if cqe else False
    assert cqe.user_data == 1
    assert True if cqe[1] else False
    assert cqe[1].user_data == 2
    with pytest.raises(IndexError, match=re.escape('`io_uring_cqe()[2]` out of `cqe`')):
        assert cqe[2]


def test_cqe_get_index():
    liburing.test_cqe_get_index()
