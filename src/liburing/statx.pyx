from cpython.mem cimport PyMem_RawMalloc, PyMem_RawFree
from .error cimport memory_error


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
            >>> stat.is_file
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
        return self.ptr.stx_mode & 0o7777

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

    @property
    def stx_dio_mem_align(self):
        return self.ptr.stx_dio_mem_align

    @property
    def stx_dio_offset_align(self):
        return self.ptr.stx_dio_offset_align

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
            >>> stat.is_file
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
            STATX_DIOALIGN      # Want/got direct I/O alignment info

        Note
            - Keep reference to `path` or else it will raise `FileNotFoundError`
    '''
    __io_uring_prep_statx(sqe.ptr, dfd, path, flags, mask, statxbuf.ptr)


# AT_STATX_SYNC_TYPE = __AT_STATX_SYNC_TYPE
AT_STATX_SYNC_AS_STAT = __AT_STATX_SYNC_AS_STAT
AT_STATX_FORCE_SYNC = __AT_STATX_FORCE_SYNC
AT_STATX_DONT_SYNC = __AT_STATX_DONT_SYNC

STATX_TYPE = __STATX_TYPE
STATX_MODE = __STATX_MODE
STATX_NLINK = __STATX_NLINK
STATX_UID = __STATX_UID
STATX_GID = __STATX_GID
STATX_ATIME = __STATX_ATIME
STATX_MTIME = __STATX_MTIME
STATX_CTIME = __STATX_CTIME
STATX_INO = __STATX_INO
STATX_SIZE = __STATX_SIZE
STATX_BLOCKS = __STATX_BLOCKS
STATX_BASIC_STATS = __STATX_BASIC_STATS
STATX_BTIME = __STATX_BTIME
STATX_MNT_ID = __STATX_MNT_ID
STATX_DIOALIGN = __STATX_DIOALIGN

STATX_ATTR_COMPRESSED = __STATX_ATTR_COMPRESSED
STATX_ATTR_IMMUTABLE = __STATX_ATTR_IMMUTABLE
STATX_ATTR_APPEND = __STATX_ATTR_APPEND
STATX_ATTR_NODUMP = __STATX_ATTR_NODUMP
STATX_ATTR_ENCRYPTED = __STATX_ATTR_ENCRYPTED
STATX_ATTR_AUTOMOUNT = __STATX_ATTR_AUTOMOUNT
STATX_ATTR_MOUNT_ROOT = __STATX_ATTR_MOUNT_ROOT
STATX_ATTR_VERITY = __STATX_ATTR_VERITY
STATX_ATTR_DAX = __STATX_ATTR_DAX

S_IFMT = __S_IFMT

S_IFSOCK = __S_IFSOCK
S_IFLNK = __S_IFLNK
S_IFREG = __S_IFREG
S_IFBLK = __S_IFBLK
S_IFDIR = __S_IFDIR
S_IFCHR = __S_IFCHR
S_IFIFO = __S_IFIFO

S_ISUID = __S_ISUID
S_ISGID = __S_ISGID
S_ISVTX = __S_ISVTX

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
