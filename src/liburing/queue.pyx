from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from cpython.ref cimport Py_INCREF, Py_DECREF
from .error cimport memory_error, trap_error


LIBURING_UDATA_TIMEOUT = __LIBURING_UDATA_TIMEOUT


# TODO:
# cpdef int io_uring_queue_init_mem(unsigned int entries,
#                                   io_uring ring,
#                                   io_uring_params p,
#                                   nullptr_t buf,
#                                   size_t buf_size):
#     return trap_error(__io_uring_queue_init_mem(entries, ring.ptr, p.ptr, &buf, buf_size))

cpdef int io_uring_queue_init_params(unsigned int entries,
                                     io_uring ring,
                                     io_uring_params p) nogil:
    return trap_error(__io_uring_queue_init_params(entries, ring.ptr, p.ptr))

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
    return trap_error(__io_uring_queue_init(entries, ring.ptr, flags))

cpdef int io_uring_queue_mmap(int fd,
                              io_uring_params p,
                              io_uring ring) nogil:
    return trap_error(__io_uring_queue_mmap(fd, p.ptr, ring.ptr))

cpdef int io_uring_ring_dontfork(io_uring ring) nogil:
    return trap_error(__io_uring_ring_dontfork(ring.ptr))

cpdef void io_uring_queue_exit(io_uring ring) noexcept nogil:
    if ring.ptr is not NULL:
        __io_uring_queue_exit(ring.ptr)

cpdef unsigned int io_uring_peek_batch_cqe(io_uring ring,
                                           io_uring_cqe cqes,
                                           unsigned int count) nogil:
    return __io_uring_peek_batch_cqe(ring.ptr, &cqes.ptr, count)

cpdef int io_uring_wait_cqes(io_uring ring,
                             io_uring_cqe cqe_ptr,
                             unsigned int wait_nr,
                             timespec ts=None,
                             sigset sigmask=None) nogil:
    # cdef timespec_t _ts = ts.ptr or NULL
    # cdef sigset_t _sm = sigmask.ptr or NULL
    return trap_error(__io_uring_wait_cqes(ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr, sigmask.ptr))

cpdef int io_uring_wait_cqe_timeout(io_uring ring, io_uring_cqe cqe_ptr, timespec ts) nogil:
    return trap_error(__io_uring_wait_cqe_timeout(ring.ptr, &cqe_ptr.ptr, ts.ptr))

cpdef int io_uring_submit(io_uring ring) nogil:
    return trap_error(__io_uring_submit(ring.ptr))

cpdef int io_uring_submit_and_wait(io_uring ring, unsigned int wait_nr) nogil:
    return trap_error(__io_uring_submit_and_wait(ring.ptr, wait_nr))

cpdef int io_uring_submit_and_wait_timeout(io_uring ring,
                                           io_uring_cqe cqe_ptr,
                                           unsigned int wait_nr,
                                           timespec ts,
                                           sigset sigmask) nogil:
    return trap_error(__io_uring_submit_and_wait_timeout(ring.ptr, &cqe_ptr.ptr, wait_nr, ts.ptr,
                                                         sigmask.ptr))

cpdef int io_uring_get_events(io_uring ring) nogil:
    return trap_error(__io_uring_get_events(ring.ptr))

cpdef int io_uring_submit_and_get_events(io_uring ring) nogil:
    return trap_error(__io_uring_submit_and_get_events(ring.ptr))

#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset sig) nogil:
    return trap_error(__io_uring_enter(fd, to_submit, min_complete, flags, sig.ptr))

cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset sig,
                          size_t sz) nogil:
    return trap_error(__io_uring_enter2(fd, to_submit, min_complete, flags, sig.ptr, sz))

cpdef int io_uring_setup(unsigned int entries,
                         io_uring_params p) nogil:
    return trap_error(__io_uring_setup(entries, p.ptr))

cpdef inline void io_uring_cq_advance(io_uring ring,
                                      unsigned int nr) noexcept nogil:
    __io_uring_cq_advance(ring.ptr, nr)

cpdef inline void io_uring_cqe_seen(io_uring ring,
                                    io_uring_cqe nr) noexcept nogil:
    __io_uring_cqe_seen(ring.ptr, nr.ptr)


# Command prep helpers
# --------------------
cpdef inline void io_uring_sqe_set_data(io_uring_sqe sqe,
                                        object obj):
    Py_INCREF(obj)
    __io_uring_sqe_set_data(sqe.ptr, <void*>obj)

cpdef inline object io_uring_cqe_get_data(io_uring_cqe cqe):
    cdef object obj = <object>__io_uring_cqe_get_data(cqe.ptr)
    Py_DECREF(obj)
    return obj

cpdef inline void io_uring_sqe_set_data64(io_uring_sqe sqe,
                                          __u64 data) noexcept nogil:
    __io_uring_sqe_set_data64(sqe.ptr, data)

cpdef inline __u64 io_uring_cqe_get_data64(io_uring_cqe cqe) noexcept nogil:
    return __io_uring_cqe_get_data64(cqe.ptr)

cpdef inline void io_uring_sqe_set_flags(io_uring_sqe sqe,
                                         unsigned int flags) noexcept nogil:
    __io_uring_sqe_set_flags(sqe.ptr, flags)

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
    return __io_uring_sq_ready(ring.ptr)

cpdef inline unsigned int io_uring_sq_space_left(io_uring ring) noexcept nogil:
    return __io_uring_sq_space_left(ring.ptr)

cpdef inline int io_uring_sqring_wait(io_uring ring) noexcept nogil:
    return __io_uring_sqring_wait(ring.ptr)

cpdef inline unsigned int io_uring_cq_ready(io_uring ring) noexcept nogil:
    return __io_uring_cq_ready(ring.ptr)

cpdef inline bool io_uring_cq_has_overflow(io_uring ring) noexcept nogil:
    return __io_uring_cq_has_overflow(ring.ptr)

cpdef inline bool io_uring_cq_eventfd_enabled(io_uring ring) noexcept nogil:
    return __io_uring_cq_eventfd_enabled(ring.ptr)

cpdef inline int io_uring_cq_eventfd_toggle(io_uring ring,
                                            bool enabled) noexcept nogil:
    return __io_uring_cq_eventfd_toggle(ring.ptr, enabled)

cpdef inline int io_uring_wait_cqe_nr(io_uring ring,
                                      io_uring_cqe cqe_ptr,
                                      unsigned int wait_nr) noexcept nogil:
    return __io_uring_wait_cqe_nr(ring.ptr, &cqe_ptr.ptr, wait_nr)

cpdef inline int io_uring_peek_cqe(io_uring ring,
                                   io_uring_cqe cqe_ptr) noexcept nogil:
    return __io_uring_peek_cqe(ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_wait_cqe(io_uring ring,
                                   io_uring_cqe cqe_ptr) noexcept nogil:
    return __io_uring_wait_cqe(ring.ptr, &cqe_ptr.ptr)

cpdef inline int io_uring_buf_ring_mask(__u32 ring_entries) noexcept nogil:
    return __io_uring_buf_ring_mask(ring_entries)

cpdef inline void io_uring_buf_ring_init(io_uring_buf_ring br) noexcept nogil:
    __io_uring_buf_ring_init(br.ptr)

# TODO:
# cpdef inline void io_uring_buf_ring_add(io_uring_buf_ring br,
#                                                      void *addr,
#                                                      unsigned int len,
#                                                      unsigned short bid,
#                                                      int mask,
#                                                      int buf_offset) noexcept nogil:
#     __io_uring_buf_ring_add(br.ptr, &addr, len, bid, mask, buf_offset)

cpdef inline void io_uring_buf_ring_advance(io_uring_buf_ring br,
                                            int count) noexcept nogil:
    __io_uring_buf_ring_advance(br.ptr, count)

cpdef inline void io_uring_buf_ring_cq_advance(io_uring ring,
                                               io_uring_buf_ring br,
                                               int count) noexcept nogil:
    __io_uring_buf_ring_cq_advance(ring.ptr, br.ptr, count)

cpdef inline int io_uring_buf_ring_available(io_uring ring,
                                             io_uring_buf_ring br,
                                             unsigned short bgid) noexcept nogil:
    return __io_uring_buf_ring_available(ring.ptr, br.ptr, bgid)

cpdef inline io_uring_sqe io_uring_get_sqe(io_uring ring):
    cdef io_uring_sqe sqe = io_uring_sqe(0)
    sqe.ptr = __io_uring_get_sqe(ring.ptr)
    return sqe
