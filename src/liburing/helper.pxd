from libc.string cimport memcpy
from .type cimport bool
from .io_uring cimport io_uring_sqe_t, io_uring_sqe
from .liburing cimport io_uring_get_sqe_c, io_uring_sq_space_left_c, io_uring


cpdef bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe) noexcept nogil
