from liburing import liburing_major_version, liburing_minor_version, liburing_check_version


def test_liburing_version():
    assert liburing_major_version() == 2
    # assert liburing_minor_version() == 5
    assert liburing_minor_version() == 6
    assert liburing_check_version(3, 0) is True
