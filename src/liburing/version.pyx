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
