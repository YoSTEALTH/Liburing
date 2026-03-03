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

    # class
    with raises(MemoryError):
        ts = liburing.kernel_timespec()
        assert ts.sec == 123

    # TODO: test bottom with io_uring
    # ts = liburing.timespec(-1.87)

    # assert False
