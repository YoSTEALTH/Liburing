cdef class io_uring_probe:

    def __cinit__(self, unsigned int num=0):
        if num:
            self.ptr = <__io_uring_probe*>PyMem_RawCalloc(
                num, sizeof(__io_uring_probe) + num * sizeof(__io_uring_probe_op)
            )
            if self.ptr is NULL:
                memory_error(self)
            self.len = num

    def __dealloc__(self):
        if self.len and self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def last_op(self):
        if self.ptr is not NULL:
            return self.ptr.last_op
        memory_error(self)

    @property
    def ops_len(self):
        if self.ptr is not NULL:
            return self.ptr.ops_len
        memory_error(self)

cpdef io_uring_probe io_uring_get_probe_ring(io_uring ring):
    cdef io_uring_probe probe = io_uring_probe()
    probe.ptr = __io_uring_get_probe_ring(&ring.ptr)
    return probe

cpdef io_uring_probe io_uring_get_probe():
    cdef io_uring_probe probe = io_uring_probe()
    probe.ptr = __io_uring_get_probe()
    return probe

cpdef void io_uring_free_probe(io_uring_probe probe):
    __io_uring_free_probe(probe.ptr)
    probe.ptr = NULL

cpdef inline bool io_uring_opcode_supported(io_uring_probe p, int op):
    return __io_uring_opcode_supported(p.ptr, op)

cpdef int io_uring_register_probe(io_uring ring, io_uring_probe p, unsigned int nr):
    return trap_error(__io_uring_register_probe(&ring.ptr, p.ptr, nr))
