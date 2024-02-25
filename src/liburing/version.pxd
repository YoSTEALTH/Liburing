from .lib.uring cimport *


# note: changed C function name from `io_uring_*` to `liburing_*`, as this is 
#       `liburing` library version. `io_uring` is the backend installed into linux.
cpdef int liburing_version_major()
cpdef int liburing_version_minor()
cpdef bool liburing_version_check(int major, int minor)
