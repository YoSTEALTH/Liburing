# TODO: class/function here have not been organized, yet!


cdef class io_uring_buf_ring:
    pass

# Mapped buffer ring alloc/register + unregister/free helpers
cpdef io_uring_buf_ring io_uring_setup_buf_ring(io_uring ring,
                                                unsigned int nentries,
                                                int bgid,
                                                unsigned int flags,
                                                int ret):
    cdef io_uring_buf_ring buf = io_uring_buf_ring()
    buf.ptr = __io_uring_setup_buf_ring(&ring.ptr, nentries, bgid, flags, &ret)
    memory_error(buf)
    return buf

cpdef int io_uring_free_buf_ring(io_uring ring,
                                 io_uring_buf_ring br,
                                 unsigned int nentries,
                                 int bgid):
    cdef int r = __io_uring_free_buf_ring(&ring.ptr, br.ptr, nentries, bgid)
    trap_error(r)
    br.ptr = NULL

cpdef inline void io_uring_prep_fadvise(io_uring_sqe sqe,
                                        int fd,
                                        __u64 offset,
                                        off_t len,
                                        int advice) noexcept nogil:
    __io_uring_prep_fadvise(sqe.ptr, fd, offset, len, advice)

# TODO:
# cpdef inline void io_uring_prep_madvise(io_uring_sqe sqe,
#                                         void *addr,
#                                         off_t length,
#                                         int advice) noexcept nogil:
#     __io_uring_prep_madvise(sqe.ptr, &addr, length, advice)


cpdef inline void io_uring_prep_msg_ring(io_uring_sqe sqe,
                                         int fd,
                                         unsigned int len,
                                         __u64 data,
                                         unsigned int flags=0) noexcept nogil:
    __io_uring_prep_msg_ring(sqe.ptr, fd, len, data, flags)

cpdef inline void io_uring_prep_msg_ring_fd(io_uring_sqe sqe,
                                            int fd,
                                            int source_fd,
                                            int target_fd,
                                            __u64 data,
                                            unsigned int flags=0) noexcept nogil:
    __io_uring_prep_msg_ring_fd(sqe.ptr, fd, source_fd, target_fd, data, flags)

cpdef inline void io_uring_prep_msg_ring_fd_alloc(io_uring_sqe sqe,
                                                  int fd,
                                                  int source_fd,
                                                  __u64 data,
                                                  unsigned int flags=0) noexcept nogil:
    __io_uring_prep_msg_ring_fd_alloc(sqe.ptr, fd, source_fd, data, flags)

cpdef inline void io_uring_prep_msg_ring_cqe_flags(io_uring_sqe sqe,
                                                   int fd,
                                                   unsigned int len,
                                                   __u64 data,
                                                   unsigned int cqe_flags,
                                                   unsigned int flags=0) noexcept nogil:
    __io_uring_prep_msg_ring_cqe_flags(sqe.ptr, fd, len, data, flags, cqe_flags)


cpdef ssize_t io_uring_mlock_size(unsigned int entries, unsigned int flags) nogil:
    return __io_uring_mlock_size(entries, flags)

cpdef ssize_t io_uring_mlock_size_params(unsigned int entries, io_uring_params p) nogil:
    return __io_uring_mlock_size_params(entries, p.ptr)
