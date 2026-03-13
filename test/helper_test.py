import pytest
import liburing


def test_file_index():
    ids = liburing.FileIndex([-1, -1, 3])
    assert ids[1] == -1
    ids.update([4, 5, 6])
    assert ids[1] == 5
    assert list(ids) == [4, 5, 6]

    # error
    pytest.skip("PyOZ bug.")
    with pytest.raises(ValueError):
        ids.update([4, 5, 6, 7, 8, 9])  # PyOZ raises `RuntimeError: ValueError`

    with pytest.raises(TypeError):  # PyOZ raises `RuntimeError: TypeError`
        ids.update([4, 5, "s"])


def test_timespec():
    ts = liburing.timespec(1)
    assert ts.sec == 1
    assert ts.nsec == 0

    ts = liburing.timespec(1.5)
    assert ts.sec == 1
    assert ts.nsec == 500_000_000

    ts = liburing.timespec(0.5)
    assert ts.sec == 0
    assert ts.nsec == 500_000_000

    ts = liburing.timespec(0)
    assert ts.sec == 0
    assert ts.nsec == 0
    ts.sec = 1
    ts.nsec = 500_000
    assert ts.sec == 1
    assert ts.nsec == 500_000

    with pytest.raises(MemoryError):
        ts = liburing.Timespec()
        assert ts.sec == 123


def test_put_sqe():
    assert _loop(1, 2) is False  # entries < sqe
    assert _loop(2, 2) is True
    assert _loop(8, 2) is True
    with pytest.raises(RuntimeError):
        assert _loop(1, 0) is True
    assert _loop(1024, 1024) is True

    # note: entries is rounded up to the nearest power of `2`
    assert _loop(3, 4) is True
    assert _loop(3, 5) is False
    assert _loop(5, 8) is True


def _loop(entries, num):
    ring = liburing.Ring()
    cqe = liburing.Cqe()
    try:
        assert liburing.io_uring_queue_init(entries, ring) == 0
        sqe = liburing.Sqe(num)
        for i in range(num):
            liburing.io_uring_prep_nop(sqe[i])
            sqe[i].user_data = i
        if liburing.put_sqe(ring, sqe):
            liburing.io_uring_submit(ring)
        else:
            return False
        if num:
            assert liburing.io_uring_wait_cqes(ring, cqe, num) == 0
            for i in range(num):
                assert cqe[i].user_data == i
            liburing.io_uring_cq_advance(ring, num)
        return True
    finally:
        liburing.io_uring_queue_exit(ring)
