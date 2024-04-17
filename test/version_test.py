from liburing import LINUX_VERSION_MAJOR, LINUX_VERSION_MINOR, linux_version_check, \
                     liburing_version_major, liburing_version_minor, liburing_version_check


def test_set_linux_version_define():
    with open('/proc/version', 'rb') as file:
        major, minor, *_ = file.read().split()[2].split(b'.', 2)
    assert LINUX_VERSION_MAJOR == int(major)
    assert LINUX_VERSION_MINOR == int(minor)


def test_linux_version():
    major = LINUX_VERSION_MAJOR
    minor = LINUX_VERSION_MINOR
    assert linux_version_check(f'{major-1 or 1}') is False
    assert linux_version_check(f'{major-1 or 1}.{minor or 1}') is False
    assert linux_version_check(f'{major}.{minor}') is False  # current linux version
    assert linux_version_check(major+1) is True
    assert linux_version_check(float(f'{major+1}.{minor or 1}')) is True


def test_liburing_version():
    assert liburing_version_major() >= 2 and liburing_version_minor() >= 4
    # checks if liburing version is == or > than installed version.
    assert liburing_version_check(10, 10) is True
