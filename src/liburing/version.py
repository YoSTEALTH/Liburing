from functools import lru_cache


LINUX_VERSION_MAJOR = 0
LINUX_VERSION_MINOR = 0


def _set_linux_version():
    global LINUX_VERSION_MAJOR, LINUX_VERSION_MINOR
    if not LINUX_VERSION_MAJOR:
        with open('/proc/version', 'rb') as file:
            data = file.read()
        major, minor, *_ = data.split()[2].split(b'.', 2)
        LINUX_VERSION_MAJOR = int(major)
        LINUX_VERSION_MINOR = int(minor)


_set_linux_version()  # init


@lru_cache
def linux_version_check(version):
    ''' Linux Version Check.

        Type
            version:  str | int | float
            return: bool

        Example
            # assuming your linux is 6.7
            >>> linux_version_check(5)
            False
            >>> linux_version_check('6.6')
            False
            >>> linux_version_check(6.7)
            False
            >>> linux_version_check(6.8)
            True
            >>> linux_version_check(7.0)
            True
    '''
    major, minor = map(int, str(float(version)).split('.'))  # '6.7' -> 6 7
    return (major > LINUX_VERSION_MAJOR) or ((major == LINUX_VERSION_MAJOR) and
                                             (minor > LINUX_VERSION_MINOR))
