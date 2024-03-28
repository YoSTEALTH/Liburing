from .queue cimport *


cpdef void io_uring_prep_mkdir(io_uring_sqe sqe, const char *path, mode_t mode=?) noexcept nogil
cpdef void io_uring_prep_mkdirat(io_uring_sqe sqe,
                                 const char *path,
                                 mode_t mode=?,
                                 int dfd=?) noexcept nogil

cpdef void io_uring_prep_rename(io_uring_sqe sqe,
                                const char *oldpath,
                                const char *newpath) noexcept nogil
cpdef void io_uring_prep_renameat(io_uring_sqe sqe,
                                  const char *oldpath,
                                  const char *newpath,
                                  int olddfd=?,
                                  int newdfd=?,
                                  unsigned int flags=?) noexcept nogil

cpdef void io_uring_prep_symlinkat(io_uring_sqe sqe,
                                   const char *target,
                                   const char *linkpath,
                                   int newdirfd=?) noexcept nogil
cpdef void io_uring_prep_symlink(io_uring_sqe sqe,
                                 const char *target,
                                 const char *linkpath) noexcept nogil

cpdef void io_uring_prep_link(io_uring_sqe sqe,
                              const char *oldpath,
                              const char *newpath,
                              int flags=?) noexcept nogil
cpdef void io_uring_prep_linkat(io_uring_sqe sqe,
                                const char *oldpath,
                                const char *newpath,
                                int olddfd=?,
                                int newdfd=?,
                                int flags=?) noexcept nogil
cpdef void io_uring_prep_unlink(io_uring_sqe sqe,
                                const char *path,
                                int flags=?) noexcept nogil
cpdef void io_uring_prep_unlinkat(io_uring_sqe sqe,
                                  const char *path,
                                  int flags=?,
                                  int dfd=?) noexcept nogil

cpdef void io_uring_prep_fallocate(io_uring_sqe sqe,
                                   int fd,
                                   __u64 len,
                                   __u64 offset=?,
                                   int mode=?) noexcept nogil

cpdef void io_uring_prep_splice(io_uring_sqe sqe,
                                int fd_in,
                                int64_t off_in,
                                int fd_out,
                                int64_t off_out,
                                unsigned int nbytes,
                                unsigned int splice_flags) noexcept nogil


cpdef enum __os_define__:
    SPLICE_F_FD_IN_FIXED = __SPLICE_F_FD_IN_FIXED

    # flags for `renameat2`.
    RENAME_NOREPLACE = __RENAME_NOREPLACE
    RENAME_EXCHANGE = __RENAME_EXCHANGE
    RENAME_WHITEOUT = __RENAME_WHITEOUT

    # `fallocate` mode
    FALLOC_FL_KEEP_SIZE = __FALLOC_FL_KEEP_SIZE
    FALLOC_FL_PUNCH_HOLE = __FALLOC_FL_PUNCH_HOLE
    FALLOC_FL_NO_HIDE_STALE = __FALLOC_FL_NO_HIDE_STALE
    FALLOC_FL_COLLAPSE_RANGE = __FALLOC_FL_COLLAPSE_RANGE
    FALLOC_FL_ZERO_RANGE = __FALLOC_FL_ZERO_RANGE
    FALLOC_FL_INSERT_RANGE = __FALLOC_FL_INSERT_RANGE
    FALLOC_FL_UNSHARE_RANGE = __FALLOC_FL_UNSHARE_RANGE

    # splice flags
    SPLICE_F_MOVE = __SPLICE_F_MOVE
    SPLICE_F_NONBLOCK = __SPLICE_F_NONBLOCK
    SPLICE_F_MORE = __SPLICE_F_MORE
    SPLICE_F_GIFT = __SPLICE_F_GIFT
