# linux version
LINUX_VERSION_MAJOR = __LINUX_VERSION_MAJOR
LINUX_VERSION_MINOR = __LINUX_VERSION_MINOR

cpdef inline bool linux_version_check(__u8 major, __u8 minor=0) noexcept nogil:
    ''' Linux Version Check.

        Type
            major:  int
            minor:  int
            return: bool

        Example
            # assuming your linux is 6.7
            >>> linux_version_check(5, 0)
            False
            >>> linux_version_check(6, 6)
            False
            >>> linux_version_check(6, 7)
            False
            >>> linux_version_check(6, 8)
            True
            >>> linux_version_check(7, 0)
            True
    '''
    return (major > __LINUX_VERSION_MAJOR) or ((major == __LINUX_VERSION_MAJOR) and 
                                               (minor > __LINUX_VERSION_MINOR))


# liburing version
cpdef __u8 liburing_version_major():
    ''' Note: `io_uring_major_version` has been renamed to `liburing_version_major` '''
    return __io_uring_major_version()

cpdef __u8 liburing_version_minor():
    ''' Note: `io_uring_minor_version` has been renamed to `liburing_version_minor` '''
    return __io_uring_minor_version()

cpdef bool liburing_version_check(__u8 major, __u8 minor):
    ''' Note: `io_uring_check_version` has been renamed to `liburing_version_check` '''
    return __io_uring_check_version(major, minor)
