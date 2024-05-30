from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .error cimport memory_error
from .queue cimport *


cdef class statx:
    cdef __statx* ptr


cpdef void io_uring_prep_statx(io_uring_sqe sqe,
                               statx statxbuf,
                               const char *path,
                               int flags=?,
                               unsigned int mask=?,
                               int dfd=?) noexcept nogil


cpdef enum __statx_define__:
    # defines
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
    # note: not supported
    # STATX_DIOALIGN = __STATX_DIOALIGN

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

    # AT_STATX_SYNC_TYPE = __AT_STATX_SYNC_TYPE  # skipping: not documented
    AT_STATX_SYNC_AS_STAT = __AT_STATX_SYNC_AS_STAT
    AT_STATX_FORCE_SYNC = __AT_STATX_FORCE_SYNC
    AT_STATX_DONT_SYNC = __AT_STATX_DONT_SYNC
