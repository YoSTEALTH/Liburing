import pytest
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
    assert sqe[1] is not sqe
    with pytest.raises(IndexError):
        assert sqe[2]

    with pytest.raises(OverflowError, match="can't convert negative value to unsigned int"):
        io_uring_sqe(-3)

    with pytest.raises(TypeError):
        io_uring_sqe(None)


def test_io_uring_cqe():
    io_uring_cqe()
    # note: not much to test here, since the data is filled by `io_uring` backend.
    #       most of the test will be done while using other functions
