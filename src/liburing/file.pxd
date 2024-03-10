from .lib.uring cimport *
from .type cimport iovec
from .queue cimport io_uring, io_uring_sqe


cdef class open_how:
    cdef __open_how *ptr


cpdef void io_uring_prep_splice(io_uring_sqe sqe,
                                int fd_in,
                                int64_t off_in,
                                int fd_out,
                                int64_t off_out,
                                unsigned int nbytes,
                                unsigned int splice_flags) noexcept nogil
cpdef void io_uring_prep_tee(io_uring_sqe sqe,
                             int fd_in,
                             int fd_out,
                             unsigned int nbytes,
                             unsigned int splice_flags) noexcept nogil
cpdef void io_uring_prep_readv(io_uring_sqe sqe,
                               int fd,
                               iovec iovecs,
                               __u64 offset=?) noexcept nogil
cpdef void io_uring_prep_readv2(io_uring_sqe sqe,
                                int fd,
                                iovec iovecs,
                                __u64 offset=?,
                                int flags=?) noexcept nogil
cpdef void io_uring_prep_read_fixed(io_uring_sqe sqe,
                                    int fd,
                                    char *buf,
                                    unsigned int nbytes,
                                    __u64 offset,
                                    int buf_index) noexcept nogil
cpdef void io_uring_prep_writev(io_uring_sqe sqe,
                                int fd,
                                iovec iovecs,
                                unsigned int nr_vecs,
                                __u64 offset) noexcept nogil
cpdef void io_uring_prep_writev2(io_uring_sqe sqe,
                                 int fd,
                                 iovec iovecs,
                                 unsigned int nr_vecs,
                                 __u64 offset,
                                 int flags) noexcept nogil
cpdef void io_uring_prep_write_fixed(io_uring_sqe sqe,
                                     int fd,
                                     char *buf,
                                     unsigned int nbytes,
                                     __u64 offset,
                                     int buf_index) noexcept nogil
cpdef void io_uring_prep_fsync(io_uring_sqe sqe,
                               int fd,
                               unsigned int fsync_flags=?) noexcept nogil
cpdef void io_uring_prep_sync_file_range(io_uring_sqe sqe,
                                         int fd,
                                         unsigned int len=?,
                                         __u64 offset=?,
                                         int flags=?) noexcept nogil
cpdef void io_uring_prep_openat(io_uring_sqe sqe,
                                const char *path,
                                int flags=?,
                                mode_t mode=?,
                                int dfd=?) noexcept nogil
cpdef void io_uring_prep_openat2(io_uring_sqe sqe,
                                 const char *path,
                                 open_how how,
                                 int dfd=?) noexcept nogil
cpdef void io_uring_prep_openat_direct(io_uring_sqe sqe,
                                       const char *path,
                                       int flags=?,
                                       unsigned int file_index=?,
                                       mode_t mode=?,
                                       int dfd=?) noexcept nogil
cpdef void io_uring_prep_openat2_direct(io_uring_sqe sqe,
                                        const char *path,
                                        open_how how,
                                        unsigned int file_index=?,
                                        int dfd=?) noexcept nogil
cpdef void io_uring_prep_read(io_uring_sqe sqe,
                              int fd,
                              unsigned char[:] buf,  # `void *buf`
                              unsigned int nbytes,
                              __u64 offset) noexcept nogil
cpdef void io_uring_prep_read_multishot(io_uring_sqe sqe,
                                        int fd,
                                        unsigned int nbytes,
                                        __u64 offset,
                                        int buf_group) noexcept nogil
cpdef void io_uring_prep_write(io_uring_sqe sqe,
                               int fd,
                               const unsigned char[:] buf,  # `const void * buf`
                               unsigned int nbytes,
                               __u64 offset) noexcept nogil

cpdef void io_uring_prep_files_update(io_uring_sqe sqe, list[int] fds, int offset=?)

cpdef void io_uring_prep_ftruncate(io_uring_sqe sqe, int fd, loff_t len) noexcept nogil
