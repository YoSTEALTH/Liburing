from libc.errno cimport errno
from libc.string cimport strerror


cpdef int trap_error(int no, str msg=?) except -1 nogil
cdef void raise_error(int no=?, str msg=?)
cpdef void memory_error(object cls, str msg=?)
cpdef void index_error(object cls, unsigned int, str msg=?)
