import re
import errno
import pytest
import liburing


@pytest.mark.skip_linux(6.7)
def test_futex_state():
    # shared
    futex = liburing.futex_state()
    assert futex.state == 0
    assert futex.private is False
    futex.state = 123
    assert futex.state == 123

    assert repr(futex) == 'futex_state(state=123, private=False)'

    with pytest.raises(AttributeError):
        futex.private = True

    with pytest.raises(OverflowError):
        futex.state = -1

    with pytest.raises(OverflowError):
        liburing.futex_state(-1)

    with pytest.raises(NotImplementedError):
        liburing.futex_state(2)

        # TODO: enable this when `futex_state(num)` can handle `> 1`
        # max_1 = liburing.FUTEX_WAITV_MAX + 1
        # msg = re.escape(f'futex_state({max_1}) > {liburing.FUTEX_WAITV_MAX}')
        # with pytest.raises(ValueError, match=msg):
        #     liburing.futex_state(max_1)

    # private
    futex = liburing.futex_state(1, True)
    assert futex.private is True
    assert repr(futex) == 'futex_state(state=0, private=True)'

    # NULL
    futex = liburing.futex_state(0)
    assert futex.private is False
    with pytest.raises(MemoryError):
        assert futex.state is None
    with pytest.raises(MemoryError):
        futex.state = 123

    assert repr(futex) == 'futex_state(state=NULL, private=NULL)'


@pytest.mark.skip_linux('6.7')
def test_futex_waitv_class():
    with pytest.raises(TypeError):
        liburing.futex_waitv()

    futex = liburing.futex_state()
    fw = liburing.futex_waitv(futex)
    assert fw.val == 0
    assert fw.flags == 0
    fw.val = 1
    fw.flags = 2
    assert fw.val == 1
    assert fw.flags == 2

    futex = liburing.futex_state(1, True)
    fw = liburing.futex_waitv(futex)
    assert fw.val == 0
    assert fw.flags == liburing.FUTEX2_PRIVATE
    fw.flags = 123
    assert fw.flags == liburing.FUTEX2_PRIVATE | 123


@pytest.mark.skip_linux('6.7')
def test_multi_wake(ring, cqe):
    val = 0
    mask = liburing.FUTEX_BITSET_MATCH_ANY
    futex = liburing.futex_state()
    futex_flags = liburing.FUTEX2_SIZE_U32

    # Submit two futex waits
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 2

    assert liburing.io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, 2, mask, futex_flags)
    sqe.user_data = 100

    assert liburing.io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0
        assert cqe.res >= 0
        liburing.io_uring_cqe_seen(ring, cqe)
    assert liburing.io_uring_peek_cqe(ring, cqe) == -errno.EAGAIN


@pytest.mark.skip_linux(6.7)
def test_multi_wake_waitv(ring, cqe):
    futex = liburing.futex_state()
    f0 = liburing.futex_waitv(futex)
    f0.flags = liburing.FUTEX2_SIZE_U32

    # Submit two futex waits
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_waitv(sqe, f0)
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_waitv(sqe, f0)
    sqe.user_data = 2

    assert liburing.io_uring_submit(ring) == 2

    # Now submit wake for just one futex
    futex.state = 1
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, 2,
                                      liburing.FUTEX_BITSET_MATCH_ANY, liburing.FUTEX2_SIZE_U32)
    sqe.user_data = 100

    assert liburing.io_uring_submit(ring) == 1

    # We expect to find completions for the both futex waits, and the futex wake.
    for i in range(3):
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0
        assert cqe.res >= 0
        liburing.io_uring_cqe_seen(ring, cqe)
    assert liburing.io_uring_peek_cqe(ring, cqe) == -errno.EAGAIN


@pytest.mark.skip_linux(6.7)
def test_futex_wake_zero(ring, cqe):
    val = 0
    mask = liburing.FUTEX_BITSET_MATCH_ANY
    futex = liburing.futex_state()
    futex_flags = liburing.FUTEX2_SIZE_U32

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wait(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 1
    assert liburing.io_uring_submit(ring) == 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_futex_wake(sqe, futex, val, mask, futex_flags)
    sqe.user_data = 2
    assert liburing.io_uring_submit(ring) == 1

    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    # Should get zero res and it should be the wake
    assert cqe.res == 0 and cqe.user_data == 2
    liburing.io_uring_cqe_seen(ring, cqe)

    # Should not have the wait complete
    assert liburing.io_uring_peek_cqe(ring, cqe) == -errno.EAGAIN
