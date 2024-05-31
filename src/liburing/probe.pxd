from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .lib.uring cimport *
from .error cimport trap_error, memory_error
from .queue cimport io_uring


cdef class io_uring_probe:
    cdef:
        __io_uring_probe*   ptr
        unsigned int        len

cpdef io_uring_probe io_uring_get_probe_ring(io_uring ring)
cpdef io_uring_probe io_uring_get_probe()
cpdef void io_uring_free_probe(io_uring_probe probe)
cpdef bool io_uring_opcode_supported(io_uring_probe p, int op)
cpdef int io_uring_register_probe(io_uring ring, io_uring_probe p, unsigned int nr)
