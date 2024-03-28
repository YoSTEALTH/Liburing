from posix.mman cimport PROT_READ, PROT_WRITE, MAP_ANONYMOUS, MAP_PRIVATE, MAP_SHARED, MAP_FAILED, \
                        mmap, munmap
from cpython.mem cimport PyMem_RawMalloc, PyMem_RawCalloc, PyMem_RawFree
from cpython.array cimport array
from .lib.uring cimport *
from .error cimport memory_error
from .queue cimport io_uring_sqe


cdef class futex_state:
    cdef:
        uint32_t *ptr
        readonly bint private
        __u8 len

cdef class futex_waitv:
    cdef:
        __futex_waitv *ptr
        bint private
        __u8 len

cpdef void io_uring_prep_futex_wake(io_uring_sqe sqe,
                                    futex_state futex,
                                    uint64_t val,
                                    uint64_t mask,
                                    uint32_t futex_flags) noexcept nogil
cpdef void io_uring_prep_futex_wait(io_uring_sqe sqe,
                                    futex_state futex,
                                    uint64_t val,
                                    uint64_t mask,
                                    uint32_t futex_flags) noexcept nogil
cpdef void io_uring_prep_futex_waitv(io_uring_sqe sqe, futex_waitv waiters) noexcept nogil


cpdef enum __futex_define__:
    FUTEX_WAIT = __FUTEX_WAIT
    FUTEX_WAKE = __FUTEX_WAKE
    FUTEX_FD = __FUTEX_FD
    FUTEX_REQUEUE = __FUTEX_REQUEUE
    FUTEX_CMP_REQUEUE = __FUTEX_CMP_REQUEUE
    FUTEX_WAKE_OP = __FUTEX_WAKE_OP
    FUTEX_WAIT_BITSET = __FUTEX_WAIT_BITSET
    FUTEX_WAKE_BITSET = __FUTEX_WAKE_BITSET
    FUTEX_LOCK_PI = __FUTEX_LOCK_PI
    FUTEX_LOCK_PI2 = __FUTEX_LOCK_PI2
    FUTEX_TRYLOCK_PI = __FUTEX_TRYLOCK_PI
    FUTEX_UNLOCK_PI = __FUTEX_UNLOCK_PI
    FUTEX_CMP_REQUEUE_PI = __FUTEX_CMP_REQUEUE_PI
    FUTEX_WAIT_REQUEUE_PI = __FUTEX_WAIT_REQUEUE_PI

    FUTEX2_PRIVATE = __FUTEX2_PRIVATE

    FUTEX2_SIZE_U8 = __FUTEX2_SIZE_U8
    FUTEX2_SIZE_U16 = __FUTEX2_SIZE_U16
    FUTEX2_SIZE_U32 = __FUTEX2_SIZE_U32
    FUTEX2_SIZE_U64 = __FUTEX2_SIZE_U64
    FUTEX2_NUMA = __FUTEX2_NUMA

    FUTEX_WAITV_MAX = __FUTEX_WAITV_MAX
    FUTEX_BITSET_MATCH_ANY = __FUTEX_BITSET_MATCH_ANY
