#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset sig) nogil:
    return trap_error(__io_uring_enter(fd, to_submit, min_complete, flags, sig.ptr))

cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset sig,
                          size_t sz) nogil:
    return trap_error(__io_uring_enter2(fd, to_submit, min_complete, flags, sig.ptr, sz))

cpdef int io_uring_setup(unsigned int entries,
                         io_uring_params p) nogil:
    return trap_error(__io_uring_setup(entries, p.ptr))
