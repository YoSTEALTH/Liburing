from .lib.uring cimport __io_uring_prep_close, __io_uring_prep_close_direct
from .queue cimport io_uring_sqe


cpdef void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil
cpdef void io_uring_prep_close_direct(io_uring_sqe sqe, unsigned int file_index) noexcept nogil
