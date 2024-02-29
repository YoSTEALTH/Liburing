cpdef inline void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil:
    __io_uring_prep_close(sqe.ptr, fd)

cpdef inline void io_uring_prep_close_direct(io_uring_sqe sqe,
                                             unsigned int file_index) noexcept nogil:
    __io_uring_prep_close_direct(sqe.ptr, file_index)
