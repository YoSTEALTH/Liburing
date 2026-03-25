import pytest
import liburing


def test_futex_6_7():
    # this should run if linux `< 6.7`
    if liburing.linux_version_check(6.7):
        with pytest.raises(RuntimeError):
            liburing.Futex()


@pytest.mark.skip_linux(6.7)
def test_futex_state():
    # shared
    futex = liburing.Futex()
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
        liburing.Futex(-1)
    with pytest.raises(IndexError):
        futex[1]

    # private
    futex = liburing.Futex(2, liburing.FUTEX2_PRIVATE)
    assert futex.private is True
    assert len(futex) == 2

    with pytest.raises(ValueError):
        liburing.Futex(0)

    # 8 bytes
    futex = liburing.Futex(2, liburing.FUTEX2_SIZE_U32)
    with pytest.raises(OverflowError):
        futex.state = 256**4
    assert futex.state == 0
    futex.state = 1
    assert futex.state == futex[0].state == 1
    futex[1].state = 2
    assert futex[1].state == 2
    assert futex.state == futex[0].state == 1


@pytest.mark.skip_linux("6.7")
def test_futex_waitv_class():
    fw = liburing.Futex(1, None, True)
    assert fw.val == 0
    assert fw.flags == liburing.FUTEX2_SIZE_U32
    fw.val = 1
    assert fw.val == 1

    with pytest.raises(ValueError):
        liburing.Futex(liburing.FUTEX_WAITV_MAX + 1, None, True)

    fw = liburing.Futex(1, liburing.FUTEX2_PRIVATE, True)
    assert fw.val == 0
    assert fw.flags == liburing.FUTEX2_PRIVATE


@pytest.mark.skip_linux("6.7")
def test_multi_wake(ring, cqe):
    val = 0
    mask = liburing.FUTEX_BITSET_MATCH_ANY
    futex_flags = liburing.FUTEX2_SIZE_U32

    # Submit two futex waits
    futex = liburing.Futex(2)
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 2

    assert liburing.io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    futex[1].state = 1
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, 2, mask, futex_flags)
    sqe.user_data = 100

    assert liburing.io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0
        entry = cqe[0]
        liburing.trap_error(entry.res)
        liburing.io_uring_cqe_seen(ring, entry)
    try:
        liburing.io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


@pytest.mark.skip_linux(6.7)
def test_futex_wake_zero(ring, cqe):
    val = 0
    mask = liburing.FUTEX_BITSET_MATCH_ANY
    futex_flags = liburing.FUTEX2_SIZE_U32
    futex = liburing.Futex(1, futex_flags)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1
    assert liburing.io_uring_submit(ring) == 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, 1, mask, futex_flags)
    sqe.user_data = 2
    assert liburing.io_uring_submit(ring) == 1

    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    # should get zero res and it should be the wake
    assert cqe[0].res == 1 and cqe[0].user_data == 2
    liburing.io_uring_cqe_seen(ring, cqe[0])

    # should not have the wait complete
    try:
        liburing.io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


@pytest.mark.skip_linux(6.7)
def test_multi_wake_waitv(ring, cqe):
    # Submit two futex waits
    flag = liburing.FUTEX2_SIZE_U32

    futex = liburing.Futex(1, flag, True)
    if sqe := liburing.io_uring_get_sqe(ring):
        liburing.io_uring_prep_futex_waitv(sqe, futex)
        sqe.user_data = 1
    else:
        assert False

    if sqe := liburing.io_uring_get_sqe(ring):
        liburing.io_uring_prep_futex_waitv(sqe, futex)
        sqe.user_data = 2
    else:
        assert False

    assert liburing.io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, 2, liburing.FUTEX_BITSET_MATCH_ANY, flag)
    sqe.user_data = 100

    assert liburing.io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0
        entry = cqe[0]
        liburing.trap_error(entry.res)
        liburing.io_uring_cqe_seen(ring, entry)
    try:
        liburing.io_uring_peek_cqe(ring, cqe)
    except BlockingIOError:
        pass


def test_futex_define():
    assert liburing.FUTEX_WAIT == 0
    assert liburing.FUTEX_WAKE == 1
    assert liburing.FUTEX_FD == 2
    assert liburing.FUTEX_REQUEUE == 3
    assert liburing.FUTEX_CMP_REQUEUE == 4
    assert liburing.FUTEX_WAKE_OP == 5
    assert liburing.FUTEX_LOCK_PI == 6
    assert liburing.FUTEX_UNLOCK_PI == 7
    assert liburing.FUTEX_TRYLOCK_PI == 8
    assert liburing.FUTEX_WAIT_BITSET == 9
    assert liburing.FUTEX_WAKE_BITSET == 10
    assert liburing.FUTEX_WAIT_REQUEUE_PI == 11
    assert liburing.FUTEX_CMP_REQUEUE_PI == 12
    assert liburing.FUTEX_LOCK_PI2 == 13

    if liburing.linux_version_check(6.7):
        assert liburing.FUTEX2_PRIVATE == 0
        assert liburing.FUTEX2_SIZE_U32 == 0
        assert liburing.FUTEX2_NUMA == 0

        assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAIT == 0
        assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAKE == 1
    else:
        assert liburing.FUTEX2_PRIVATE == 128
        assert liburing.FUTEX2_SIZE_U32 == 0x02
        assert liburing.FUTEX2_NUMA == 0x04

        assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAIT == 128
        assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAKE == 129

    assert liburing.FUTEX2_MPOL == 0x08 or 0
    assert liburing.FUTEX_WAITV_MAX == 128
    assert liburing.FUTEX_BITSET_MATCH_ANY == 0xFFFFFFFF
