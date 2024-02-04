from liburing import liburing_major_version, liburing_minor_version, liburing_check_version


def test_liburing_version():
    assert liburing_major_version() >= 2 and liburing_minor_version() >= 4
    # checks if liburing version is == or > than installed version.
    assert liburing_check_version(5, 0) is True
