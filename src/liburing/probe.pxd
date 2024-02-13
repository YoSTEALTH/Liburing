from .type cimport bool
from .io_uring cimport io_uring_probe_t
from .liburing cimport io_uring_t, io_uring


cdef class io_uring_probe:
    cdef io_uring_probe_t * ptr


cdef extern from * nogil:
    io_uring_probe_t * io_uring_get_probe_ring_c 'io_uring_get_probe_ring'(io_uring_t *ring)
    io_uring_probe_t * io_uring_get_probe_c 'io_uring_get_probe'()  # note: (void) is removed
    void io_uring_free_probe_c 'io_uring_free_probe'(io_uring_probe_t *probe)
    bool io_uring_opcode_supported_c 'io_uring_opcode_supported'(io_uring_probe_t *p, int op)
    int io_uring_register_probe_c 'io_uring_register_probe'(io_uring_t *ring,
                                                            io_uring_probe_t *p,
                                                            unsigned int nr)


cpdef io_uring_probe io_uring_get_probe_ring(io_uring ring)
cpdef io_uring_probe io_uring_get_probe()
cpdef void io_uring_free_probe(io_uring_probe probe)
cpdef bool io_uring_opcode_supported(io_uring_probe p, int op)
cpdef int io_uring_register_probe(io_uring ring, io_uring_probe p, unsigned int nr)


cpdef dict probe
