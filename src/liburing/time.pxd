from .lib.type cimport *


cdef class timespec:
    cdef __kernel_timespec *ptr


# from .type cimport __u64, int64_t, __kernel_timespec, timespec
# from .io_uring cimport __io_uring_sqe, io_uring_sqe


# cpdef void io_uring_prep_timeout(io_uring_sqe sqe,
#                                  timespec ts,
#                                  unsigned int count,
#                                  unsigned int flags)
# cpdef void io_uring_prep_timeout_remove(io_uring_sqe sqe,
#                                         __u64 user_data,
#                                         unsigned int flags)
# cpdef void io_uring_prep_timeout_update(io_uring_sqe sqe,
#                                         timespec ts,
#                                         __u64 user_data,
#                                         unsigned int flags)
# cpdef void io_uring_prep_link_timeout(io_uring_sqe sqe,
#                                       timespec ts,
#                                       unsigned int flags)
