from .lib.uring cimport *


cdef class io_uring_params:
    cdef __io_uring_params * ptr

cdef class io_uring_restriction:
    cdef __io_uring_restriction * ptr

cdef class io_uring_buf_reg:
    cdef __io_uring_buf_reg * ptr

cdef class io_uring_sync_cancel_reg:
    cdef __io_uring_sync_cancel_reg * ptr

cdef class io_uring_buf_ring:
    cdef __io_uring_buf_ring * ptr
