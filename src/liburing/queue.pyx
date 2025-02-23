cdef class io_uring:
    ''' I/O URing

        Example
            >>> ring = io_uring()
            >>> io_uring_queue_init(123, ring)
            >>> io_uring_queue_exit(ring)
    '''
    @property
    def flags(self)-> __u32:
        if self.active:
            return self.ptr.flags

    @property
    def ring_fd(self)-> __s32:
        if self.active:
            return self.ptr.ring_fd

    @property
    def features(self)-> __u32:
        if self.active:
            return self.ptr.features

    @property
    def enter_ring_fd(self)-> __s32:
        if self.active:
            return self.ptr.enter_ring_fd

    @property
    def int_flags(self)-> __u8:
        if self.active:
            return self.ptr.int_flags

    def __repr__(self)-> str:
        if self.active:
            return f'{self.__class__.__name__}(flags={self.ptr.flags!r}, ' \
                   f'ring_fd={self.ptr.ring_fd!r}, features={self.ptr.features!r}, ' \
                   f'enter_ring_fd={self.ptr.enter_ring_fd!r}, int_flags={self.ptr.int_flags!r}) '
        return super().__repr__()


cdef class io_uring_sqe:
    ''' IO submission data structure (Submission Queue Entry)

        Example
            # single
            >>> sqe = io_uring_sqe()
            >>> io_uring_prep_read(sqe, ...)

            # multiple
            >>> sqe = io_uring_sqe(2)
            >>> io_uring_prep_write(sqe[0], ...)
            >>> io_uring_prep_read(sqe[1], ...)

            # *** MUST DO ***
            >>> if io_uring_put_sqe(ring, sqe):
            ...     io_uring_submit(ring)

        Note
            - `io_uring_sqe` is not the same as `io_uring_get_sqe()`.
            - This class has dual usage:
                1. It works as a base class for `io_uring_get_sqe()` return.
                2. It can also be used as `sqe = io_uring_sqe(<int>)`, rather than "get" sqe(s)
                you are going to "put" pre-made sqe(s) into the ring later. Refer to
                `help(io_uring_put_sqe)` to see more detail.
    '''
    def __cinit__(self, __u16 num=1, *args, **kwargs):
        cdef unicode msg
        if num:
            if num > 1024:
                msg = f'`{self.__class__.__name__}(num)` is limited to 1024, received {num!r}'
                raise ValueError(msg)
            self.ptr = <__io_uring_sqe*>PyMem_RawCalloc(num, sizeof(__io_uring_sqe))
            if self.ptr is NULL:
                memory_error(self)
            if num > 1:
                self.ref = [None]*(num-1)  # does not hold index `0` reference.
            self.len = num
            # note: if `self.len` is not set it means its for internally `ptr` reference use.

    def __dealloc__(self):
        if self.len and self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __bool__(self):
        return self.ptr is not NULL

    def __len__(self):
        return self.len

    def __getitem__(self, unsigned int index):
        cdef io_uring_sqe sqe
        if self.ptr is not NULL:
            if index == 0:
                return self
            elif self.len and index < self.len:
                if (sqe := self.ref[index-1]) is not None:
                    return sqe  # return from reference cache
                # create new reference class
                sqe = io_uring_sqe(0)  # `0` is set to indicated `ptr` memory is not managed
                sqe.ptr = &self.ptr[index]
                self.ref[index-1] = sqe  # cache sqe as this class attribute
                return sqe
        index_error(self, index, 'out of `sqe`')

    @property
    def flags(self) -> unsigned:
        return self.ptr.flags

    @flags.setter
    def flags(self, unsigned int flags):
        __io_uring_sqe_set_flags(self.ptr, flags)

    @property
    def user_data(self) -> __u64:
        return self.ptr.user_data

    @user_data.setter
    def user_data(self, __u64 data):
        cdef unicode msg
        if data != 0:
            __io_uring_sqe_set_data64(self.ptr, data)
        else:
            msg = f'`{self.__class__.__name__}.user_data` can not be {data!r}'
            raise ValueError(msg)


cdef class io_uring_cqe:
    ''' IO completion data structure (Completion Queue Entry)

        Example
            >>> cqes = io_uring_cqe()

            # single
            # ------
            >>> cqe = cqes  # same as `cqes[0]`
            >>> cqe.res
            0
            >>> cqe.flags
            0
            >>> cqe.user_data
            123

            # get item
            # --------
            >>> cqes[0].user_data
            123

            # iter
            # ----
            >>> ready = io_uring_cq_ready(ring)
            >>> for i in range(ready):
            ...     cqe = cqes[i]
            ...     cqe.user_data
            ...     io_uring_cq_advance(ring, 1)
            123

        Note
            - `cqes = io_uring_cqe()` only needs to be defined once, and reused.
            - Use `io_uring_cq_ready(ring)` to figure out how many cqe's are ready.
    '''
    def __cinit__(self):
        self.ptr = NULL

    def __getitem__(self, unsigned int index):
        cdef io_uring_cqe cqe
        if self.ptr is not NULL and self.ptr.user_data:
            if index == 0:
                return self
            elif self.ptr[index].user_data:
                cqe = io_uring_cqe()
                cqe.ptr = &self.ptr[index]
                return cqe
        index_error(self, index, 'out of `cqe`')
        # note: no need to cache items since `cqe` is normally called once or passed around.

    def __bool__(self):
        if self.ptr is NULL:
            return False
        return True if self.ptr.user_data else False

    def __repr__(self):
        if self.ptr is not NULL and self.ptr.user_data:
            return f'{self.__class__.__name__}(user_data={self.ptr.user_data!r}, ' \
                   f'res={self.ptr.res!r}, flags={self.ptr.flags!r})'
        return super().__repr__()

    @property
    def user_data(self) -> __u64:
        if self.ptr is not NULL and self.ptr.user_data:
            return self.ptr.user_data
        memory_error(self, 'out of `cqe`')

    @property
    def res(self) -> __s32:
        if self.ptr is not NULL and self.ptr.user_data:
            return self.ptr.res
        memory_error(self, 'out of `cqe`')

    @property
    def flags(self) -> __u32:
        if self.ptr is not NULL and self.ptr.user_data:
            return self.ptr.flags
        memory_error(self, 'out of `cqe`')

    cdef inline tuple[__s32, __u64] get_index(self, unsigned int index) noexcept nogil:
        ''' Get Index

            Example
                >>> index = 1
                >>> res, user_data = cqe.get_index(index)
                >>> if user_data:
                ...     res, user_data
                0 123

            Note
                - Just like `__getitem__` but faster!
        '''
        if self.ptr is not NULL:
            return self.ptr[index].res, self.ptr[index].user_data
        return 0, 0


# TODO:
cdef class siginfo:
    pass

cdef class sigset:
    pass


cpdef int io_uring_queue_init_mem(unsigned int entries,
                                  io_uring ring,
                                  io_uring_params p,
                                  unsigned char[:] buf,
                                  size_t buf_size):
    if ring.active:
        raise RuntimeError('`io_uring_queue_init_mem(ring)` already initialized!')
    ring.active = True
    return trap_error(__io_uring_queue_init_mem(entries, &ring.ptr, p.ptr, &buf[0], buf_size))

cpdef int io_uring_queue_init_params(unsigned int entries, io_uring ring, io_uring_params p) nogil:
    if ring.active:
        raise RuntimeError('`io_uring_queue_init_params(ring)` already initialized!')
    ring.active = True
    return trap_error(__io_uring_queue_init_params(entries, &ring.ptr, p.ptr))

cpdef int io_uring_queue_init(unsigned int entries, io_uring ring, unsigned int flags=0) nogil:
    ''' Setup `io_uring` Submission & Completion Queues

        Example
            >>> ring = io_uring()
            >>> try:
            ...     io_uring_queue_init(1024, ring)
            ...     # do stuff ...
            >>> finally:
            ...     io_uring_queue_exit(ring)
    '''
    if ring.active:
        raise RuntimeError('`io_uring_queue_init(ring)` already initialized!')
    ring.active = True
    return trap_error(__io_uring_queue_init(entries, &ring.ptr, flags))

cpdef int io_uring_queue_mmap(int fd,
                              io_uring_params p,
                              io_uring ring) nogil:
    return trap_error(__io_uring_queue_mmap(fd, p.ptr, &ring.ptr))

cpdef int io_uring_ring_dontfork(io_uring ring) nogil:
    return trap_error(__io_uring_ring_dontfork(&ring.ptr))

cpdef int io_uring_queue_exit(io_uring ring) nogil:
    if not ring.active:
        raise RuntimeError('`io_uring_queue_exit(ring)` already exited!')
    __io_uring_queue_exit(&ring.ptr)
    ring.active = False

cpdef unsigned int io_uring_peek_batch_cqe(io_uring ring,
                                           io_uring_cqe cqes,
                                           unsigned int count) nogil:
    '''
        WARNING: currently there is a bug with `io_uring_peek_batch_cqe()` leading to segfault!!!
    '''
    return trap_error(__io_uring_peek_batch_cqe(&ring.ptr, &cqes.ptr, count))

cpdef int io_uring_wait_cqes(io_uring ring,
                             io_uring_cqe cqe_ptr,
                             unsigned int wait_nr,
                             timespec ts=None,
                             sigset sigmask=None) nogil:
    return trap_error(__io_uring_wait_cqes(&ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, sigmask.ptr))

cpdef int io_uring_wait_cqes_min_timeout(io_uring ring,
                                         io_uring_cqe cqe_ptr,
                                         unsigned int wait_nr,
                                         timespec ts,
                                         unsigned int min_ts_usec,
                                         sigset sigmask=None) nogil:
    return trap_error(__io_uring_wait_cqes_min_timeout(&ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, min_ts_usec, sigmask.ptr))

cpdef int io_uring_wait_cqe_timeout(io_uring ring, io_uring_cqe cqe_ptr, timespec ts) nogil:
    return trap_error(__io_uring_wait_cqe_timeout(&ring.ptr, &cqe_ptr.ptr, ts.ptr))

cpdef int io_uring_submit(io_uring ring) nogil:
    return trap_error(__io_uring_submit(&ring.ptr))

cpdef int io_uring_submit_and_wait(io_uring ring, unsigned int wait_nr) nogil:
    return trap_error(__io_uring_submit_and_wait(&ring.ptr, wait_nr))

cpdef int io_uring_submit_and_wait_timeout(io_uring ring,
                                           io_uring_cqe cqe_ptr,
                                           unsigned int wait_nr,
                                           timespec ts=None,
                                           sigset sigmask=None) nogil:
    return trap_error(__io_uring_submit_and_wait_timeout(&ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, sigmask.ptr))

cpdef int io_uring_submit_and_wait_min_timeout(io_uring ring,
                                               io_uring_cqe cqe_ptr,
                                               unsigned int wait_nr,
                                               timespec ts,
                                               unsigned int min_wait,
                                              sigset sigmask=None) nogil:
    return trap_error(__io_uring_submit_and_wait_min_timeout(&ring.ptr,
                                                             &cqe_ptr.ptr,
                                                             wait_nr,
                                                             ts.ptr,
                                                             min_wait,
                                                             sigmask.ptr))

cpdef int io_uring_submit_and_wait_reg(io_uring ring, io_uring_cqe cqe_ptr, unsigned int wait_nr, int reg_index) nogil:
    return trap_error(__io_uring_submit_and_wait_reg(&ring.ptr, &cqe_ptr.ptr, wait_nr, reg_index))

cpdef int io_uring_register_wait_reg(io_uring ring, io_uring_reg_wait reg, int nr) nogil:
    return trap_error(__io_uring_register_wait_reg(&ring.ptr, reg.ptr, nr))

cpdef int io_uring_resize_rings(io_uring ring, io_uring_params p) nogil:
    return trap_error(__io_uring_resize_rings(&ring.ptr, p.ptr))

cpdef int io_uring_clone_buffers_offset(io_uring dst,
                                        io_uring src,
                                        unsigned int dst_off,
                                        unsigned int src_off,
                                        unsigned int nr,
                                        unsigned int flags) nogil:
    return trap_error(__io_uring_clone_buffers_offset(&dst.ptr, &src.ptr, dst_off, src_off, nr, flags))

cpdef int io_uring_clone_buffers(io_uring dst, io_uring src) nogil:
    return trap_error(__io_uring_clone_buffers(&dst.ptr, &src.ptr))

cpdef int io_uring_enable_rings(io_uring ring) nogil:
    return trap_error(__io_uring_enable_rings(&ring.ptr))

cpdef int io_uring_close_ring_fd(io_uring ring) nogil:
    return trap_error(__io_uring_close_ring_fd(&ring.ptr))


cpdef int io_uring_get_events(io_uring ring) nogil:
    return trap_error(__io_uring_get_events(&ring.ptr))

cpdef int io_uring_submit_and_get_events(io_uring ring) nogil:
    return trap_error(__io_uring_submit_and_get_events(&ring.ptr))

cpdef int io_uring_buf_ring_head(io_uring ring, int buf_group, uint16_t head) nogil:
    return trap_error(__io_uring_buf_ring_head(&ring.ptr, buf_group, &head))

cpdef inline void io_uring_cq_advance(io_uring ring, unsigned int nr) noexcept nogil:
    __io_uring_cq_advance(&ring.ptr, nr)

cpdef inline void io_uring_cqe_seen(io_uring ring, io_uring_cqe cqe) noexcept nogil:
    __io_uring_cqe_seen(&ring.ptr, cqe.ptr)


# Command prep helpers
# --------------------
cpdef inline void io_uring_sqe_set_data(io_uring_sqe sqe, object obj):
    Py_INCREF(obj)
    __io_uring_sqe_set_data(sqe.ptr, <void*>obj)

cpdef inline object io_uring_cqe_get_data(io_uring_cqe cqe):
    cdef object obj = <object>__io_uring_cqe_get_data(cqe.ptr)
    Py_DECREF(obj)
    return obj


cpdef inline void io_uring_sqe_set_data64(io_uring_sqe sqe, __u64 data) noexcept nogil:
    __io_uring_sqe_set_data64(sqe.ptr, data)

cpdef inline __u64 io_uring_cqe_get_data64(io_uring_cqe cqe) noexcept nogil:
    return __io_uring_cqe_get_data64(cqe.ptr)

cpdef inline void io_uring_sqe_set_flags(io_uring_sqe sqe, unsigned int flags) noexcept nogil:
    __io_uring_sqe_set_flags(sqe.ptr, flags)

cpdef inline void io_uring_sqe_set_buf_group(io_uring_sqe sqe, int bgid) noexcept nogil:
    __io_uring_sqe_set_buf_group(sqe.ptr, bgid)
    
cpdef inline void io_uring_initialize_sqe(io_uring_sqe sqe) noexcept nogil:
    __io_uring_initialize_sqe(sqe.ptr)

cpdef inline void io_uring_prep_nop(io_uring_sqe sqe) noexcept nogil:
    __io_uring_prep_nop(sqe.ptr)

cpdef inline void io_uring_prep_cancel64(io_uring_sqe sqe,
                                         __u64 user_data,
                                         int flags) noexcept nogil:
    __io_uring_prep_cancel64(sqe.ptr, user_data, flags)

cpdef inline void io_uring_prep_cancel(io_uring_sqe sqe,
                                       object user_data,
                                       int flags) noexcept:
    Py_INCREF(user_data)
    __io_uring_prep_cancel(sqe.ptr, <void*>user_data, flags)

cpdef inline void io_uring_prep_cancel_fd(io_uring_sqe sqe,
                                          int fd,
                                          unsigned int flags) noexcept nogil:
    __io_uring_prep_cancel_fd(sqe.ptr, fd, flags)

cpdef inline void io_uring_prep_waitid(io_uring_sqe sqe,
                                       idtype_t     idtype,
                                       id_t         id,
                                       siginfo      infop,
                                       int          options,
                                       unsigned int flags) noexcept nogil:
    __io_uring_prep_waitid(sqe.ptr, idtype, id, infop.ptr, options, flags)

cpdef inline void io_uring_prep_fixed_fd_install(io_uring_sqe sqe,
                                                 int          fd,
                                                 unsigned int flags) noexcept nogil:
    __io_uring_prep_fixed_fd_install(sqe.ptr, fd, flags)

cpdef inline unsigned int io_uring_sq_ready(io_uring ring) noexcept nogil:
    return __io_uring_sq_ready(&ring.ptr)

cpdef inline unsigned int io_uring_sq_space_left(io_uring ring) noexcept nogil:
    return __io_uring_sq_space_left(&ring.ptr)

cpdef inline int io_uring_sqring_wait(io_uring ring) noexcept nogil:
    return __io_uring_sqring_wait(&ring.ptr)

cpdef inline unsigned int io_uring_cq_ready(io_uring ring) noexcept nogil:
    return __io_uring_cq_ready(&ring.ptr)

cpdef inline bool io_uring_cq_has_overflow(io_uring ring) noexcept nogil:
    return __io_uring_cq_has_overflow(&ring.ptr)

cpdef inline bool io_uring_cq_eventfd_enabled(io_uring ring) noexcept nogil:
    return __io_uring_cq_eventfd_enabled(&ring.ptr)

cpdef inline int io_uring_cq_eventfd_toggle(io_uring ring,
                                            bool enabled) noexcept nogil:
    return __io_uring_cq_eventfd_toggle(&ring.ptr, enabled)

cpdef inline int io_uring_wait_cqe_nr(io_uring ring,
                                      io_uring_cqe cqe_ptr,
                                      unsigned int wait_nr) noexcept nogil:
    return __io_uring_wait_cqe_nr(&ring.ptr, &cqe_ptr.ptr, wait_nr)

cpdef inline int io_uring_peek_cqe(io_uring ring,
                                   io_uring_cqe cqe_ptr) noexcept nogil:
    return __io_uring_peek_cqe(&ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_wait_cqe(io_uring ring,
                                   io_uring_cqe cqe_ptr) noexcept nogil:
    return __io_uring_wait_cqe(&ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_buf_ring_mask(__u32 ring_entries) noexcept nogil:
    return __io_uring_buf_ring_mask(ring_entries)

cpdef inline void io_uring_buf_ring_init(io_uring_buf_ring br) noexcept nogil:
    __io_uring_buf_ring_init(br.ptr)

cpdef inline void io_uring_buf_ring_add(io_uring_buf_ring br,
                                        unsigned char[:] addr,  # void *addr,
                                        unsigned int len,
                                        unsigned short bid,
                                        int mask,
                                        int buf_offset) noexcept nogil:
    __io_uring_buf_ring_add(br.ptr, &addr[0], len, bid, mask, buf_offset)

cpdef inline void io_uring_buf_ring_advance(io_uring_buf_ring br,
                                            int count) noexcept nogil:
    __io_uring_buf_ring_advance(br.ptr, count)

cpdef inline void io_uring_buf_ring_cq_advance(io_uring ring,
                                               io_uring_buf_ring br,
                                               int count) noexcept nogil:
    __io_uring_buf_ring_cq_advance(&ring.ptr, br.ptr, count)

cpdef inline int io_uring_buf_ring_available(io_uring ring,
                                             io_uring_buf_ring br,
                                             unsigned short bgid) noexcept nogil:
    return __io_uring_buf_ring_available(&ring.ptr, br.ptr, bgid)

cpdef inline io_uring_sqe io_uring_get_sqe(io_uring ring):
    cdef io_uring_sqe sqe = io_uring_sqe(0)
    sqe.ptr = __io_uring_get_sqe(&ring.ptr)
    return sqe

cpdef inline unsigned int io_uring_for_each_cqe(io_uring ring, io_uring_cqe cqe) noexcept nogil:
    '''
        Example
            >>> for i in range(io_uring_for_each_cqe(ring, cqe)):
            ...     cqe[i].res, cqe[i].user_data
            123, 123
    '''
    return __io_uring_for_each_cqe(&ring.ptr, cqe.ptr)
