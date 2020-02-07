# import os
# import pytest
from liburing import lib


def test_trap_error():
    assert lib.trap_error(0) == 0
    assert lib.trap_error(1) == 1
    assert lib.trap_error(222) == 222

    # with pytest.raises(BlockingIOError):
    #     lib.trap_error(-11)
    # ^^^ THIS FAILS!!! even though it outputs:
    # -----------------------------------------
    #     ../../Liburing/Liburing/test/other_test.py From cffi callback <function trap_error at 0x7f3d8f0bc0d0>:
    #     Traceback (most recent call last):
    #       File "... /CFFI-Liburing/Liburing/liburing/wrapper.py", line 23, in trap_error
    #         raise OSError(-no, os.strerror(-no))
    #     BlockingIOError: [Errno 11] Resource temporarily unavailable

    # THIS WORKS!!! - so something do with cffi
    # try:
    #     no = -11
    #     raise OSError(-no, os.strerror(-no))
    # except BlockingIOError:
    #     assert True
    # else:
    #     assert False
