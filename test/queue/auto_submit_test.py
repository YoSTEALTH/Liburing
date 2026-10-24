"""`Ring(auto_submit=True)`: taking an entry from a full submission queue submits what is queued first,
except in the middle of a link chain (a submit would end the chain there)."""

import pytest
from liburing import *


@pytest.fixture
def small():
    """A ring with 4 submission entries that submits when full."""
    ring = Ring(auto_submit=True)
    io_uring_queue_init(4, ring)
    yield ring
    io_uring_queue_exit(ring)


def nop(ring, user_data, flags=0):
    sqe = io_uring_get_sqe(ring)
    assert sqe is not None
    io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    sqe.flags = flags
    return sqe


def reap(ring, cqe, n):
    """`user_data` and `res` of `n` completions, in order."""
    out = []
    for _ in range(n):
        assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
        out.append((cqe[0].user_data, cqe[0].res))
        io_uring_cqe_seen(ring, cqe[0])
    return out


def test_option():
    assert Ring().auto_submit is False
    ring = Ring(auto_submit=True)
    assert ring.auto_submit is True
    ring.auto_submit = False
    assert ring.auto_submit is False
    assert Ring(True).auto_submit is True


def test_default_full_queue(ring):
    n = io_uring_sq_space_left(ring)
    for i in range(n):
        nop(ring, i)
    assert io_uring_get_sqe(ring) is None  # you submit
    assert io_uring_prep_nop(Sqe(ring)) is False
    assert io_uring_sq_ready(ring) == n
    assert io_uring_submit(ring) == n
    io_uring_cq_advance(ring, io_uring_cq_ready(ring))


def test_get_sqe_submits(small, cqe):
    for i in range(10):
        nop(small, i)  # the 5th and 9th submit the 4 before
    assert io_uring_sq_ready(small) == 2
    assert io_uring_submit(small) == 2
    assert sorted(reap(small, cqe, 10)) == [(i, 0) for i in range(10)]  # every `user_data` kept


def test_sqe_ring_submits(small, cqe):
    sqe = Sqe(small)
    for i in range(10):
        assert io_uring_prep_nop(sqe) is True
        sqe.user_data = i
    assert io_uring_submit(small) == 2
    assert sorted(reap(small, cqe, 10)) == [(i, 0) for i in range(10)]


def test_not_mid_chain(small, cqe):
    for i in range(3):
        nop(small, i)
    last = nop(small, 3, IOSQE_IO_LINK)  # links to the next one: a submit now would end the chain
    assert io_uring_get_sqe(small) is None
    sqe = Sqe(small)
    assert io_uring_prep_nop(sqe) is False
    assert io_uring_sq_ready(small) == 4  # nothing submitted
    last.flags = 0
    nop(small, 4)  # the chain ended: submits the 4
    assert io_uring_sq_ready(small) == 1
    io_uring_submit(small)
    assert sorted(reap(small, cqe, 5)) == [(i, 0) for i in range(5)]


def test_put_sqe_chain_not_split(small, cqe):
    chain = Sqe(3)
    for i in range(3):
        io_uring_prep_nop(chain[i])
        chain[i].user_data = 10 + i
    chain[0].flags = chain[1].flags = IOSQE_IO_LINK
    nop(small, 1)
    nop(small, 2)  # 2 free: the chain needs 3
    assert put_sqe(small, chain) is True  # submitted the 2 first, then copied all 3
    assert io_uring_sq_ready(small) == 3
    assert io_uring_submit(small) == 3
    assert reap(small, cqe, 5)[2:] == [(10, 0), (11, 0), (12, 0)]  # the chain ran whole, in order


def test_put_sqe_longer_than_queue(small):
    assert put_sqe(small, Sqe(5)) is False  # 5 entries never fit in 4, submitted or not


def test_holds_survive_the_submit(small, cqe):
    import os

    r, w = os.pipe()
    try:
        os.write(w, b"abcdefgh")
        bufs = [bytearray(2) for _ in range(4)]
        for i, buf in enumerate(bufs):
            sqe = io_uring_get_sqe(small)
            io_uring_prep_read(sqe, r, buf)
            sqe.user_data = i
        nop(small, 9)  # full: submits the 4 reads (their holds move into table entries)
        io_uring_submit(small)
        assert sorted(reap(small, cqe, 5)) == [(0, 2), (1, 2), (2, 2), (3, 2), (9, 0)]
        assert b"".join(bufs) == b"abcdefgh"
    finally:
        os.close(r)
        os.close(w)
