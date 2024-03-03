from .queue cimport *


cdef class epoll_event:
    cdef __epoll_event * ptr


cpdef void io_uring_prep_poll_add(io_uring_sqe sqe,
                                  int fd,
                                  unsigned int poll_mask) noexcept nogil

cpdef void io_uring_prep_poll_update(io_uring_sqe sqe,
                                     __u64 old_user_data,
                                     __u64 new_user_data,
                                     unsigned int poll_mask,
                                     unsigned int flags) noexcept nogil

cpdef void io_uring_prep_poll_remove(io_uring_sqe sqe, __u64 user_data) noexcept nogil

cpdef void io_uring_prep_poll_multishot(io_uring_sqe sqe,
                                        int fd,
                                        unsigned int poll_mask) noexcept nogil


cpdef void io_uring_prep_epoll_ctl(io_uring_sqe sqe,
                                   int epfd,
                                   int fd,
                                   int op,
                                   epoll_event ev) noexcept nogil
