from liburing import liburing_version_major, liburing_version_minor, liburing_version_check


def test_liburing_version():
    assert liburing_version_major() >= 2 and liburing_version_minor() >= 4
    # checks if liburing version is == or > than installed version.
    assert liburing_version_check(5, 0) is True
