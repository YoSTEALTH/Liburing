from .lib.uring cimport *


# linux version
cpdef bool linux_version_check(__u8 major, __u8 minor=?) noexcept nogil

# liburing version
cpdef __u8 liburing_version_major()
cpdef __u8 liburing_version_minor()
cpdef bool liburing_version_check(__u8 major, __u8 minor)
# note: changed C function name from `io_uring_*` to `liburing_*`, as this is 
#       `liburing` library version. `io_uring` is the backend installed into linux.
