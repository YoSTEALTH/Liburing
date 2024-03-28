cdef class futex_state:
    ''' Futex State - User Address Memory '''
    def __cinit__(self, __u8 num=1, bint private=False):
        '''
            Type
                num:     int
                private: bool
                return:  None

            Example
                >>> futex = futex_state()
                >>> futex.state
                0
                >>> futex.private
                False

                >>> io_uring_prep_futex_wait(sqe, futex)
                >>> futex.state = 1
                >>> io_uring_prep_futex_wake(sqe, futex)

                >>> futex.state = 0
                >>> fwv = futex_waitv(futex)
                >>> io_uring_prep_futex_waitv(sqe, fwv)

            Note
                - By default `MAP_SHARED` is created. Set `futex_state(True)` to use `MAP_PRIVATE`
                and `FUTEX2_PRIVATE`
        '''
        if not __FUTEX2_PRIVATE:
            raise EnvironmentError('Looks like your Linux version does not support `futex2` '
                                   'features. Please updrade to Linux `6.7`+ and try again.')
        if num > 1:
            raise NotImplementedError(f'`{self.__class__.__name__}()` `num > 1`')
        if num > __FUTEX_WAITV_MAX:
            raise ValueError(f'{self.__class__.__name__}(num={num}) > {__FUTEX_WAITV_MAX}')
        self.len = num
        self.private = private
        if num:
            self.ptr = <uint32_t*>mmap(NULL, sizeof(uint32_t) * num, PROT_READ | PROT_WRITE,
                                       MAP_ANONYMOUS | (MAP_PRIVATE if private else MAP_SHARED),
                                       -1, 0)
            if self.ptr == MAP_FAILED:
                memory_error(self, '- `mmap()` not created!')

    def __dealloc__(self):
        if self.len:
            munmap(self.ptr, sizeof(uint32_t) * self.len)
            self.ptr = NULL

    @property
    def state(self) -> uint32_t:
        if self.ptr is NULL:
            memory_error(self, 'memory not set!')
        return self.ptr[0]

    @state.setter
    def state(self, uint32_t value):
        if self.ptr is NULL:
            memory_error(self, 'memory not set!')
        self.ptr[0] = value

    def __repr__(self):
        if self.ptr is NULL:
            return  f'{self.__class__.__name__}(state=NULL, private=NULL)'
        else:
            return  f'{self.__class__.__name__}(state={self.ptr[0]!r}, private={self.private!r})'

cdef class futex_waitv:
    ''' A Waiter For Vectorized Wait '''
    def __cinit__(self, futex_state futex):
        '''
            Type
                futex: futex_state
                return: None

            Flags
                FUTEX2_SIZE_U8
                FUTEX2_SIZE_U16
                FUTEX2_SIZE_U32
                FUTEX2_SIZE_U64
                FUTEX2_NUMA

            Example
                >>> futex = futex_state()
                >>> futex.state = 1

                >>> waiter = futex_waitv(futex)
                >>> waiter.val = 0
                >>> waiter.val
                0

                >>> io_uring_prep_futex_waitv(sqe, waiter, ...)
        '''
        if futex.len > 1:
            raise NotImplementedError(f'`{self.__class__.__name__}()` `waiters > 1`')

        if futex.len:
            self.ptr = <__futex_waitv*>PyMem_RawCalloc(futex.len, sizeof(__futex_waitv))
            if self.ptr is NULL:
                memory_error(self)
            self.ptr.uaddr = <__u64>futex.ptr
            self.private = futex.private
            self.len = futex.len

            if self.private:
                self.ptr.flags = __FUTEX2_PRIVATE

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def val(self):
        if self.ptr is not NULL:
            return self.ptr.val

    @val.setter
    def val(self, __u64 val):
        if self.ptr is not NULL:
            self.ptr.val = val

    @property
    def flags(self):
        if self.ptr is not NULL:
            return self.ptr.flags

    @flags.setter
    def flags(self, __u32 flags):
        if self.ptr is not NULL:
            self.ptr.flags |= flags


cpdef inline void io_uring_prep_futex_wake(io_uring_sqe sqe,
                                           futex_state futex,
                                           uint64_t val,
                                           uint64_t mask,
                                           uint32_t futex_flags) noexcept nogil:
    __io_uring_prep_futex_wake(sqe.ptr, futex.ptr, val, mask, futex_flags, 0)

cpdef inline void io_uring_prep_futex_wait(io_uring_sqe sqe,
                                           futex_state futex,
                                           uint64_t val,
                                           uint64_t mask,
                                           uint32_t futex_flags) noexcept nogil:
    __io_uring_prep_futex_wait(sqe.ptr, futex.ptr, val, mask, futex_flags, 0)

cpdef inline void io_uring_prep_futex_waitv(io_uring_sqe sqe, futex_waitv waiters) noexcept nogil:
    __io_uring_prep_futex_waitv(sqe.ptr, waiters.ptr, waiters.len, 0)
