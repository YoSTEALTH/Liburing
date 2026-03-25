import pytest
import liburing


def test_Sqe():
    with pytest.raises(RuntimeError):
        sqe = liburing.Sqe(0)

    sqe = liburing.Sqe()
    assert sqe.fd == 0
    assert sqe.len == 0
    assert sqe.user_data == 0
    assert len(sqe) == 1
    assert bool(sqe) is True

    sqe = liburing.Sqe(2)
    assert len(sqe) == 2
    assert True if sqe[1] else False
    sqe.user_data = 123
    assert sqe.user_data == 123
    assert sqe[0].user_data == 123
    assert sqe[0].user_data is sqe.user_data
    assert sqe[1].user_data == 0
    sqe[1].user_data = 321
    assert sqe[1].user_data == 321
    assert sqe.user_data == 123  # check again to make sure wires aren't crossed.

    with pytest.raises(IndexError):
        assert sqe[2]

    with pytest.raises(OverflowError):
        liburing.Sqe(-3)


def test_Cqe(ring, cqe):
    with pytest.raises(IndexError):
        cqe[0]
    with pytest.raises(IndexError):
        cqe[1]
    with pytest.raises(AttributeError):
        cqe.user_data
    assert not (True if cqe else False)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 2

    assert liburing.io_uring_submit(ring) == 2
    assert liburing.io_uring_wait_cqe_nr(ring, cqe, 2) == 0
    assert liburing.io_uring_cq_ready(ring) == 2

    assert True if cqe else False
    entry = cqe[0]
    assert entry.user_data == 1
    assert liburing.io_uring_cqe_seen(ring, entry) is None

    assert True if cqe[1] else False
    entry = cqe[1]
    assert entry.user_data == 2
    assert liburing.io_uring_cqe_seen(ring, entry) is None
