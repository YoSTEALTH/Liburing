from .lib.uring cimport *
from .time cimport timespec
from .type cimport sigset, siginfo


cdef class io_uring:
    cdef __io_uring *ptr

cdef class io_uring_sqe:
    cdef:
        __io_uring_sqe * ptr
        unsigned int len
        list ref

cdef class io_uring_cqe:
    cdef __io_uring_cqe * ptr

cdef class io_uring_params:
    cdef __io_uring_params * ptr

cdef class io_uring_buf_ring:
    cdef __io_uring_buf_ring * ptr


cpdef int io_uring_queue_init_mem(unsigned int entries,
                                  io_uring ring,
                                  io_uring_params p,
                                  unsigned char[:] buf,
                                  size_t buf_size)
cpdef int io_uring_queue_init_params(unsigned int entries,
                                     io_uring ring,
                                     io_uring_params p) nogil
cpdef int io_uring_queue_init(unsigned int entries,
                              io_uring ring,
                              unsigned int flags=?) nogil
cpdef int io_uring_queue_mmap(int fd,
                              io_uring_params p,
                              io_uring ring) nogil
cpdef int io_uring_ring_dontfork(io_uring ring) nogil
cpdef void io_uring_queue_exit(io_uring ring) nogil
cpdef unsigned int io_uring_peek_batch_cqe(io_uring ring,
                                           io_uring_cqe cqes,
                                           unsigned int count) nogil
cpdef int io_uring_wait_cqes(io_uring ring,
                             io_uring_cqe cqe_ptr,
                             unsigned int wait_nr,
                             timespec ts=?,
                             sigset sigmask=?) nogil
cpdef int io_uring_wait_cqe_timeout(io_uring ring,
                                    io_uring_cqe cqe_ptr,
                                    timespec ts) nogil
cpdef int io_uring_submit(io_uring ring) nogil
cpdef int io_uring_submit_and_wait(io_uring ring,
                                   unsigned int wait_nr) nogil
cpdef int io_uring_submit_and_wait_timeout(io_uring ring,
                                           io_uring_cqe cqe_ptr,
                                           unsigned int wait_nr,
                                           timespec ts,
                                           sigset sigmask) nogil

cpdef int io_uring_enable_rings(io_uring ring) nogil
cpdef int io_uring_close_ring_fd(io_uring ring) nogil

cpdef int io_uring_get_events(io_uring ring) nogil
cpdef int io_uring_submit_and_get_events(io_uring ring) nogil

cpdef void io_uring_cq_advance(io_uring ring,
                               unsigned int nr) noexcept nogil
cpdef void io_uring_cqe_seen(io_uring ring,
                             io_uring_cqe nr) noexcept nogil

# Command prep helpers
# --------------------
cpdef void io_uring_sqe_set_data(io_uring_sqe sqe,
                                 object obj)
cpdef object io_uring_cqe_get_data(io_uring_cqe cqe)
cpdef void io_uring_sqe_set_data64(io_uring_sqe sqe,
                                   __u64 data) noexcept nogil
cpdef __u64 io_uring_cqe_get_data64(io_uring_cqe cqe) noexcept nogil
cpdef void io_uring_sqe_set_flags(io_uring_sqe sqe,
                                  unsigned int flags) noexcept nogil

cpdef void io_uring_prep_nop(io_uring_sqe sqe) noexcept nogil
cpdef void io_uring_prep_cancel64(io_uring_sqe sqe,
                                  __u64 user_data,
                                  int flags) noexcept nogil
cpdef void io_uring_prep_cancel(io_uring_sqe sqe,
                                object user_data,
                                int flags) noexcept
cpdef void io_uring_prep_cancel_fd(io_uring_sqe sqe,
                                   int fd,
                                   unsigned int flags) noexcept nogil

cpdef void io_uring_prep_waitid(io_uring_sqe sqe,
                                idtype_t idtype,
                                id_t id,
                                siginfo infop,
                                int options,
                                unsigned int flags) noexcept nogil
cpdef void io_uring_prep_fixed_fd_install(io_uring_sqe sqe,
                                          int fd,
                                          unsigned int flags) noexcept nogil

cpdef unsigned int io_uring_sq_ready(io_uring ring) noexcept nogil
cpdef unsigned int io_uring_sq_space_left(io_uring ring) noexcept nogil
cpdef int io_uring_sqring_wait(io_uring ring) noexcept nogil
cpdef unsigned int io_uring_cq_ready(io_uring ring) noexcept nogil
cpdef bool io_uring_cq_has_overflow(io_uring ring) noexcept nogil
cpdef bool io_uring_cq_eventfd_enabled(io_uring ring) noexcept nogil

cpdef int io_uring_cq_eventfd_toggle(io_uring ring,
                                     bool enabled) noexcept nogil
cpdef int io_uring_wait_cqe_nr(io_uring ring,
                               io_uring_cqe cqe_ptr,
                               unsigned int wait_nr) noexcept nogil
cpdef int io_uring_peek_cqe(io_uring ring,
                            io_uring_cqe cqe_ptr) noexcept nogil
cpdef int io_uring_wait_cqe(io_uring ring,
                            io_uring_cqe cqe_ptr) noexcept nogil

cpdef int io_uring_buf_ring_mask(__u32 ring_entries) noexcept nogil
cpdef void io_uring_buf_ring_init(io_uring_buf_ring br) noexcept nogil
cpdef void io_uring_buf_ring_add(io_uring_buf_ring br,
                                 unsigned char[:] addr,
                                 unsigned int len,
                                 unsigned short bid,
                                 int mask,
                                 int buf_offset) noexcept nogil
cpdef void io_uring_buf_ring_advance(io_uring_buf_ring br,
                                     int count) noexcept nogil
cpdef void io_uring_buf_ring_cq_advance(io_uring ring,
                                        io_uring_buf_ring br,
                                        int count) noexcept nogil
cpdef int io_uring_buf_ring_available(io_uring ring,
                                      io_uring_buf_ring br,
                                      unsigned short bgid) noexcept nogil

cpdef io_uring_sqe io_uring_get_sqe(io_uring ring)
