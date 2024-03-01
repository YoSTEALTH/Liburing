from .lib.uring cimport *
from .type cimport sigset
from .error cimport trap_error
from .queue cimport io_uring_params


#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset sig) nogil
cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset sig,
                          size_t sz) nogil
cpdef int io_uring_setup(unsigned int entries, io_uring_params p) nogil
cpdef int io_uring_register(unsigned int fd,
                            unsigned int opcode,
                            const unsigned char[:] arg,
                            unsigned int nr_args) nogil
