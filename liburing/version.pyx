# distutils: language=c


cpdef int liburing_major_version():
    return liburing_major_version_c()

cpdef int liburing_minor_version():
    return liburing_minor_version_c()

cpdef int liburing_check_version(int major, int minor):
    return liburing_check_version_c(major, minor)
