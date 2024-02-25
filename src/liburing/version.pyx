cpdef int liburing_version_major():
    ''' Note: `io_uring_major_version` has been renamed to `liburing_version_major` '''
    return __io_uring_major_version()

cpdef int liburing_version_minor():
    ''' Note: `io_uring_minor_version` has been renamed to `liburing_version_minor` '''
    return __io_uring_minor_version()

cpdef bool liburing_version_check(int major, int minor):
    ''' Note: `io_uring_check_version` has been renamed to `liburing_version_check` '''
    return __io_uring_check_version(major, minor)
