from libc.stdlib cimport free
from .helper cimport trap_error
from .io_uring cimport IORING_OP_LAST, io_uring_op


cdef class io_uring_probe:
    def __dealloc__(self):
        # just in case user forgets to call `io_uring_free_probe` or error happened 
        if self.ptr is not NULL:
            io_uring_free_probe_c(self.ptr)


cpdef io_uring_probe io_uring_get_probe_ring(io_uring ring):
    cdef io_uring_probe probe = io_uring_probe()
    probe.ptr = io_uring_get_probe_ring_c(ring.ptr)
    return probe

cpdef io_uring_probe io_uring_get_probe():
    cdef io_uring_probe probe = io_uring_probe()
    probe.ptr = io_uring_get_probe_c()
    return probe

cpdef void io_uring_free_probe(io_uring_probe probe):
    io_uring_free_probe_c(probe.ptr)
    if probe.ptr is not NULL:
        probe.ptr = NULL  # account for C Liburing bug

cpdef inline bool io_uring_opcode_supported(io_uring_probe p, int op):
    return io_uring_opcode_supported_c(p.ptr, op)

cpdef int io_uring_register_probe(io_uring ring, io_uring_probe p, unsigned int nr):
    return trap_error(io_uring_register_probe_c(ring.ptr, p.ptr, nr))
