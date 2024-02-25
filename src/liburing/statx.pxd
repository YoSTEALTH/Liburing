from .lib.statx cimport __statx


cdef class statx:
    cdef __statx * ptr
