from .type cimport *


# note: Linux 6.7+
#       `io_uring` uses `futex2`, not `futex`
cdef extern from '<linux/futex.h>' nogil:
    struct __futex_waitv 'futex_waitv':
        __u64 val           # expected value at `uaddr`
        __u64 uaddr         # user address to wait on
        __u32 flags         # flags for this waiter
        __u32 __reserved    # reserved member to preserve data alignment. Should be `0`.

    # NOTE: linux version 6.7 +

    # # Catch Result(s)
    # __u8 __FUTEX_WAIT 'FUTEX_WAIT'
    # __u8 __FUTEX_WAKE 'FUTEX_WAKE'
    # __u8 __FUTEX_FD 'FUTEX_FD'
    # __u8 __FUTEX_REQUEUE 'FUTEX_REQUEUE'
    # __u8 __FUTEX_CMP_REQUEUE 'FUTEX_CMP_REQUEUE'
    # __u8 __FUTEX_WAKE_OP 'FUTEX_WAKE_OP'
    # __u8 __FUTEX_WAIT_BITSET 'FUTEX_WAIT_BITSET'
    # __u8 __FUTEX_WAKE_BITSET 'FUTEX_WAKE_BITSET'
    # __u8 __FUTEX_LOCK_PI 'FUTEX_LOCK_PI'
    # __u8 __FUTEX_LOCK_PI2 'FUTEX_LOCK_PI2'
    # __u8 __FUTEX_TRYLOCK_PI 'FUTEX_TRYLOCK_PI'
    # __u8 __FUTEX_UNLOCK_PI 'FUTEX_UNLOCK_PI'
    # __u8 __FUTEX_CMP_REQUEUE_PI 'FUTEX_CMP_REQUEUE_PI'
    # __u8 __FUTEX_WAIT_REQUEUE_PI 'FUTEX_WAIT_REQUEUE_PI'

    # # a futex can be either private or shared. private is used for processes that shares the
    # # same memory space and the virtual address of the futex will be the same for all processes.
    # # this allows for optimizations in the kernel. to use private flag:
    # # e.g `__FUTEX2_PRIVATE | __FUTEX_WAIT`
    # __u8 __FUTEX2_PRIVATE 'FUTEX2_PRIVATE'

    # # Flags for `futex2` syscalls.
    # __u8 __FUTEX2_SIZE_U8 'FUTEX2_SIZE_U8'
    # __u8 __FUTEX2_SIZE_U16 'FUTEX2_SIZE_U16'
    # __u8 __FUTEX2_SIZE_U32 'FUTEX2_SIZE_U32'
    # __u8 __FUTEX2_SIZE_U64 'FUTEX2_SIZE_U64'
    # __u8 __FUTEX2_NUMA 'FUTEX2_NUMA'

    # # max numbers of elements in a `futex_waitv` array
    # __u8 __FUTEX_WAITV_MAX 'FUTEX_WAITV_MAX'

    # # mask - bitset with all bits set for the `FUTEX_*_BITSET` OPs to request a match of any bit.
    # __u32 __FUTEX_BITSET_MATCH_ANY 'FUTEX_BITSET_MATCH_ANY'
