# NOTE: linux version 6.7 +

# from .lib.uring cimport *
# from .queue cimport io_uring_sqe


# cdef class futex_state:
#     cdef:
#         uint32_t *ptr
#         readonly bint private
#         __u8 len

# cdef class futex_waitv:
#     cdef:
#         __futex_waitv *ptr
#         bint private
#         __u8 len

# cpdef void io_uring_prep_futex_wake(io_uring_sqe sqe,
#                                     futex_state futex,
#                                     uint64_t val,
#                                     uint64_t mask,
#                                     uint32_t futex_flags) noexcept nogil
# cpdef void io_uring_prep_futex_wait(io_uring_sqe sqe,
#                                     futex_state futex,
#                                     uint64_t val,
#                                     uint64_t mask,
#                                     uint32_t futex_flags) noexcept nogil
# cpdef void io_uring_prep_futex_waitv(io_uring_sqe sqe, futex_waitv waiters) noexcept nogil
