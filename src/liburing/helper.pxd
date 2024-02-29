from libc.string cimport memcpy
from .lib.uring cimport *
from .queue cimport io_uring, io_uring_sqe


cpdef bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe) noexcept nogil
