cpdef int trap_error(int no) except -1 nogil
cdef void raise_error(int no=?)
cpdef void memory_error(object cls, str msg=?)
cpdef void index_error(object cls, unsigned int, str msg=?)
