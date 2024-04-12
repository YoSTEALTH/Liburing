cpdef inline bool io_uring_put_sqe(io_uring ring, io_uring_sqe sqe_s) noexcept:
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
    '''
    cdef:
        __u32           i
        size_t          size
        io_uring_sqe    sqe
        __io_uring_sqe* _sqe

    if sqe_s.len == 0:
        return True
        # note:
        #   - its ok to submit `0` sqe thus `True`
        #   - this also accounts for `ptr` gotten from `io_uring_get_sqe`
        #       as its `len == 0` thus not try to copy memory
    else:
        size = sizeof(__io_uring_sqe)
        if sqe_s.len == 1:
            if (_sqe := __io_uring_get_sqe(ring.ptr)) is not NULL:
                memcpy(_sqe, sqe_s.ptr, size)
                return True
        elif __io_uring_sq_space_left(ring.ptr) >= sqe_s.len:
            for i in range(sqe_s.len):
                if (_sqe := __io_uring_get_sqe(ring.ptr)) is NULL:
                    return False  # is triggered when submitting `> entries` can handle!
                    # TODO: maybe need to set some kind of flag to continue where it was left off?
                sqe = sqe_s[i]
                memcpy(_sqe, sqe.ptr, size)
            else:
                return True
