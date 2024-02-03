# distutils: language=c


cpdef int liburing_major_version():
    return io_uring_major_version_c()

cpdef int liburing_minor_version():
    return io_uring_minor_version_c()

cpdef bool liburing_check_version(int major, int minor):
    return io_uring_check_version_c(major, minor)
