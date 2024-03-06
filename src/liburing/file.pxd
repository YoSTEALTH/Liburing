from .lib.uring cimport *
from .type cimport iovec
from .queue cimport io_uring, io_uring_sqe


cpdef enum __define__:
    RESOLVE_NO_XDEV = __RESOLVE_NO_XDEV
    RESOLVE_NO_MAGICLINKS = __RESOLVE_NO_MAGICLINKS
    RESOLVE_NO_SYMLINKS = __RESOLVE_NO_SYMLINKS
    RESOLVE_BENEATH = __RESOLVE_BENEATH
    RESOLVE_IN_ROOT = __RESOLVE_IN_ROOT
    RESOLVE_CACHED = __RESOLVE_CACHED

    SYNC_FILE_RANGE_WAIT_BEFORE = __SYNC_FILE_RANGE_WAIT_BEFORE
    SYNC_FILE_RANGE_WRITE = __SYNC_FILE_RANGE_WRITE
    SYNC_FILE_RANGE_WAIT_AFTER = __SYNC_FILE_RANGE_WAIT_AFTER

    O_ACCMODE = __O_ACCMODE
    O_RDONLY = __O_RDONLY
    O_WRONLY = __O_WRONLY
    O_RDWR = __O_RDWR

    O_APPEND = __O_APPEND
    O_ASYNC = __O_ASYNC
    O_CLOEXEC = __O_CLOEXEC
    O_CREAT = __O_CREAT

    O_DIRECT = __O_DIRECT
    O_DIRECTORY = __O_DIRECTORY
    O_DSYNC = __O_DSYNC
    O_EXCL = __O_EXCL
    O_LARGEFILE = __O_LARGEFILE
    O_NOATIME = __O_NOATIME
    O_NOCTTY = __O_NOCTTY
    O_NOFOLLOW = __O_NOFOLLOW
    O_NONBLOCK = __O_NONBLOCK
    O_PATH = __O_PATH

    O_SYNC = __O_SYNC
    O_TMPFILE = __O_TMPFILE
    O_TRUNC = __O_TRUNC

    S_IRWXU = __S_IRWXU
    S_IRUSR = __S_IRUSR
    S_IWUSR = __S_IWUSR
    S_IXUSR = __S_IXUSR
    S_IRWXG = __S_IRWXG
    S_IRGRP = __S_IRGRP
    S_IWGRP = __S_IWGRP
    S_IXGRP = __S_IXGRP
    S_IRWXO = __S_IRWXO
    S_IROTH = __S_IROTH
    S_IWOTH = __S_IWOTH
    S_IXOTH = __S_IXOTH

    S_ISUID = __S_ISUID
    S_ISGID = __S_ISGID
    S_ISVTX = __S_ISVTX


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
                                       unsigned int file_index,
                                       int flags=?,
                                       mode_t mode=?,
                                       int dfd=?) noexcept nogil
cpdef void io_uring_prep_openat2_direct(io_uring_sqe sqe,
                                        const char *path,
                                        unsigned int file_index,
                                        open_how how,
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
