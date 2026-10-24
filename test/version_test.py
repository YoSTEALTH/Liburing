import pytest
from liburing import *


def test_liburing_version():
    assert liburing_version_major() >= 2 and liburing_version_minor() >= 4
    # checks if liburing version is == or > than installed version.
    assert liburing_version_check(10, 10) is True
    with pytest.raises(OverflowError):  # ConversionError
        assert liburing_version_check(-1, 10) is False
    with pytest.raises(OverflowError):  # ConversionError
        assert liburing_version_check(1, -2) is False
