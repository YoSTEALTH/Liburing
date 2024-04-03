from .type cimport *


cdef extern from '../include/liburing/compat.h' nogil:
    # Definition of RESOLVE_* constants
    struct __open_how 'open_how':
        __u64   flags
        __u64   mode
        __u64   resolve

    enum:
        # Block mount-point crossings (includes bind-mounts).
        __RESOLVE_NO_XDEV 'RESOLVE_NO_XDEV'
        # Block traversal through procfs-style "magic-links".
        __RESOLVE_NO_MAGICLINKS 'RESOLVE_NO_MAGICLINKS'
        # Block traversal through all symlinks (implies OEXT_NO_MAGICLINKS)
        __RESOLVE_NO_SYMLINKS 'RESOLVE_NO_SYMLINKS'
        # Block "lexical" trickery like "..", symlinks, and absolute paths which escape the dirfd.
        __RESOLVE_BENEATH 'RESOLVE_BENEATH'
        # Make all jumps to "/" and ".." be scoped inside the dirfd (similar to chroot(2)).
        __RESOLVE_IN_ROOT 'RESOLVE_IN_ROOT'
        # Only complete if resolution can be completed through cached lookup.
        # May return `-EAGAIN` if that's not possible.
        __RESOLVE_CACHED 'RESOLVE_CACHED'


cdef extern from '<fcntl.h>' nogil:
    enum:
        # `sync_file_range` flags for `io_uring_prep_sync_file_range`
        # -----------------------------------------------------------
        __SYNC_FILE_RANGE_WAIT_BEFORE 'SYNC_FILE_RANGE_WAIT_BEFORE'
        __SYNC_FILE_RANGE_WRITE 'SYNC_FILE_RANGE_WRITE'
        __SYNC_FILE_RANGE_WAIT_AFTER 'SYNC_FILE_RANGE_WAIT_AFTER'

        __O_ACCMODE 'O_ACCMODE'
        __O_RDONLY 'O_RDONLY'
        __O_WRONLY 'O_WRONLY'
        __O_RDWR 'O_RDWR'

        __O_APPEND 'O_APPEND'
        __O_ASYNC 'O_ASYNC'
        __O_CLOEXEC 'O_CLOEXEC'
        __O_CREAT 'O_CREAT'
        # ...
        __O_DIRECT 'O_DIRECT'
        __O_DIRECTORY 'O_DIRECTORY'
        __O_DSYNC 'O_DSYNC'
        __O_EXCL 'O_EXCL'
        __O_LARGEFILE 'O_LARGEFILE'
        __O_NOATIME 'O_NOATIME'
        __O_NOCTTY 'O_NOCTTY'
        __O_NOFOLLOW 'O_NOFOLLOW'
        __O_NONBLOCK 'O_NONBLOCK'  # 'O_NDELAY'
        __O_PATH 'O_PATH'
        # ...
        __O_SYNC 'O_SYNC'
        __O_TMPFILE 'O_TMPFILE'  # must be specified with `O_RDWR` | `O_WRONLY`. `O_EXCL` (optional)
        __O_TRUNC 'O_TRUNC'
