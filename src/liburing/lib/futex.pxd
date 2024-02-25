from .type cimport *


cdef extern from '<linux/futex.h>' nogil:
    struct __futex_waitv 'futex_waitv':
        __u64 val
        __u64 uaddr
        __u32 flags
        __u32 __reserved
