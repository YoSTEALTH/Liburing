cpdef int liburing_version_major():
    return io_uring_major_version_c()

cpdef int liburing_version_minor():
    return io_uring_minor_version_c()

cpdef bool liburing_version_check(int major, int minor):
    return io_uring_check_version_c(major, minor)
