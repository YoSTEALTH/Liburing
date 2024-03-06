# TODO: these classes will be moved later to appropriate files.
from posix.unistd cimport _SC_IOV_MAX
from .lib.type cimport *


cpdef enum __define__:
    SC_IOV_MAX = _SC_IOV_MAX


cdef class iovec:
    cdef:
        __iovec *ptr
        list ref  # TODO: replace this with array() ?
        unsigned int len

cdef class siginfo:
    cdef siginfo_t *ptr

cdef class sigset:
    cdef sigset_t *ptr
