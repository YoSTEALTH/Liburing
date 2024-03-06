# openat, openat2, accept, ...
IORING_FILE_INDEX_ALLOC = __IORING_FILE_INDEX_ALLOC


cpdef inline void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil:
    __io_uring_prep_close(sqe.ptr, fd)

cpdef inline void io_uring_prep_close_direct(io_uring_sqe sqe,
                                             unsigned int file_index) noexcept nogil:
    __io_uring_prep_close_direct(sqe.ptr, file_index)


cpdef inline void io_uring_prep_provide_buffers(io_uring_sqe sqe,
                                                unsigned char[:] addr,  # void *addr,
                                                int len,
                                                int nr,
                                                int bgid,
                                                int bid=0) noexcept nogil:
    __io_uring_prep_provide_buffers(sqe.ptr, &addr[0], len, nr, bgid, bid)

cpdef inline void io_uring_prep_remove_buffers(io_uring_sqe sqe, int nr, int bgid) noexcept nogil:
    __io_uring_prep_remove_buffers(sqe.ptr, nr, bgid)
