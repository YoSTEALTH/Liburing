cdef class timespec:
    ''' Kernel Timespec

        Example
            >>> ts = timespec(1)        # int
            >>> ts = timespec(1.5)      # float
            >>> io_uring_prep_timeout(sqe, ts, ...)

            # manually set raw value
            >>> ts = timespec()
            >>> ts.tv_sec = 1           # second
            >>> ts.tv_nsec = 500000000  # nanosecond
            >>> io_uring_prep_timeout(sqe, ts, ...)
    '''
    def __cinit__(self, double second=0):
        self.ptr = <__kernel_timespec*>PyMem_RawCalloc(1, sizeof(__kernel_timespec))
        if self.ptr is NULL:
            memory_error(self)
        if second:
            # note: converting from `double` is the reason for casting
            self.ptr.tv_sec = <int64_t>(second / 1)
            self.ptr.tv_nsec = <long long>(((second % 1) * 1_000_000_000) / 1)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def tv_sec(self):
        if self.ptr is NULL:
            memory_error(self)
        return self.ptr.tv_sec

    @tv_sec.setter
    def tv_sec(self, int64_t second):
        if self.ptr is NULL:
            memory_error(self)
        self.ptr.tv_sec = second

    @property
    def tv_nsec(self):
        if self.ptr is NULL:
            memory_error(self)
        return self.ptr.tv_nsec

    @tv_nsec.setter
    def tv_nsec(self, long long nanosecond):
        if self.ptr is NULL:
            memory_error(self)
        self.ptr.tv_nsec = nanosecond


cpdef inline void io_uring_prep_timeout(io_uring_sqe sqe,
                                        timespec ts,
                                        unsigned int count,
                                        unsigned int flags) noexcept nogil:
    __io_uring_prep_timeout(sqe.ptr, ts.ptr, count, flags)

cpdef inline void io_uring_prep_timeout_remove(io_uring_sqe sqe,
                                               __u64 user_data,
                                               unsigned int flags) noexcept nogil:
    __io_uring_prep_timeout_remove(sqe.ptr, user_data, flags)

cpdef inline void io_uring_prep_timeout_update(io_uring_sqe sqe,
                                               timespec ts,
                                               __u64 user_data,
                                               unsigned int flags) noexcept nogil:
    __io_uring_prep_timeout_update(sqe.ptr, ts.ptr, user_data, flags)

cpdef inline void io_uring_prep_link_timeout(io_uring_sqe sqe,
                                             timespec ts,
                                             unsigned int flags) noexcept nogil:
    __io_uring_prep_link_timeout(sqe.ptr, ts.ptr, flags)
