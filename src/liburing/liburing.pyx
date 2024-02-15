from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from cpython.ref cimport Py_INCREF, Py_DECREF


cdef class io_uring:
    ''' I/O URing

        Example
            >>> ring = io_uring()
            >>> io_uring_queue_init(123, ring, 0)
            >>> io_uring_queue_exit(ring)
    '''
    def __cinit__(self):
        # note: set initial struct io_uring values to `0` so `ring.ring_fd` can be checked to be true on exit.
        self.ptr = <io_uring_t*>PyMem_RawCalloc(1, sizeof(io_uring_t))
        if self.ptr is NULL:
            memory_error(self)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def flags(self):
        return self.ptr.flags

    @property
    def ring_fd(self):
        return self.ptr.ring_fd

    @property
    def features(self):
        return self.ptr.features

    @property
    def enter_ring_fd(self):
        return self.ptr.enter_ring_fd

    @property
    def int_flags(self):
        return self.ptr.int_flags

    def __repr__(self):
        return f'{self.__class__.__name__}(flags={self.ptr.flags!r}, ring_fd={self.ptr.ring_fd!r}, ' \
               f'features={self.ptr.features!r}, enter_ring_fd={self.ptr.enter_ring_fd!r}, ' \
               f'int_flags={self.ptr.int_flags!r}) '


# TODO:
# cpdef int io_uring_queue_init_mem(unsigned int entries,
#                                   io_uring ring,
#                                   io_uring_params p,
#                                   nullptr_t buf,
#                                   size_t buf_size):
#     return trap_error(io_uring_queue_init_mem_c(entries, ring.ptr, p.ptr, &buf, buf_size))

cpdef int io_uring_queue_init_params(unsigned int entries,
                                     io_uring ring,
                                     io_uring_params p) nogil:
    return trap_error(io_uring_queue_init_params_c(entries, ring.ptr, p.ptr))

cpdef int io_uring_queue_init(unsigned int entries,
                              io_uring ring,
                              unsigned int flags=0) nogil:
    ''' Setup `io_uring` Submission & Completion Queues

        Example
            >>> ring = io_uring()
            >>> try:
            ...     io_uring_queue_init(1024, ring)
            ...     # do stuff
            >>> finally:
            ...     io_uring_queue_exit(ring)
    '''
    return trap_error(io_uring_queue_init_c(entries, ring.ptr, flags))

cpdef int io_uring_queue_mmap(int fd,
                              io_uring_params p,
                              io_uring ring) nogil:
    return trap_error(io_uring_queue_mmap_c(fd, p.ptr, ring.ptr))

cpdef int io_uring_ring_dontfork(io_uring ring) nogil:
    return trap_error(io_uring_ring_dontfork_c(ring.ptr))

cpdef void io_uring_queue_exit(io_uring ring) noexcept nogil:
    io_uring_queue_exit_c(ring.ptr)

cpdef unsigned int io_uring_peek_batch_cqe(io_uring ring, io_uring_cqe cqes, unsigned int count) nogil:
    return io_uring_peek_batch_cqe_c(ring.ptr, &cqes.ptr, count)

cpdef int io_uring_wait_cqes(io_uring ring, io_uring_cqe cqe_ptr, unsigned int wait_nr, timespec ts,
                             sigset_t sigmask) nogil:
    return trap_error(io_uring_wait_cqes_c(ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, &sigmask))

cpdef int io_uring_wait_cqe_timeout(io_uring ring, io_uring_cqe cqe_ptr, timespec ts) nogil:
    return trap_error(io_uring_wait_cqe_timeout_c(ring.ptr, &cqe_ptr.ptr, ts.ptr))

cpdef int io_uring_submit(io_uring ring) nogil:
    return trap_error(io_uring_submit_c(ring.ptr))

cpdef int io_uring_submit_and_wait(io_uring ring, unsigned int wait_nr) nogil:
    return trap_error(io_uring_submit_and_wait_c(ring.ptr, wait_nr))

cpdef int io_uring_submit_and_wait_timeout(io_uring ring,
                                           io_uring_cqe cqe_ptr,
                                           unsigned int wait_nr,
                                           timespec ts,
                                           sigset_t sigmask) nogil:
    return trap_error(io_uring_submit_and_wait_timeout_c(ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, &sigmask))


cpdef int io_uring_get_events(io_uring ring) nogil:
    return trap_error(io_uring_get_events_c(ring.ptr))

cpdef int io_uring_submit_and_get_events(io_uring ring) nogil:
    return trap_error(io_uring_submit_and_get_events_c(ring.ptr))

#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset_t sig) nogil:
    return trap_error(io_uring_enter_c(fd, to_submit, min_complete, flags, &sig))

cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset_t sig,
                          size_t sz) nogil:
    return trap_error(io_uring_enter2_c(fd, to_submit, min_complete, flags, &sig, sz))

cpdef int io_uring_setup(unsigned int entries,
                         io_uring_params p) nogil:
    return trap_error(io_uring_setup_c(entries, p.ptr))


cpdef inline void io_uring_cq_advance(io_uring ring, unsigned int nr) noexcept nogil:
    io_uring_cq_advance_c(ring.ptr, nr)

cpdef inline void io_uring_cqe_seen(io_uring ring, io_uring_cqe nr) noexcept nogil:
    io_uring_cqe_seen_c(ring.ptr, nr.ptr)


# Command prep helpers
# --------------------
cpdef inline void io_uring_sqe_set_data(io_uring_sqe sqe, object obj) noexcept:
    Py_INCREF(obj)
    io_uring_sqe_set_data_c(sqe.ptr, <void*>obj)

cpdef inline object io_uring_cqe_get_data(io_uring_cqe cqe) noexcept:
    cdef object obj = <object>io_uring_cqe_get_data_c(cqe.ptr)
    Py_DECREF(obj)
    return obj

cpdef inline void io_uring_sqe_set_data64(io_uring_sqe sqe, __u64 data) noexcept nogil:
    io_uring_sqe_set_data64_c(sqe.ptr, data)

cpdef inline __u64 io_uring_cqe_get_data64(io_uring_cqe cqe) noexcept nogil:
    return io_uring_cqe_get_data64_c(cqe.ptr)

cpdef inline void io_uring_sqe_set_flags(io_uring_sqe sqe, unsigned int flags) noexcept nogil:
    io_uring_sqe_set_flags_c(sqe.ptr, flags)


cpdef inline void io_uring_prep_nop(io_uring_sqe sqe) noexcept nogil:
    io_uring_prep_nop_c(sqe.ptr)

cpdef inline void io_uring_prep_cancel64(io_uring_sqe sqe, __u64 user_data, int flags) noexcept nogil:
    io_uring_prep_cancel64_c(sqe.ptr, user_data, flags)

cpdef inline void io_uring_prep_cancel(io_uring_sqe sqe, object user_data, int flags) noexcept:
    Py_INCREF(user_data)
    io_uring_prep_cancel_c(sqe.ptr, <void*>user_data, flags)

cpdef inline void io_uring_prep_cancel_fd(io_uring_sqe sqe, int fd, unsigned int flags) noexcept nogil:
    io_uring_prep_cancel_fd_c(sqe.ptr, fd, flags)

cpdef inline void io_uring_prep_waitid(io_uring_sqe sqe,
                                       idtype_t     idtype,
                                       id_t         id,
                                       siginfo      infop,
                                       int          options,
                                       unsigned int flags) noexcept nogil:
    io_uring_prep_waitid_c(sqe.ptr, idtype, id, infop.ptr, options, flags)

cpdef inline void io_uring_prep_fixed_fd_install(io_uring_sqe sqe,
                                                 int          fd,
                                                 unsigned int flags) noexcept nogil:
    io_uring_prep_fixed_fd_install_c(sqe.ptr, fd, flags)


cpdef inline unsigned int io_uring_sq_ready(io_uring ring) noexcept nogil:
    return io_uring_sq_ready_c(ring.ptr)

cpdef inline unsigned int io_uring_sq_space_left(io_uring ring) noexcept nogil:
    return io_uring_sq_space_left_c(ring.ptr)

cpdef inline int io_uring_sqring_wait(io_uring ring) noexcept nogil:
    return io_uring_sqring_wait_c(ring.ptr)

cpdef inline unsigned int io_uring_cq_ready(io_uring ring) noexcept nogil:
    return io_uring_cq_ready_c(ring.ptr)

cpdef inline bool io_uring_cq_has_overflow(io_uring ring) noexcept nogil:
    return io_uring_cq_has_overflow_c(ring.ptr)

cpdef inline bool io_uring_cq_eventfd_enabled(io_uring ring) noexcept nogil:
    return io_uring_cq_eventfd_enabled_c(ring.ptr)

cpdef inline int io_uring_cq_eventfd_toggle(io_uring ring, bool enabled) noexcept nogil:
    return io_uring_cq_eventfd_toggle_c(ring.ptr, enabled)

cpdef inline int io_uring_wait_cqe_nr(io_uring ring,
                                      io_uring_cqe cqe_ptr,
                                      unsigned int     wait_nr) noexcept nogil:
    return io_uring_wait_cqe_nr_c(ring.ptr, &cqe_ptr.ptr, wait_nr)

cpdef inline int io_uring_peek_cqe(io_uring ring, io_uring_cqe cqe_ptr) noexcept nogil:
    return io_uring_peek_cqe_c(ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_wait_cqe(io_uring ring, io_uring_cqe cqe_ptr) noexcept nogil:
    return io_uring_wait_cqe_c(ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_buf_ring_mask(__u32 ring_entries) noexcept nogil:
    return io_uring_buf_ring_mask_c(ring_entries)

cpdef inline void io_uring_buf_ring_init(io_uring_buf_ring br) noexcept nogil:
    io_uring_buf_ring_init_c(br.ptr)

# TODO:
# cpdef inline void io_uring_buf_ring_add(io_uring_buf_ring br,
#                                                      void *addr,
#                                                      unsigned int len,
#                                                      unsigned short bid,
#                                                      int mask,
#                                                      int buf_offset) noexcept nogil:
#     io_uring_buf_ring_add_c(br.ptr, &addr, len, bid, mask, buf_offset)

cpdef inline void io_uring_buf_ring_advance(io_uring_buf_ring br, int count) noexcept nogil:
    io_uring_buf_ring_advance_c(br.ptr, count)

cpdef inline void io_uring_buf_ring_cq_advance(io_uring          ring,
                                               io_uring_buf_ring br,
                                               int               count) noexcept nogil:
    io_uring_buf_ring_cq_advance_c(ring.ptr, br.ptr, count)

cpdef inline int io_uring_buf_ring_available(io_uring          ring,
                                             io_uring_buf_ring br,
                                             unsigned short    bgid) noexcept nogil:
    return io_uring_buf_ring_available_c(ring.ptr, br.ptr, bgid)

cpdef inline io_uring_sqe io_uring_get_sqe(io_uring ring) noexcept:
    cdef io_uring_sqe sqe = io_uring_sqe(0)
    sqe.ptr = io_uring_get_sqe_c(ring.ptr)
    return sqe
