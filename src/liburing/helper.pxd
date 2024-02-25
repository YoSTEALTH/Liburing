from libc.string cimport memcpy
from .lib.uring cimport *
from ._io_uring cimport io_uring_sqe
from .queue cimport io_uring

cpdef bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe) noexcept nogil
