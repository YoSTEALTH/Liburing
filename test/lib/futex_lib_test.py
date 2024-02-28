import pytest
import liburing


@pytest.mark.skip_linux('6.7')
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

    assert liburing.FUTEX2_SIZE_U8 == 0x00
    assert liburing.FUTEX2_SIZE_U16 == 0x01
    assert liburing.FUTEX2_SIZE_U32 == 0x02
    assert liburing.FUTEX2_SIZE_U64 == 0x03
    assert liburing.FUTEX2_NUMA == 0x04

    assert liburing.FUTEX2_PRIVATE == 128
    assert liburing.FUTEX_WAITV_MAX == 128
    assert liburing.FUTEX_BITSET_MATCH_ANY == 0xffffffff

    assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAIT == 128
    assert liburing.FUTEX2_PRIVATE | liburing.FUTEX_WAKE == 129
