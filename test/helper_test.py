import re
import pytest
from liburing import trap_error, memory_error


def test_trap_error():
    assert trap_error(0) == 0
    assert trap_error(1) == 1

    with pytest.raises(BlockingIOError):
        trap_error(-11)

    with pytest.raises(OSError):
        trap_error(-1)


def test_memory_error():
    class MyClass:
        pass

    error = re.escape('`MyClass()` is out of memory!')
    with pytest.raises(MemoryError, match=error):
        memory_error(MyClass())
