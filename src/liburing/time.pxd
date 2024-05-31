from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .lib.uring cimport *
from .error cimport memory_error, index_error
from .queue cimport io_uring_sqe


cdef class timespec:
    cdef __kernel_timespec* ptr


cpdef void io_uring_prep_timeout(io_uring_sqe sqe,
                                 timespec ts,
                                 unsigned int count,
                                 unsigned int flags) noexcept nogil
cpdef void io_uring_prep_timeout_remove(io_uring_sqe sqe,
                                        __u64 user_data,
                                        unsigned int flags) noexcept nogil
cpdef void io_uring_prep_timeout_update(io_uring_sqe sqe,
                                        timespec ts,
                                        __u64 user_data,
                                        unsigned int flags) noexcept nogil
cpdef void io_uring_prep_link_timeout(io_uring_sqe sqe,
                                      timespec ts,
                                      unsigned int flags) noexcept nogil


cpdef enum __time_define__:
    IORING_TIMEOUT_ABS = __IORING_TIMEOUT_ABS
    IORING_TIMEOUT_UPDATE = __IORING_TIMEOUT_UPDATE
    IORING_TIMEOUT_BOOTTIME = __IORING_TIMEOUT_BOOTTIME
    IORING_TIMEOUT_REALTIME = __IORING_TIMEOUT_REALTIME
    IORING_LINK_TIMEOUT_UPDATE = __IORING_LINK_TIMEOUT_UPDATE
    IORING_TIMEOUT_ETIME_SUCCESS = __IORING_TIMEOUT_ETIME_SUCCESS
    IORING_TIMEOUT_MULTISHOT = __IORING_TIMEOUT_MULTISHOT
    IORING_TIMEOUT_CLOCK_MASK = __IORING_TIMEOUT_CLOCK_MASK
    IORING_TIMEOUT_UPDATE_MASK = __IORING_TIMEOUT_UPDATE_MASK
