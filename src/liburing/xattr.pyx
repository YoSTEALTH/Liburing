cpdef inline void io_uring_prep_setxattr(io_uring_sqe sqe,
                                         const char *name,
                                         const char *value,
                                         const char *path,
                                         unsigned int len,
                                         int flags=0) noexcept nogil:
    __io_uring_prep_setxattr(sqe.ptr, name, value, path, flags, len)

cpdef inline void io_uring_prep_getxattr(io_uring_sqe sqe,
                                         const char *name,
                                         char *value,
                                         const char *path,
                                         unsigned int len) noexcept nogil:
    __io_uring_prep_getxattr(sqe.ptr, name, value, path, len)

cpdef inline void io_uring_prep_fsetxattr(io_uring_sqe sqe,
                                          int fd,
                                          const char *name,
                                          const char *value,
                                          unsigned int len,
                                          int flags=0) noexcept nogil:
    __io_uring_prep_fsetxattr(sqe.ptr, fd, name, value, flags, len)

cpdef inline void io_uring_prep_fgetxattr(io_uring_sqe sqe,
                                          int fd,
                                          const char *name,
                                          char *value,
                                          unsigned int len) noexcept nogil:
    __io_uring_prep_fgetxattr(sqe.ptr, fd, name, value, len)
