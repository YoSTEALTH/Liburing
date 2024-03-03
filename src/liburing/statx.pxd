from .lib.uring cimport __statx, __io_uring_prep_statx
from .queue cimport io_uring_sqe


cdef class statx:
    cdef __statx *ptr


cpdef void io_uring_prep_statx(io_uring_sqe sqe,
                               int dfd,
                               const char *path,
                               int flags,
                               unsigned int mask,
                               statx statxbuf) noexcept nogil
