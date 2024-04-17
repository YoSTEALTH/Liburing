cpdef inline bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe_s) noexcept nogil:
    ''' Put `io_uring_sqe` into `io_uring` ring's memory.

        Type
            ring:   io_uring
            sqe_s:  io_uring_sqe
            return: bool

        Example
            # single
            >>> sqe = io_uring_sqe()
            >>> io_uring_prep_read(sqe, ...)

            # multiple
            >>> sqe = io_uring_sqe(2)
            >>> io_uring_prep_read(sqe[0], ...)
            >>> io_uring_prep_write(sqe[1], ...)

            # back-end single | multiple
            >>> if io_uring_put_sqe(self.ring, sqe):
            ...     # do stuff

            # failed: `ring` was full, submit and try to again.
            >>> if io_uring_put_sqe(self.ring, sqe):
            ...     io_uring_submit(self.ring)
            ...     if io_uring_put_sqe(self.ring, sqe):
            ...         # do stuff

        Note
            - Returns `False` if queue is full. Will need to `io_uring_submit()` and try again.
            - Returns `False` if `entries` < `len(sqe_s)`
    '''
    cdef:
        __u16           i
        size_t          size
        __io_uring_sqe* sqe

    if sqe_s.len == 0:
        return True
        # note:
        #   - its ok to submit `0` sqe thus `True`
        #   - this also accounts for `ptr` gotten from `io_uring_get_sqe`
        #       as its `len == 0` thus not try to replace memory by mistake!
    else:
        size = sizeof(__io_uring_sqe)
        if sqe_s.len == 1:
            if (sqe := __io_uring_get_sqe(&ring.ptr)) is not NULL:
                memcpy(sqe, sqe_s.ptr, size)
                return True
        elif (ring.ptr.sq.ring_entries >= sqe_s.len
                and __io_uring_sq_space_left(&ring.ptr) >= sqe_s.len):
            for i in range(sqe_s.len):
                if (sqe := __io_uring_get_sqe(&ring.ptr)) is NULL:
                    return False  # this should ever trigger but just in case!
                memcpy(sqe, <void*>&sqe_s.ptr[i], size)
            else:
                return True
        else:
            return False
