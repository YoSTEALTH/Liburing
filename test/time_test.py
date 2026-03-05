from pytest import raises
import liburing


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

    with raises(MemoryError):
        ts = liburing.Timespec()
        assert ts.sec == 123
