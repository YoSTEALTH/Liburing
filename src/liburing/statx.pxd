from .queue cimport *


cdef class statx:
    cdef __statx *ptr


cpdef void io_uring_prep_statx(io_uring_sqe sqe,
                               statx statxbuf,
                               const char *path,
                               int flags=?,
                               unsigned int mask=?,
                               int dfd=?) noexcept nogil
