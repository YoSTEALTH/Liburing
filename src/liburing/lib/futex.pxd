from .type cimport *


# note: `io_uring` uses `futex2`, not `futex`
cdef extern from '<linux/futex.h>' nogil:
    struct __futex_waitv 'futex_waitv':
        __u64 val           # expected value at uaddr
        __u64 uaddr         # user address to wait on
        __u32 flags         # flags for this waiter
        __u32 __reserved    # reserved member to preserve data alignment. Should be `0`.

    # Catch Result(s)
    __u8 __FUTEX_WAIT_BITSET 'FUTEX_WAIT_BITSET'
    __u8 __FUTEX_WAKE_BITSET 'FUTEX_WAKE_BITSET'

    # Flags for `futex2` syscalls.
    __u8 __FUTEX2_SIZE_U8 'FUTEX2_SIZE_U8'
    __u8 __FUTEX2_SIZE_U16 'FUTEX2_SIZE_U16'
    __u8 __FUTEX2_SIZE_U32 'FUTEX2_SIZE_U32'
    __u8 __FUTEX2_SIZE_U64 'FUTEX2_SIZE_U64'
    __u8 __FUTEX2_NUMA 'FUTEX2_NUMA'

    # a futex can be either private or shared. private is used for processes that shares the
    # same memory space and the virtual address of the futex will be the same for all processes.
    # this allows for optimizations in the kernel.
    __u8 __FUTEX2_PRIVATE 'FUTEX2_PRIVATE'

    # max numbers of elements in a `futex_waitv` array
    __u8 __FUTEX_WAITV_MAX 'FUTEX_WAITV_MAX'

    # mask - bitset with all bits set for the `FUTEX_*_BITSET` OPs to request a match of any bit.
    __u32 __FUTEX_BITSET_MATCH_ANY 'FUTEX_BITSET_MATCH_ANY'
