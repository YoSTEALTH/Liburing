cpdef inline bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe) noexcept nogil:
    ''' Put `io_uring_sqe` into `io_uring` ring's memory.

        Type
            ring:   io_uring
            sqe:    io_uring_sqe
            return: bool

        Example
            # single
            >>> sqe = io_uring_sqe()
            >>> io_uring_prep_read(sqe, ...)

            # multiple
            >>> sqe = io_uring_sqe(2)
            >>> io_uring_prep_read(sqe[0], ...)
            >>> io_uring_prep_read(sqe[1], ...)

            # back-end (single | multiple)
            >>> if io_uring_put_sqe(ring, sqe):
            ...     io_uring_submit(ring)
            ...     ...
            >>> else:
            ...     # failed: `ring` was full, submit and try to again.
            ...     io_uring_submit(ring)
            ...     io_uring_put_sqe(ring, sqe)
            ...     ...

        Note
            - Returns `False` if queue is full. Will need to `io_uring_submit()` and try again.
            - `io_uring_sqe()` will auto delete memory used for `sqe` if not referenced/reused.
    '''
    cdef unsigned int size = sizeof(io_uring_sqe_t)
    cdef unsigned int sqe_left = io_uring_sq_space_left_c(ring.ptr)

    if sqe_left >= sqe.len:
        for i in range(sqe.len):
            memcpy(io_uring_get_sqe_c(ring.ptr), &sqe.ptr[i], size)
        return True
