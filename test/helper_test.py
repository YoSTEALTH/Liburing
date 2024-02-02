from pytest import raises
from liburing.helper import trap_error


def test_trap_error():
    assert trap_error(0) == 0
    assert trap_error(1) == 1

    with raises(BlockingIOError):
        trap_error(-11)

    with raises(OSError):
        trap_error(-1)
