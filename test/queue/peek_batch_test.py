import pytest

import liburing


def submit_nops(ring, n, start=0):
    for i in range(n):
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.user_data = start + i + 1
    assert liburing.io_uring_submit_and_wait(ring, n) == n


def test_peek_batch_cqe(ring):
    batch = liburing.CqeBatch(8)
    assert liburing.io_uring_peek_batch_cqe(ring, batch) == 0  # nothing ready
    assert len(batch) == 0

    submit_nops(ring, 5)
    assert liburing.io_uring_peek_batch_cqe(ring, batch, 2) == 2  # partial
    assert [c.user_data for c in batch] == [1, 2]
    liburing.io_uring_cq_advance(ring, 2)

    assert liburing.io_uring_peek_batch_cqe(ring, batch) == 3  # rest
    assert [c.user_data for c in batch] == [3, 4, 5]
    with pytest.raises(IndexError):
        batch[3]
    liburing.io_uring_cq_advance(ring, 3)


def test_peek_batch_cqe_misuse(ring):
    with pytest.raises(ValueError):
        liburing.CqeBatch(0)
    with pytest.raises(ValueError):
        liburing.io_uring_peek_batch_cqe(ring, liburing.CqeBatch(2), 3)
    with pytest.raises(TypeError):
        liburing.io_uring_peek_batch_cqe(ring, liburing.Cqe())
