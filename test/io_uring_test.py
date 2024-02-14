from re import escape
from pytest import raises
from liburing import io_uring_sqe, io_uring_cqe


def test_io_uring_sqe():
    sqe = io_uring_sqe(0)
    assert len(sqe) == 0
    assert bool(sqe) is False

    sqe = io_uring_sqe()
    assert len(sqe) == 1
    assert bool(sqe) is True

    sqe = io_uring_sqe(2)
    assert len(sqe) == 2
    assert sqe[0] is sqe
    assert (a := sqe[1]) is not sqe
    assert (b := sqe[1]) is a  # refernce from cache
    assert b is not sqe
    with raises(IndexError):
        assert sqe[2]

    with raises(OverflowError, match="can't convert negative value to unsigned int"):
        io_uring_sqe(-3)

    with raises(TypeError):
        io_uring_sqe(None)


def test_io_uring_cqe():
    cqe = io_uring_cqe()
    with raises(IndexError, match=escape('`io_uring_cqe()[0]` out of `cqe`')):
        cqe[0]
    with raises(IndexError, match=escape('`io_uring_cqe()[1]` out of `cqe`')):
        cqe[1]
