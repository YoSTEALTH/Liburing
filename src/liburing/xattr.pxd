from .lib.uring cimport __io_uring_prep_setxattr, __io_uring_prep_getxattr, \
                        __io_uring_prep_fsetxattr, __io_uring_prep_fgetxattr
from .queue cimport io_uring_sqe


cpdef void io_uring_prep_setxattr(io_uring_sqe sqe,
                                  const char *name,
                                  const char *value,
                                  const char *path,
                                  unsigned int len,
                                  int flags=?) noexcept nogil
cpdef void io_uring_prep_getxattr(io_uring_sqe sqe,
                                  const char *name,
                                  char *value,
                                  const char *path,
                                  unsigned int len) noexcept nogil
cpdef void io_uring_prep_fsetxattr(io_uring_sqe sqe,
                                   int fd,
                                   const char *name,
                                   const char *value,
                                   unsigned int len,
                                   int flags=?) noexcept nogil
cpdef void io_uring_prep_fgetxattr(io_uring_sqe sqe,
                                   int fd,
                                   const char *name,
                                   char *value,
                                   unsigned int len) noexcept nogil
