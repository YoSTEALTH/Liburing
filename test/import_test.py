import os
from liburing import O_CREAT, AT_FDCWD


def test_import():
    assert os.O_CREAT == O_CREAT
    assert -100 == AT_FDCWD
