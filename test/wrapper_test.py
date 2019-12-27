import pytest
import liburing


def test_func_does_not_exit():
    with pytest.raises(AttributeError):
        liburing.call_function_that_does_not_exist()


def test_func_not_in_lib():
    @liburing.cwrap(None)
    def bad_function():
        pass

    with pytest.raises(liburing.wrapper.FunctionNotFoundError):
        bad_function()
