from liburing.version import liburing_major_version, liburing_minor_version


def test_liburing_version():
    assert liburing_major_version() == 2
    assert liburing_minor_version() == 5
