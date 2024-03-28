cdef class open_how:
    ''' How to Open a Path

        Example
            >>> how = open_how(O_CREAT | O_RDWR, 0o777, RESOLVE_CACHED)
            >>> io_uring_prep_openat2(..., how)

            # or

            >>> how = open_how()
            >>> how.flags   = O_CREAT | O_RDWR
            >>> how.mode    = 0
            >>> how.resolve = RESOLVE_CACHED
            >>> io_uring_prep_openat2(..., how)

        flags
            O_CREAT
            O_RDWR
            O_RDONLY
            O_WRONLY
            O_TMPFILE
            ...

        Resolve
            RESOLVE_BENEATH
            RESOLVE_IN_ROOT
            RESOLVE_NO_MAGICLINKS
            RESOLVE_NO_SYMLINKS
            RESOLVE_NO_XDEV
            RESOLVE_CACHED

        Note
            - `mode` is only to set when creating new or temp file.
            - You can use same `open_how()` reference if opening multiple files with same settings.
    '''
    def __cinit__(self, __u64 flags=0, __u64 mode=0, __u64 resolve=0):
        self.ptr = <__open_how*>PyMem_RawCalloc(1, sizeof(__open_how))
        if self.ptr is NULL:
            memory_error(self)

        if flags or mode or resolve:
            self.ptr.mode = mode
            self.ptr.flags = flags
            self.ptr.resolve = resolve

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def mode(self):
        return self.ptr.mode

    @mode.setter
    def mode(self, __u64 mode):
        self.ptr.mode = mode

    @property
    def flags(self):
        return self.ptr.flags

    @flags.setter
    def flags(self, __u64 flags):
        self.ptr.flags = flags

    @property
    def resolve(self):
        return self.ptr.resolve

    @resolve.setter
    def resolve(self, __u64 resolve):
        self.ptr.resolve = resolve


cpdef inline void io_uring_prep_tee(io_uring_sqe sqe,
                                    int fd_in,
                                    int fd_out,
                                    unsigned int nbytes,
                                    unsigned int splice_flags) noexcept nogil:
    __io_uring_prep_tee(sqe.ptr, fd_in, fd_out, nbytes, splice_flags)

cpdef inline void io_uring_prep_readv(io_uring_sqe sqe,
                                      int fd,
                                      iovec iovecs,
                                      __u64 offset=0) noexcept nogil:
    __io_uring_prep_readv(sqe.ptr, fd, iovecs.ptr, iovecs.len, offset)

cpdef inline void io_uring_prep_readv2(io_uring_sqe sqe,
                                       int fd,
                                       iovec iovecs,
                                       __u64 offset=0,
                                       int flags=0) noexcept nogil:
    __io_uring_prep_readv2(sqe.ptr, fd, iovecs.ptr, iovecs.len, offset, flags)

cpdef inline void io_uring_prep_read_fixed(io_uring_sqe sqe,
                                           int fd,
                                           char *buf,
                                           unsigned int nbytes,
                                           __u64 offset,
                                           int buf_index) noexcept nogil:
    __io_uring_prep_read_fixed(sqe.ptr, fd, buf, nbytes, offset, buf_index)

cpdef inline void io_uring_prep_writev(io_uring_sqe sqe,
                                       int fd,
                                       iovec iovecs,
                                       unsigned int nr_vecs,
                                       __u64 offset) noexcept nogil:
    __io_uring_prep_writev(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset)

cpdef inline void io_uring_prep_writev2(io_uring_sqe sqe,
                                        int fd,
                                        iovec iovecs,
                                        unsigned int nr_vecs,
                                        __u64 offset,
                                        int flags) noexcept nogil:
    __io_uring_prep_writev2(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset, flags)

cpdef inline void io_uring_prep_write_fixed(io_uring_sqe sqe,
                                            int fd,
                                            char *buf,
                                            unsigned int nbytes,
                                            __u64 offset,
                                            int buf_index) noexcept nogil:
    __io_uring_prep_write_fixed(sqe.ptr, fd, buf, nbytes, offset, buf_index)

cpdef inline void io_uring_prep_fsync(io_uring_sqe sqe,
                                      int fd,
                                      unsigned int fsync_flags=0) noexcept nogil:
    __io_uring_prep_fsync(sqe.ptr, fd, fsync_flags)

cpdef inline void io_uring_prep_sync_file_range(io_uring_sqe sqe,
                                                int fd,
                                                unsigned int len=0,
                                                __u64 offset=0,
                                                int flags=0) noexcept nogil:
    __io_uring_prep_sync_file_range(sqe.ptr, fd, len, offset, flags)

cpdef inline void io_uring_prep_openat(io_uring_sqe sqe,
                                       const char *path,
                                       int flags=__O_RDONLY,
                                       mode_t mode=0o777,
                                       int dfd=__AT_FDCWD) noexcept nogil:
    ''' Open File

        Example
            >>> sqe = io_uring_get_sqe(ring)
            >>> io_uring_prep_openat(sqe, b'./file.ext')
            >>> sqe.user_data = 123
            ...
            >>> io_uring_submit(ring)
            >>> io_uring_wait_cqe(ring, cqe)
            ...
            >>> assert cqe.user_data == 123
            >>> fd = trap_error(cqe.res)
    '''
    __io_uring_prep_openat(sqe.ptr, dfd, path, flags, mode)

cpdef inline void io_uring_prep_openat2(io_uring_sqe sqe,
                                        const char *path,
                                        open_how how,
                                        int dfd=__AT_FDCWD) noexcept nogil:
    __io_uring_prep_openat2(sqe.ptr, dfd, path, how.ptr)

cpdef inline void io_uring_prep_openat_direct(io_uring_sqe sqe,
                                              const char *path,
                                              int flags=__O_RDONLY,
                                              unsigned int file_index=__IORING_FILE_INDEX_ALLOC,
                                              mode_t mode=0o777,
                                              int dfd=__AT_FDCWD) noexcept nogil:
    ''' Note
            - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
            Allocated descriptor is returned in the `cqe.res`.
    '''
    __io_uring_prep_openat_direct(sqe.ptr, dfd, path, flags, mode, file_index)

cpdef inline void io_uring_prep_openat2_direct(io_uring_sqe sqe,
                                               const char *path,
                                               open_how how,
                                               unsigned int file_index=__IORING_FILE_INDEX_ALLOC,
                                               int dfd=__AT_FDCWD) noexcept nogil:
    ''' Note
            - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
            Allocated descriptor is returned in the `cqe.res`.
    '''
    __io_uring_prep_openat2_direct(sqe.ptr, dfd, path, how.ptr, file_index)

cpdef inline void io_uring_prep_read(io_uring_sqe sqe,
                                     int fd,
                                     unsigned char[:] buf,  # `void *buf`
                                     unsigned int nbytes,
                                     __u64 offset) noexcept nogil:
    __io_uring_prep_read(sqe.ptr, fd, &buf[0], nbytes, offset)

cpdef inline void io_uring_prep_read_multishot(io_uring_sqe sqe,
                                               int fd,
                                               unsigned int nbytes,
                                               __u64 offset,
                                               int buf_group) noexcept nogil:
    __io_uring_prep_read_multishot(sqe.ptr, fd, nbytes, offset, buf_group)

cpdef inline void io_uring_prep_write(io_uring_sqe sqe,
                                      int fd,
                                      const unsigned char[:] buf,  # `const void *buf`
                                      unsigned int nbytes,
                                      __u64 offset) noexcept nogil:
    __io_uring_prep_write(sqe.ptr, fd, &buf[0], nbytes, offset)

cpdef inline void io_uring_prep_files_update(io_uring_sqe sqe, list[int] fds, int offset=0):
    cdef array[int] _fds = array('i', fds)
    __io_uring_prep_files_update(sqe.ptr, _fds.data.as_ints, len(_fds), offset)

cpdef inline void io_uring_prep_ftruncate(io_uring_sqe sqe, int fd, loff_t len) noexcept nogil:
    __io_uring_prep_ftruncate(sqe.ptr, fd, len)
