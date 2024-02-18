from .type cimport *
from .error cimport *
from .io_uring cimport *


cdef extern from 'liburing.h' nogil:
    # Library interface to `io_uring`
    # -------------------------------
    struct io_uring_sq_t 'io_uring_sq':
        unsigned int *khead
        unsigned int *ktail
        unsigned int *kring_mask  # Deprecated: use `ring_mask` instead of `*kring_mask`
        unsigned int *kring_entries  # Deprecated: use `ring_entries` instead of `*kring_entries`
        unsigned int *kflags
        unsigned int *kdropped
        unsigned int *array
        io_uring_sqe_t *sqes
        unsigned int sqe_head
        unsigned int sqe_tail
        size_t ring_sz
        void *ring_ptr
        unsigned int ring_mask
        unsigned int ring_entries
        unsigned int pad[2]

    struct io_uring_cq_t 'io_uring_cq':
        unsigned int *khead
        unsigned int *ktail
        unsigned int *kring_mask  # Deprecated: use `ring_mask` instead of `*kring_mask`
        unsigned int *kring_entries  # Deprecated: use `ring_entries` instead of `*kring_entries`
        unsigned int *kflags
        unsigned int *koverflow
        io_uring_cqe_t *cqes
        size_t ring_sz
        void *ring_ptr
        unsigned int ring_mask
        unsigned int ring_entries
        unsigned int pad[2]

    struct io_uring_t 'io_uring':
        io_uring_sq_t sq
        io_uring_cq_t cq
        unsigned int flags
        int ring_fd
        unsigned int features
        int enter_ring_fd
        __u8 int_flags
        __u8 pad[3]
        unsigned int pad2

    # Library interface
    # -----------------
    int io_uring_queue_init_mem_c 'io_uring_queue_init_mem'(unsigned int entries,
                                                            io_uring_t *ring,
                                                            io_uring_params_t *p,
                                                            void *buf,
                                                            size_t buf_size)
    int io_uring_queue_init_params_c 'io_uring_queue_init_params'(unsigned int entries,
                                                                  io_uring_t *ring,
                                                                  io_uring_params_t *p)
    int io_uring_queue_init_c 'io_uring_queue_init'(unsigned int entries,
                                                    io_uring_t *ring,
                                                    unsigned int flags)
    int io_uring_queue_mmap_c 'io_uring_queue_mmap'(int fd,
                                                    io_uring_params_t *p,
                                                    io_uring_t *ring)
    int io_uring_ring_dontfork_c 'io_uring_ring_dontfork'(io_uring_t *ring)
    void io_uring_queue_exit_c 'io_uring_queue_exit'(io_uring_t *ring)
    unsigned int io_uring_peek_batch_cqe_c 'io_uring_peek_batch_cqe'(io_uring_t *ring,
                                                                     io_uring_cqe_t **cqes,
                                                                     unsigned int count)
    int io_uring_wait_cqes_c 'io_uring_wait_cqes'(io_uring_t *ring,
                                                  io_uring_cqe_t **cqe_ptr,
                                                  unsigned int wait_nr,
                                                  __kernel_timespec *ts,
                                                  sigset_t *sigmask)
    int io_uring_wait_cqe_timeout_c 'io_uring_wait_cqe_timeout'(io_uring_t *ring,
                                                                io_uring_cqe_t **cqe_ptr,
                                                                __kernel_timespec *ts)
    int io_uring_submit_c 'io_uring_submit'(io_uring_t *ring)
    int io_uring_submit_and_wait_c 'io_uring_submit_and_wait'(io_uring_t *ring,
                                                              unsigned int wait_nr)
    int io_uring_submit_and_wait_timeout_c 'io_uring_submit_and_wait_timeout'(
            io_uring_t *ring,
            io_uring_cqe_t **cqe_ptr,
            unsigned int wait_nr,
            __kernel_timespec *ts,
            sigset_t *sigmask)

    int io_uring_get_events_c 'io_uring_get_events'(io_uring_t *ring)
    int io_uring_submit_and_get_events_c 'io_uring_submit_and_get_events'(io_uring_t *ring)

    # io_uring syscalls.
    int io_uring_enter_c 'io_uring_enter'(unsigned int fd,
                                          unsigned int to_submit,
                                          unsigned int min_complete,
                                          unsigned int flags,
                                          sigset_t *sig)
    int io_uring_enter2_c 'io_uring_enter2'(unsigned int fd,
                                            unsigned int to_submit,
                                            unsigned int min_complete,
                                            unsigned int flags,
                                            sigset_t *sig,
                                            size_t sz);
    int io_uring_setup_c 'io_uring_setup'(unsigned int entries,
                                          io_uring_params_t *p)

    # TODO: need to properly test these functions
    # note: can only call these function directly from cython, not python!
    io_uring_cqe_shift(ring)
    io_uring_cqe_index(ring, ptr, mask)   
    io_uring_for_each_cqe(ring, head, cqe)

    void io_uring_cq_advance_c 'io_uring_cq_advance'(io_uring_t *ring,
                                                     unsigned int nr)
    void io_uring_cqe_seen_c 'io_uring_cqe_seen'(io_uring_t *ring,
                                                 io_uring_cqe_t *cqe)

    # Command prep helpers
    # --------------------
    void io_uring_sqe_set_data_c 'io_uring_sqe_set_data'(io_uring_sqe_t *sqe,
                                                         void *data)
    void *io_uring_cqe_get_data_c 'io_uring_cqe_get_data'(const io_uring_cqe_t *cqe)
    void io_uring_sqe_set_data64_c 'io_uring_sqe_set_data64'(io_uring_sqe_t *sqe,
                                                             __u64 data)
    __u64 io_uring_cqe_get_data64_c 'io_uring_cqe_get_data64'(const io_uring_cqe_t *cqe)
    void io_uring_sqe_set_flags_c 'io_uring_sqe_set_flags'(io_uring_sqe_t *sqe,
                                                           unsigned int flags)
    # note: access to cython users only
    void __io_uring_set_target_fixed_file(io_uring_sqe_t *sqe,
                                          unsigned int file_index)
    # note: access to cython users only
    void io_uring_prep_rw(int op,
                          io_uring_sqe_t *sqe,
                          int fd,
                          const void *addr,
                          unsigned int len,
                          __u64 offset)

    void io_uring_prep_nop_c 'io_uring_prep_nop'(io_uring_sqe_t *sqe)
    void io_uring_prep_cancel64_c 'io_uring_prep_cancel64'(io_uring_sqe_t *sqe,
                                                           __u64 user_data,
                                                           int flags)
    void io_uring_prep_cancel_c 'io_uring_prep_cancel'(io_uring_sqe_t *sqe,
                                                       void *user_data,
                                                       int flags)
    void io_uring_prep_cancel_fd_c 'io_uring_prep_cancel_fd'(io_uring_sqe_t *sqe,
                                                             int fd,
                                                             unsigned int flags)

    void io_uring_prep_waitid_c 'io_uring_prep_waitid'(io_uring_sqe_t *sqe,
                                                       idtype_t idtype,
                                                       id_t id,
                                                       siginfo_t *infop,
                                                       int options,
                                                       unsigned int flags)
    void io_uring_prep_fixed_fd_install_c 'io_uring_prep_fixed_fd_install'(io_uring_sqe_t *sqe,
                                                                           int fd,
                                                                           unsigned int flags)

    unsigned int io_uring_sq_ready_c 'io_uring_sq_ready'(const io_uring_t *ring)
    unsigned int io_uring_sq_space_left_c 'io_uring_sq_space_left'(const io_uring_t *ring)
    int io_uring_sqring_wait_c 'io_uring_sqring_wait'(io_uring_t *ring)
    unsigned int io_uring_cq_ready_c 'io_uring_cq_ready'(const io_uring_t *ring)
    bool io_uring_cq_has_overflow_c 'io_uring_cq_has_overflow'(const io_uring_t *ring)
    bool io_uring_cq_eventfd_enabled_c 'io_uring_cq_eventfd_enabled'(const io_uring_t *ring)

    int io_uring_cq_eventfd_toggle_c 'io_uring_cq_eventfd_toggle'(io_uring_t *ring,
                                                                  bool enabled)
    int io_uring_wait_cqe_nr_c 'io_uring_wait_cqe_nr'(io_uring_t *ring,
                                                      io_uring_cqe_t **cqe_ptr,
                                                      unsigned int wait_nr)
    int io_uring_peek_cqe_c 'io_uring_peek_cqe'(io_uring_t *ring,
                                                io_uring_cqe_t **cqe_ptr)
    int io_uring_wait_cqe_c 'io_uring_wait_cqe'(io_uring_t *ring,
                                                io_uring_cqe_t **cqe_ptr)
    int io_uring_buf_ring_mask_c 'io_uring_buf_ring_mask'(__u32 ring_entries)
    void io_uring_buf_ring_init_c 'io_uring_buf_ring_init'(io_uring_buf_ring_t *br)
    void io_uring_buf_ring_add_c 'io_uring_buf_ring_add'(io_uring_buf_ring_t *br,
                                                         void *addr,
                                                         unsigned int len,
                                                         unsigned short bid,
                                                         int mask,
                                                         int buf_offset)
    void io_uring_buf_ring_advance_c 'io_uring_buf_ring_advance'(io_uring_buf_ring_t *br,
                                                                 int count)
    void io_uring_buf_ring_cq_advance_c 'io_uring_buf_ring_cq_advance'(io_uring_t *ring,
                                                                       io_uring_buf_ring_t *br,
                                                                       int count)
    int io_uring_buf_ring_available_c 'io_uring_buf_ring_available'(io_uring_t *ring,
                                                                    io_uring_buf_ring_t *br,
                                                                    unsigned short bgid)
    io_uring_sqe_t *io_uring_get_sqe_c 'io_uring_get_sqe'(io_uring_t *ring)


cdef class io_uring:
    cdef io_uring_t *ptr

# TODO:
# cpdef int io_uring_queue_init_mem(unsigned int entries,
#                                   io_uring ring,
#                                   io_uring_params p,
#                                   nullptr_t buf,
#                                   size_t buf_size)
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

cpdef int io_uring_get_events(io_uring ring) nogil
cpdef int io_uring_submit_and_get_events(io_uring ring) nogil

#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset sig) nogil
cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset sig,
                          size_t sz) nogil
cpdef int io_uring_setup(unsigned int entries,
                         io_uring_params p) nogil

cpdef void io_uring_cq_advance(io_uring ring,
                               unsigned int nr) noexcept nogil
cpdef void io_uring_cqe_seen(io_uring ring,
                             io_uring_cqe nr) noexcept nogil

# Command prep helpers
# --------------------
cpdef void io_uring_sqe_set_data(io_uring_sqe sqe,
                                 object obj) noexcept
cpdef object io_uring_cqe_get_data(io_uring_cqe cqe) noexcept
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

# TODO:
# cpdef void io_uring_buf_ring_add(io_uring_buf_ring br,
#                                  void *addr,
#                                  unsigned int len,
#                                  unsigned short bid,
#                                  int mask,
#                                  int buf_offset) noexcept nogil
cpdef void io_uring_buf_ring_advance(io_uring_buf_ring br,
                                     int count) noexcept nogil
cpdef void io_uring_buf_ring_cq_advance(io_uring ring,
                                        io_uring_buf_ring br,
                                        int count) noexcept nogil
cpdef int io_uring_buf_ring_available(io_uring ring,
                                      io_uring_buf_ring br,
                                      unsigned short bgid) noexcept nogil
cpdef io_uring_sqe io_uring_get_sqe(io_uring ring) noexcept
