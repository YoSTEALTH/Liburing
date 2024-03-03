cdef class statx:
    # TODO
    pass


cpdef inline void io_uring_prep_statx(io_uring_sqe sqe,
                                      int dfd,
                                      const char *path,
                                      int flags,
                                      unsigned int mask,
                                      statx statxbuf) noexcept nogil:
    __io_uring_prep_statx(sqe.ptr, dfd, path, flags, mask, statxbuf.ptr)
