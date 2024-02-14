from re import escape
from pytest import raises
from liburing import trap_error, memory_error, index_error


class MyClass:
    pass


def test_trap_error():
    assert trap_error(0) == 0
    assert trap_error(1) == 1

    with raises(BlockingIOError):
        trap_error(-11)

    with raises(OSError):
        trap_error(-1)


def test_memory_error():
    error = escape('`MyClass()` is out of memory!')
    with raises(MemoryError, match=error):
        memory_error(MyClass())

    error = escape('`MyClass()` message')
    with raises(MemoryError, match=error):
        memory_error(MyClass(), 'message')


def test_index_error():
    error = escape('`MyClass()[1]` out of range!')
    with raises(IndexError, match=error):
        index_error(MyClass(), 1)

    error = escape('`MyClass()[1]` message!')
    with raises(IndexError, match=error):
        index_error(MyClass(), 1, 'message!')

    with raises(OverflowError):
        index_error(MyClass(), -1)
