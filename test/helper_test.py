import pytest
import liburing


def test_fds():
    fds = liburing.Fds([-1, -1, 3])
    assert fds[1] == -1
    fds.update([4, 5, 6])
    assert fds[1] == 5

    # error
    pytest.skip("PyOZ bug.")
    with pytest.raises(ValueError):
        fds.update([4, 5, 6, 7, 8, 9])  # PyOZ raises `RuntimeError: ValueError`

    with pytest.raises(TypeError):  # PyOZ raises `RuntimeError: TypeError`
        fds.update([4, 5, "s"])


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
