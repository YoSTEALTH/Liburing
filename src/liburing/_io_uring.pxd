from .lib.uring cimport *


cdef class io_uring:
    cdef __io_uring *ptr

cdef class io_uring_sqe:
    cdef:
        __io_uring_sqe * ptr
        unsigned int len
        list ref  # TODO: replace with `array()` # index object reference holder

cdef class io_uring_cqe:
    cdef __io_uring_cqe * ptr

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
