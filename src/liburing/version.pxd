from .type cimport bool


cdef extern from 'liburing.h' nogil:
    int io_uring_major_version_c "io_uring_major_version"()
    int io_uring_minor_version_c "io_uring_minor_version"()
    bool io_uring_check_version_c "io_uring_check_version"(int major, int minor)
    # note: changed C function name from `io_uring_*` to `liburing_*`, as this is 
    #       `liburing` library. `io_uring` is the backend installed into linux.


cpdef int liburing_version_major()
cpdef int liburing_version_minor()
cpdef bool liburing_version_check(int major, int minor)
