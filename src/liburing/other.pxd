from .lib.uring cimport *
from .queue cimport io_uring, io_uring_params, io_uring_sqe


cdef class io_uring_buf_ring:
    cdef __io_uring_buf_ring * ptr
    # TODO: io_uring_free_buf_ring on exit.


cpdef io_uring_buf_ring io_uring_setup_buf_ring(io_uring ring,
                                                unsigned int nentries,
                                                int bgid,
                                                unsigned int flags,
                                                int ret)
cpdef int io_uring_free_buf_ring(io_uring ring,
                                 io_uring_buf_ring br,
                                 unsigned int nentries,
                                 int bgid)

cpdef void io_uring_prep_fadvise(io_uring_sqe sqe,
                                 int fd,
                                 __u64 offset,
                                 off_t len,
                                 int advice) noexcept nogil
# TODO:
# cpdef void io_uring_prep_madvise(io_uring_sqe sqe,
#                                         void *addr,
#                                         off_t length,
#                                         int advice) noexcept nogil

cpdef void io_uring_prep_msg_ring(io_uring_sqe sqe,
                                  int fd,
                                  unsigned int len,
                                  __u64 data,
                                  unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_msg_ring_fd(io_uring_sqe sqe,
                                     int fd,
                                     int source_fd,
                                     int target_fd,
                                     __u64 data,
                                     unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_msg_ring_fd_alloc(io_uring_sqe sqe,
                                           int fd,
                                           int source_fd,
                                           __u64 data,
                                           unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_msg_ring_cqe_flags(io_uring_sqe sqe,
                                            int fd,
                                            unsigned int len,
                                            __u64 data,
                                            unsigned int cqe_flags,
                                            unsigned int flags=?) noexcept nogil

cpdef ssize_t io_uring_mlock_size(unsigned int entries, unsigned int flags) nogil
cpdef ssize_t io_uring_mlock_size_params(unsigned int entries, io_uring_params p) nogil
