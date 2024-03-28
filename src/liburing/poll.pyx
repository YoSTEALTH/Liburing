cdef class epoll_event:
    ''' Note: if you want this feature create an Issue/PR. '''


cpdef inline void io_uring_prep_poll_add(io_uring_sqe sqe,
                                         int fd,
                                         unsigned int poll_mask) noexcept nogil:
    __io_uring_prep_poll_add(sqe.ptr, fd, poll_mask)

cpdef inline void io_uring_prep_poll_update(io_uring_sqe sqe,
                                            __u64 old_user_data,
                                            __u64 new_user_data,
                                            unsigned int poll_mask,
                                            unsigned int flags) noexcept nogil:
    __io_uring_prep_poll_update(sqe.ptr, old_user_data, new_user_data, poll_mask, flags)

cpdef inline void io_uring_prep_poll_remove(io_uring_sqe sqe,
                                            __u64 user_data) noexcept nogil:
    __io_uring_prep_poll_remove(sqe.ptr, user_data)

cpdef inline void io_uring_prep_poll_multishot(io_uring_sqe sqe,
                                               int fd,
                                               unsigned int poll_mask) noexcept nogil:
    __io_uring_prep_poll_multishot(sqe.ptr, fd, poll_mask)


cpdef inline void io_uring_prep_epoll_ctl(io_uring_sqe sqe,
                                          int epfd,
                                          int fd,
                                          int op,
                                          epoll_event ev) noexcept nogil:
    __io_uring_prep_epoll_ctl(sqe.ptr, epfd, fd, op, ev.ptr)
