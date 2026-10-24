from pytest import raises
from liburing import *


def test_trap_error():
    assert trap_error(0) == 0
    assert trap_error(1) == 1

    with raises(BlockingIOError):
        trap_error(-11)

    with raises(OSError):
        trap_error(-1)
