from .type cimport *


cdef extern from '<sys/epoll.h>' nogil:
    ctypedef union epoll_data_t:
        void*    ptr
        int      fd
        uint32_t u32
        uint64_t u64

    struct __epoll_event 'epoll_event':
        uint32_t     events  # Epoll events
        epoll_data_t data    # User data variable

    # TODO: need to add epoll flags
