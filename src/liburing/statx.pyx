cdef class statx:
    ''' Structures for the extended file attribute retrieval system call `statx()`.

        Example
            >>> ring = io_uring()
            ... ...
            >>> stat = statx()
            >>> path = __file__.encode()
            >>> if sqe := io_uring_get_sqe(ring)
            ...     io_uring_prep_statx(sqe, stat, path)
            ... ...
            >>> stat.isfile
            True
            >>> stat.size
            123

        Note
            - For more information visit:
                https://man7.org/linux/man-pages/man2/statx.2.html
                https://man7.org/linux/man-pages/man7/inode.7.html
    '''
    def __cinit__(self):
        self.ptr = <__statx*>PyMem_RawMalloc(sizeof(__statx))
        if self.ptr is NULL:
            memory_error(self)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def stx_mask(self):
        return self.ptr.stx_mask

    @property
    def stx_blksize(self):
        return self.ptr.stx_blksize

    @property
    def stx_attributes(self):
        return self.ptr.stx_attributes

    @property
    def stx_nlink(self):
        return self.ptr.stx_nlink

    @property
    def stx_uid(self):
        return self.ptr.stx_uid

    @property
    def stx_gid(self):
        return self.ptr.stx_gid

    @property
    def stx_mode(self):
        return self.ptr.stx_mode

    @property
    def stx_ino(self):
        return self.ptr.stx_ino

    @property
    def stx_size(self):
        return self.ptr.stx_size

    @property
    def stx_blocks(self):
        return self.ptr.stx_blocks

    @property
    def stx_attributes_mask(self):
        return self.ptr.stx_attributes_mask

    # Timestamps
    # ----------
    @property
    def stx_atime(self) -> float:
        ''' The file's last access timestamp. '''
        return self.ptr.stx_atime.tv_sec + (self.ptr.stx_atime.tv_nsec * 0.000_000_001)

    @property
    def stx_btime(self) -> float:
        ''' The file's creation timestamp. '''
        return self.ptr.stx_btime.tv_sec + (self.ptr.stx_btime.tv_nsec * 0.000_000_001)

    @property
    def stx_ctime(self) -> float:
        ''' The file's last status change timestamp. '''
        return self.ptr.stx_ctime.tv_sec + (self.ptr.stx_ctime.tv_nsec * 0.000_000_001)

    @property
    def stx_mtime(self) -> float:
        ''' The file's last modification timestamp. '''
        return self.ptr.stx_mtime.tv_sec + (self.ptr.stx_mtime.tv_nsec * 0.000_000_001)

    # ID
    # --
    @property
    def stx_rdev_major(self):
        return self.ptr.stx_rdev_major

    @property
    def stx_rdev_minor(self):
        return self.ptr.stx_rdev_minor

    @property
    def stx_dev_major(self):
        return self.ptr.stx_dev_major

    @property
    def stx_dev_minor(self):
        return self.ptr.stx_dev_minor

    @property
    def stx_mnt_id(self):
        return self.ptr.stx_mnt_id

    # note: not supported
    # @property
    # def stx_dio_mem_align(self):
    #     return self.ptr.stx_dio_mem_align

    # @property
    # def stx_dio_offset_align(self):
    #     return self.ptr.stx_dio_offset_align

    # Inode
    # -----
    @property
    def islink(self) -> bool:
        ''' Return True if mode is from a symbolic link. '''
        return __S_ISLNK(self.ptr.stx_mode)

    @property
    def isfile(self) -> bool:
        ''' Return True if mode is from a regular file. '''
        return __S_ISREG(self.ptr.stx_mode)

    @property
    def isreg(self) -> bool:
        ''' Return True if mode is from a regular file. '''
        return __S_ISREG(self.ptr.stx_mode)

    @property
    def isdir(self) -> bool:
        ''' Return True if mode is from a directory. '''
        return __S_ISDIR(self.ptr.stx_mode)

    @property
    def ischr(self) -> bool:
        ''' Return True if mode is from a character special device file. '''
        return __S_ISCHR(self.ptr.stx_mode)

    @property
    def isblk(self) -> bool:
        ''' Return True if mode is from a block special device file. '''
        return __S_ISBLK(self.ptr.stx_mode)

    @property
    def isfifo(self) -> bool:
        ''' Return True if mode is from a FIFO (named pipe). '''
        return __S_ISFIFO(self.ptr.stx_mode)

    @property
    def issock(self) -> bool:
        ''' Return True if mode is from a socket. '''
        return __S_ISSOCK(self.ptr.stx_mode)


cpdef inline void io_uring_prep_statx(io_uring_sqe sqe,
                                      statx statxbuf,
                                      const char *path,
                                      int flags=0,
                                      unsigned int mask=0,
                                      int dfd=__AT_FDCWD) noexcept nogil:
    '''
        Type
            sqe:      io_uring_sqe
            statxbuf: statx
            path:     bytes
            flags:    int
            mask:     int
            dfd:      int
            return:   None

        Example
            >>> stat = statx()
            >>> path = __file__.encode()  # note: also keeps reference alive
            >>> if sqe := io_uring_get_sqe()
            ...     io_uring_prep_statx(sqe, AT_FDCWD, path, 0, 0, stat)
            ... ...
            >>> stat.isfile
            True
            >>> stat.size
            123

        Flag
            AT_EMPTY_PATH
            AT_NO_AUTOMOUNT
            AT_SYMLINK_NOFOLLOW     # Do not follow symbolic links.
            AT_STATX_SYNC_AS_STAT
            AT_STATX_FORCE_SYNC
            AT_STATX_DONT_SYNC

        Mask
            STATX_TYPE          # Want|got `stx_mode & S_IFMT`
            STATX_MODE          # Want|got `stx_mode & ~S_IFMT`
            STATX_NLINK         # Want|got `stx_nlink`
            STATX_UID           # Want|got `stx_uid`
            STATX_GID           # Want|got `stx_gid`
            STATX_ATIME         # Want|got `stx_atime`
            STATX_MTIME         # Want|got `stx_mtime`
            STATX_CTIME         # Want|got `stx_ctime`
            STATX_INO           # Want|got `stx_ino`
            STATX_SIZE          # Want|got `stx_size`
            STATX_BLOCKS        # Want|got `stx_blocks`
            STATX_BASIC_STATS   # [All of the above]
            STATX_BTIME         # Want|got `stx_btime`
            STATX_MNT_ID        # Got `stx_mnt_id`
            # note: not supported
            # STATX_DIOALIGN      # Want/got direct I/O alignment info

        Note
            - Keep reference to `path` or else it will raise `FileNotFoundError`
    '''
    __io_uring_prep_statx(sqe.ptr, dfd, path, flags, mask, statxbuf.ptr)
