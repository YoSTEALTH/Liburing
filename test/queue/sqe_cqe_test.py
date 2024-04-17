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


def test_io_uring_cqe():
    cqe = liburing.io_uring_cqe()
    with pytest.raises(IndexError, match=re.escape('`io_uring_cqe()[0]` out of `cqe`')):
        cqe[0]
    with pytest.raises(IndexError, match=re.escape('`io_uring_cqe()[1]` out of `cqe`')):
        cqe[1]
