#cython: boundscheck=False

cdef class open_how:
    ''' How to Open a Pathname

        Example
            >>> how = open_how(O_RDWR, 0, RESOLVE_CACHED)
            >>> io_uring_prep_openat2(..., how)

            # or

            >>> how = open_how()
            >>> how.flags   = O_RDWR
            >>> how.mode    = 0o777
            >>> how.resolve = RESOLVE_CACHED
            >>> io_uring_prep_openat2(..., how)

        Resolve
            RESOLVE_BENEATH
            RESOLVE_IN_ROOT
            RESOLVE_NO_MAGICLINKS
            RESOLVE_NO_SYMLINKS
            RESOLVE_NO_XDEV
            RESOLVE_CACHED

        Note
            - visit https://man7.org/linux/man-pages/man2/openat2.2.html for more information.
    '''
    def __cinit__(self, __u64 flags=0, __u64 mode=0, __u64 resolve=0):
        self.ptr = <open_how_t*>PyMem_RawCalloc(1, sizeof(open_how_t))
        if self.ptr is NULL:
            memory_error(self)

        if flags or mode or resolve:
            self.ptr.flags   = flags
            self.ptr.mode    = mode
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


cpdef int io_uring_register_files(io_uring ring, int files, unsigned int nr_files) nogil:
    return trap_error(io_uring_register_files_c(ring.ptr, &files, nr_files))

cpdef int io_uring_register_files_tags(io_uring ring,
                                       int files,
                                       __u64 tags,
                                       unsigned int nr) nogil:
    return trap_error(io_uring_register_files_tags_c(ring.ptr, &files, &tags, nr))

cpdef int io_uring_register_files_sparse(io_uring ring,
                                         unsigned int nr) nogil:
    return trap_error(io_uring_register_files_sparse_c(ring.ptr, nr))

cpdef int io_uring_register_files_update_tag(io_uring ring,
                                             unsigned int off,
                                             int files,
                                             __u64 tags,
                                             unsigned int nr_files) nogil:
    return trap_error(io_uring_register_files_update_tag_c(ring.ptr, off, &files, &tags, nr_files))

cpdef int io_uring_unregister_files(io_uring ring) nogil:
    return trap_error(io_uring_unregister_files_c(ring.ptr))

cpdef int io_uring_register_files_update(io_uring ring,
                                         unsigned int off,
                                         int files,
                                         unsigned int nr_files) nogil:
    return trap_error(io_uring_register_files_update_c(ring.ptr, off, &files, nr_files))


cpdef inline void io_uring_prep_splice(io_uring_sqe sqe,
                                       int fd_in,
                                       int64_t off_in,
                                       int fd_out,
                                       int64_t off_out,
                                       unsigned int nbytes,
                                       unsigned int splice_flags) noexcept nogil:
    '''
        Note
            `io_uring_prep_splice()` - Either `fd_in` or `fd_out` must be a pipe.

            - If `fd_in` refers to a pipe, `off_in` is ignored and must be set to `-1`.

            - If `fd_in` does not refer to a pipe and `off_in` is `-1`, then `nbytes` are read
              from `fd_in` starting from the file offset, which is incremented by the
              number of bytes read.

            - If `fd_in` does not refer to a pipe and `off_in` is not `-1`, then the starting
              offset of `fd_in` will be `off_in`.

            This splice operation can be used to implement sendfile by splicing to an
            intermediate pipe first, then splice to the final destination.
            In fact, the implementation of sendfile in kernel uses splice internally.

            NOTE that even if `fd_in` or `fd_out` refers to a pipe, the splice operation
            can still fail with `EINVAL` if one of the `fd` doesn't explicitly support splice
            operation, e.g. reading from terminal is unsupported from kernel 5.7 to 5.11.
            Check issue #291 for more information.
    '''
    io_uring_prep_splice_c(sqe.ptr, fd_in, off_in, fd_out, off_out, nbytes, splice_flags)

cpdef inline void io_uring_prep_tee(io_uring_sqe sqe,
                                     int fd_in,
                                     int fd_out,
                                     unsigned int nbytes,
                                     unsigned int splice_flags) noexcept nogil:
    io_uring_prep_tee_c(sqe.ptr, fd_in, fd_out, nbytes, splice_flags)

cpdef inline void io_uring_prep_readv(io_uring_sqe sqe,
                                      int fd,
                                      iovec iovecs,
                                      unsigned int nr_vecs,
                                      __u64 offset) noexcept nogil:
    io_uring_prep_readv_c(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset)

cpdef inline void io_uring_prep_readv2(io_uring_sqe sqe,
                                       int fd,
                                       iovec iovecs,
                                       unsigned int nr_vecs,
                                       __u64 offset,
                                       int flags) noexcept nogil:
    io_uring_prep_readv2_c(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset, flags)

cpdef inline void io_uring_prep_read_fixed(io_uring_sqe sqe,
                                           int fd,
                                           char *buf,
                                           unsigned int nbytes,
                                           __u64 offset,
                                           int buf_index) noexcept nogil:
    io_uring_prep_read_fixed_c(sqe.ptr, fd, buf, nbytes, offset, buf_index)

cpdef inline void io_uring_prep_writev(io_uring_sqe sqe,
                                       int fd,
                                       iovec iovecs,
                                       unsigned int nr_vecs,
                                       __u64 offset) noexcept nogil:
    io_uring_prep_writev_c(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset)

cpdef inline void io_uring_prep_writev2(io_uring_sqe sqe,
                                        int fd,
                                        iovec iovecs,
                                        unsigned int nr_vecs,
                                        __u64 offset,
                                        int flags) noexcept nogil:
    io_uring_prep_writev2_c(sqe.ptr, fd, iovecs.ptr, nr_vecs, offset, flags)

cpdef inline void io_uring_prep_write_fixed(io_uring_sqe sqe,
                                            int fd,
                                            char *buf,
                                            unsigned int nbytes,
                                            __u64 offset,
                                            int buf_index) noexcept nogil:
    io_uring_prep_write_fixed_c(sqe.ptr, fd, buf, nbytes, offset, buf_index)


cpdef inline void io_uring_prep_fsync(io_uring_sqe sqe,
                                      int fd,
                                      unsigned int fsync_flags) noexcept nogil:
    io_uring_prep_fsync_c(sqe.ptr, fd, fsync_flags)


cpdef inline void io_uring_prep_openat(io_uring_sqe sqe,
                                       int dfd,
                                       const char *path,
                                       int flags,
                                       mode_t mode) noexcept nogil:
    io_uring_prep_openat_c(sqe.ptr, dfd, path, flags, mode)

cpdef inline void io_uring_prep_openat2(io_uring_sqe sqe,
                                        int          dfd,
                                        const char  *path,
                                        open_how     how) noexcept nogil:
    io_uring_prep_openat2_c(sqe.ptr, dfd, path, how.ptr)

cpdef inline void io_uring_prep_openat_direct(io_uring_sqe sqe,
                                              int dfd,
                                              const char *path,
                                              int flags,
                                              mode_t mode,
                                              unsigned int file_index) noexcept nogil:
    io_uring_prep_openat_direct_c(sqe.ptr, dfd, path, flags, mode, file_index)

cpdef inline void io_uring_prep_openat2_direct(io_uring_sqe sqe,
                                               int          dfd,
                                               const char  *path,
                                               open_how     how,
                                               unsigned int file_index) noexcept nogil:
    io_uring_prep_openat2_direct_c(sqe.ptr, dfd, path, how.ptr, file_index)


cpdef inline void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil:
    io_uring_prep_close_c(sqe.ptr, fd)

cpdef inline void io_uring_prep_close_direct(io_uring_sqe sqe,
                                             unsigned int file_index) noexcept nogil:
    io_uring_prep_close_direct_c(sqe.ptr, file_index)

cpdef inline void io_uring_prep_read(io_uring_sqe sqe,
                                     int fd,
                                     unsigned char[:] buf,  # `void *buf`
                                     unsigned int nbytes,
                                     __u64 offset) noexcept nogil:
    io_uring_prep_read_c(sqe.ptr, fd, &buf[0], nbytes, offset)

cpdef inline void io_uring_prep_read_multishot(io_uring_sqe sqe,
                                               int fd,
                                               unsigned int nbytes,
                                               __u64 offset,
                                               int buf_group) noexcept nogil:
    io_uring_prep_read_multishot_c(sqe.ptr, fd, nbytes, offset, buf_group)


cpdef inline void io_uring_prep_write(io_uring_sqe sqe,
                                      int fd,
                                      const unsigned char[:] buf,  # `const void *buf`
                                      unsigned int nbytes,
                                      __u64 offset) noexcept nogil:
    io_uring_prep_write_c(sqe.ptr, fd, &buf[0], nbytes, offset)
