import pytest
from liburing import *


def submit_nops(ring, n, start=0):
    for i in range(n):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = start + i + 1
    assert io_uring_submit_and_wait(ring, n) == n


def test_peek_batch_cqe(ring):
    batch = CqeBatch(8)
    assert io_uring_peek_batch_cqe(ring, batch) == 0  # nothing ready
    assert len(batch) == 0

    submit_nops(ring, 5)
    assert io_uring_peek_batch_cqe(ring, batch, 2) == 2  # partial
    assert [c.user_data for c in batch] == [1, 2]
    io_uring_cq_advance(ring, 2)

    assert io_uring_peek_batch_cqe(ring, batch) == 3  # rest
    assert [c.user_data for c in batch] == [3, 4, 5]
    with pytest.raises(IndexError):
        batch[3]
    io_uring_cq_advance(ring, 3)


def test_peek_batch_cqe_misuse(ring):
    with pytest.raises(ValueError):
        CqeBatch(0)
    with pytest.raises(ValueError):
        io_uring_peek_batch_cqe(ring, CqeBatch(2), 3)
    with pytest.raises(TypeError):
        io_uring_peek_batch_cqe(ring, Cqe())
