import pytest
from liburing import trap_error


def test_trap_error():
    assert trap_error(0) == 0
    assert trap_error(1) == 1
    assert trap_error(222) == 222

    with pytest.raises(BlockingIOError):
        trap_error(-11)
