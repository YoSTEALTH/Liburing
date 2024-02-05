from libc.errno cimport errno
from libc.string cimport strerror


cpdef int trap_error(int no)
cpdef void raise_error(signed int no=?)
cpdef void memory_error(object cls)
