import pytest
from liburing import *


def test_futex_6_7():
    # built without `futex2` (headers before Linux 6.7): `FUTEX2_PRIVATE == 0`
    if FUTEX2_PRIVATE == 0:
        with pytest.raises(RuntimeError):
            Futex()


def test_futex_state():
    # shared
    futex = Futex()
    assert futex.state == 0
    assert futex.private is False
    futex.state = 123
    assert futex.state == 123
    assert len(futex) == 1

    with pytest.raises(AttributeError):
        futex.private = True
    with pytest.raises(OverflowError):
        futex.state = -1
    with pytest.raises(OverflowError):
        Futex(-1)
    with pytest.raises(IndexError):
        futex[1]

    # private
    futex = Futex(2, FUTEX2_PRIVATE)
    assert futex.private is True
    assert len(futex) == 2

    with pytest.raises(ValueError):
        Futex(0)

    # 8 bytes
    futex = Futex(2, FUTEX2_SIZE_U32)
    with pytest.raises(OverflowError):
        futex.state = 256**4
    assert futex.state == 0
    futex.state = 1
    assert futex.state == futex[0].state == 1
    futex[1].state = 2
    assert futex[1].state == 2
    assert futex.state == futex[0].state == 1


def test_futex_waitv_class():
    fw = Futex(1, None, True)
    assert fw.val == 0
    assert fw.flags == FUTEX2_SIZE_U32
    fw.val = 1
    assert fw.val == 1
    fw.flags = FUTEX2_SIZE_U32 | FUTEX2_PRIVATE
    assert fw.flags == FUTEX2_SIZE_U32 | FUTEX2_PRIVATE
    assert fw.val == 1  # the flags setter used to write `.val`

    with pytest.raises(ValueError):
        Futex(FUTEX_WAITV_MAX + 1, None, True)

    fw = Futex(1, FUTEX2_PRIVATE, True)
    assert fw.val == 0
    assert fw.flags == FUTEX2_PRIVATE


def test_multi_wake(ring, cqe):
    val = 0
    mask = FUTEX_BITSET_MATCH_ANY
    futex_flags = FUTEX2_SIZE_U32

    # Submit two futex waits
    futex = Futex(2)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 2

    assert io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    futex[1].state = 1
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wake(sqe, futex, 2, mask, futex_flags)
    sqe.user_data = 100

    assert io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert io_uring_wait_cqe(ring, cqe) == 0
        entry = cqe[0]
        if not i:
            assert entry.res == 2
        io_uring_cqe_seen(ring, entry)
    try:
        io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


def test_futex_wake_zero(ring, cqe):
    val = 0
    mask = FUTEX_BITSET_MATCH_ANY
    futex_flags = FUTEX2_SIZE_U32
    futex = Futex(1, futex_flags)

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1
    assert io_uring_submit(ring) == 1

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wake(sqe, futex, 1, mask, futex_flags)
    sqe.user_data = 2
    assert io_uring_submit(ring) == 1

    assert io_uring_wait_cqe(ring, cqe) == 0

    # should get zero res and it should be the wake
    assert cqe[0].res == 1 and cqe[0].user_data == 2
    io_uring_cqe_seen(ring, cqe[0])

    # should not have the wait complete
    try:
        io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


def test_multi_wake_waitv(ring, cqe):
    # Submit two futex waits
    flag = FUTEX2_SIZE_U32

    futex = Futex(1, flag, True)
    if sqe := io_uring_get_sqe(ring):
        io_uring_prep_futex_waitv(sqe, futex)
        sqe.user_data = 1
    else:
        assert False

    if sqe := io_uring_get_sqe(ring):
        io_uring_prep_futex_waitv(sqe, futex)
        sqe.user_data = 2
    else:
        assert False

    assert io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_futex_wake(sqe, futex, 2, FUTEX_BITSET_MATCH_ANY, flag)
    sqe.user_data = 100

    assert io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert io_uring_wait_cqe(ring, cqe) == 0
        entry = cqe[0]
        if not i:
            assert entry.res == 2
        io_uring_cqe_seen(ring, entry)
    try:
        io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


def test_futex_define():
    assert FUTEX_WAIT == 0
    assert FUTEX_WAKE == 1
    assert FUTEX_FD == 2
    assert FUTEX_REQUEUE == 3
    assert FUTEX_CMP_REQUEUE == 4
    assert FUTEX_WAKE_OP == 5
    assert FUTEX_LOCK_PI == 6
    assert FUTEX_UNLOCK_PI == 7
    assert FUTEX_TRYLOCK_PI == 8
    assert FUTEX_WAIT_BITSET == 9
    assert FUTEX_WAKE_BITSET == 10
    assert FUTEX_WAIT_REQUEUE_PI == 11
    assert FUTEX_CMP_REQUEUE_PI == 12
    assert FUTEX_LOCK_PI2 == 13

    if FUTEX2_PRIVATE == 0:
        assert FUTEX2_PRIVATE == 0
        assert FUTEX2_SIZE_U32 == 0
        assert FUTEX2_NUMA == 0

        assert FUTEX2_PRIVATE | FUTEX_WAIT == 0
        assert FUTEX2_PRIVATE | FUTEX_WAKE == 1
    else:
        assert FUTEX2_PRIVATE == 128
        assert FUTEX2_SIZE_U32 == 0x02
        assert FUTEX2_NUMA == 0x04

        assert FUTEX2_PRIVATE | FUTEX_WAIT == 128
        assert FUTEX2_PRIVATE | FUTEX_WAKE == 129

    assert FUTEX2_MPOL == 0x08 or FUTEX2_MPOL == 0
    assert FUTEX_WAITV_MAX == 128
    assert FUTEX_BITSET_MATCH_ANY == 0xFFFFFFFF
