# from .type cimport bool

cdef extern from * nogil:
    ctypedef bint   bool


cdef extern from 'liburing.h' nogil:
    # changed these function name from `io_uring_*` to `liburing_*`,
    # as this is `liburing` library. `io_uring` is the backend installed into linux.
    int liburing_major_version_c "io_uring_major_version"()
    int liburing_minor_version_c "io_uring_minor_version"()
    bool liburing_check_version_c "io_uring_check_version"(int major, int minor)


cpdef int liburing_major_version()
cpdef int liburing_minor_version()
cpdef int liburing_check_version(int major, int minor)
