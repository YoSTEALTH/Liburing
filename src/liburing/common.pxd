from .lib.uring cimport __io_uring_prep_close, __io_uring_prep_close_direct, \
                        __io_uring_prep_provide_buffers, __io_uring_prep_remove_buffers
from .queue cimport io_uring_sqe


cpdef void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil
cpdef void io_uring_prep_close_direct(io_uring_sqe sqe, unsigned int file_index) noexcept nogil

cpdef void io_uring_prep_provide_buffers(io_uring_sqe sqe,
                                         unsigned char[:] addr,
                                         int len,
                                         int nr,
                                         int bgid,
                                         int bid=?) noexcept nogil
cpdef void io_uring_prep_remove_buffers(io_uring_sqe sqe, int nr, int bgid) noexcept nogil
