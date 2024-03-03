cpdef inline void io_uring_prep_mkdir(io_uring_sqe sqe,
                                      const char *path,
                                      mode_t mode=0o777) noexcept nogil:
    __io_uring_prep_mkdir(sqe.ptr, path, mode)

cpdef inline void io_uring_prep_mkdirat(io_uring_sqe sqe,
                                        const char *path,
                                        mode_t mode=0o777,
                                        int dfd=__AT_FDCWD) noexcept nogil:
    __io_uring_prep_mkdirat(sqe.ptr, dfd, path, mode)


cpdef inline void io_uring_prep_rename(io_uring_sqe sqe,
                                       const char *oldpath,
                                       const char *newpath) noexcept nogil:
    __io_uring_prep_rename(sqe.ptr, oldpath, newpath)

cpdef inline void io_uring_prep_renameat(io_uring_sqe sqe,
                                         const char *oldpath,
                                         const char *newpath,
                                         int olddfd=__AT_FDCWD,
                                         int newdfd=__AT_FDCWD,
                                         unsigned int flags=0) noexcept nogil:
    '''
        Flags
            RENAME_NOREPLACE
            RENAME_EXCHANGE
            RENAME_WHITEOUT
    '''
    __io_uring_prep_renameat(sqe.ptr, olddfd, oldpath, newdfd, newpath, flags)


cpdef inline void io_uring_prep_symlinkat(io_uring_sqe sqe,
                                          const char *target,
                                          const char *linkpath,
                                          int newdirfd=__AT_FDCWD) noexcept nogil:
    __io_uring_prep_symlinkat(sqe.ptr, target, newdirfd, linkpath)

cpdef inline void io_uring_prep_symlink(io_uring_sqe sqe,
                                        const char *target,
                                        const char *linkpath) noexcept nogil:
    __io_uring_prep_symlink(sqe.ptr, target, linkpath)


cpdef inline void io_uring_prep_link(io_uring_sqe sqe,
                                     const char *oldpath,
                                     const char *newpath,
                                     int flags=0) noexcept nogil:
    __io_uring_prep_link(sqe.ptr, oldpath, newpath, flags)

cpdef inline void io_uring_prep_linkat(io_uring_sqe sqe,
                                       const char *oldpath,
                                       const char *newpath,
                                       int olddfd=__AT_FDCWD,
                                       int newdfd=__AT_FDCWD,
                                       int flags=0) noexcept nogil:
    __io_uring_prep_linkat(sqe.ptr, olddfd, oldpath, newdfd, newpath, flags)

cpdef inline void io_uring_prep_unlink(io_uring_sqe sqe,
                                       const char *path,
                                       int flags=0) noexcept nogil:
    __io_uring_prep_unlink(sqe.ptr, path, flags)

cpdef inline void io_uring_prep_unlinkat(io_uring_sqe sqe,
                                         const char *path,
                                         int flags=0,
                                         int dfd=__AT_FDCWD) noexcept nogil:
    __io_uring_prep_unlinkat(sqe.ptr, dfd, path, flags)


cpdef inline void io_uring_prep_fallocate(io_uring_sqe sqe,
                                          int fd,
                                          __u64 len,
                                          __u64 offset=0,
                                          int mode=0) noexcept nogil:
    '''
        Mode
            FALLOC_FL_KEEP_SIZE       # default is extend size
            FALLOC_FL_PUNCH_HOLE      # de-allocates range
            FALLOC_FL_NO_HIDE_STALE   # reserved codepoint
            FALLOC_FL_COLLAPSE_RANGE
            FALLOC_FL_ZERO_RANGE
            FALLOC_FL_INSERT_RANGE
            FALLOC_FL_UNSHARE_RANGE
    '''
    __io_uring_prep_fallocate(sqe.ptr, fd, mode, offset, len)
