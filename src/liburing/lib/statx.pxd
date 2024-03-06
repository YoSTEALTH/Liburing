from .type cimport *


cdef extern from '<linux/stat.h>' nogil:
    # Timestamp structure for the timestamps in struct statx.
    struct __statx_timestamp 'statx_timestamp':
        __s64   tv_sec  # `tv_sec` seconds before(-) or after(+) 00:00:00 1st Jan 1970 UTC.
        __u32   tv_nsec  # `tv_nsec` nanoseconds (0..999,999,999) after the `tv_sec` time.

    # Structures for the extended file attribute retrieval system call `statx()`.
    struct __statx 'statx':
        # 0x00
        __u32    stx_mask               # What results were written
        __u32    stx_blksize            # Preferred general I/O size
        __u64    stx_attributes         # Flags conveying information about the file
        # 0x10
        __u32    stx_nlink              # Number of hard links
        __u32    stx_uid                # User ID of owner
        __u32    stx_gid                # Group ID of owner
        __u16    stx_mode               # File type and mode
        # 0x20
        __u64    stx_ino                # Inode number
        __u64    stx_size               # Total size in bytes
        __u64    stx_blocks             # Number of 512-byte blocks allocated
        __u64    stx_attributes_mask    # Mask to show what's supported in `stx_attributes`
        # 0x40 - The following fields are file timestamps
        __statx_timestamp   stx_atime   # Last access time
        __statx_timestamp   stx_btime   # File creation time
        __statx_timestamp   stx_ctime   # Last attribute change time
        __statx_timestamp   stx_mtime   # Last data modification time
        # 0x80
        __u32   stx_rdev_major          # Device ID of special file
        __u32   stx_rdev_minor
        __u32   stx_dev_major           # ID of device containing file
        __u32   stx_dev_minor
        # 0x90
        __u64   stx_mnt_id
        __u32   stx_dio_mem_align       # Memory buffer alignment for direct I/O
        __u32   stx_dio_offset_align    # File offset alignment for direct I/O

    # Flags
    enum:
        # __AT_STATX_SYNC_TYPE 'AT_STATX_SYNC_TYPE'  # skipping: not documented
        __AT_STATX_SYNC_AS_STAT 'AT_STATX_SYNC_AS_STAT'
        __AT_STATX_FORCE_SYNC 'AT_STATX_FORCE_SYNC'
        __AT_STATX_DONT_SYNC 'AT_STATX_DONT_SYNC'

    # Mask - flags to be set for `stx_mask`
    # - Query request/result mask for `statx()` and struct `statx::stx_mask`.
    # - These bits should be set in the "mask" argument of `statx()` to request
    #   particular items when calling `statx()`.
    enum:
        __STATX_TYPE 'STATX_TYPE'                # Want|got `stx_mode & S_IFMT`
        __STATX_MODE 'STATX_MODE'                # Want|got `stx_mode & ~S_IFMT`
        __STATX_NLINK 'STATX_NLINK'              # Want|got `stx_nlink`
        __STATX_UID 'STATX_UID'                  # Want|got `stx_uid`
        __STATX_GID 'STATX_GID'                  # Want|got `stx_gid`
        __STATX_ATIME 'STATX_ATIME'              # Want|got `stx_atime`
        __STATX_MTIME 'STATX_MTIME'              # Want|got `stx_mtime`
        __STATX_CTIME 'STATX_CTIME'              # Want|got `stx_ctime`
        __STATX_INO 'STATX_INO'                  # Want|got `stx_ino`
        __STATX_SIZE 'STATX_SIZE'                # Want|got `stx_size`
        __STATX_BLOCKS 'STATX_BLOCKS'            # Want|got `stx_blocks`
        __STATX_BASIC_STATS 'STATX_BASIC_STATS'  # [All of the above]
        __STATX_BTIME 'STATX_BTIME'              # Want|got `stx_btime`
        __STATX_MNT_ID 'STATX_MNT_ID'            # Got `stx_mnt_id`
        __STATX_DIOALIGN 'STATX_DIOALIGN'        # Want/got direct I/O alignment info

    # Attributes to be found in `stx_attributes` and masked in `stx_attributes_mask`.
    enum:
        __STATX_ATTR_COMPRESSED 'STATX_ATTR_COMPRESSED'  # [I] File is compressed by the fs
        __STATX_ATTR_IMMUTABLE 'STATX_ATTR_IMMUTABLE'    # [I] File is marked immutable
        __STATX_ATTR_APPEND 'STATX_ATTR_APPEND'          # [I] File is append-only
        __STATX_ATTR_NODUMP 'STATX_ATTR_NODUMP'          # [I] File is not to be dumped
        __STATX_ATTR_ENCRYPTED 'STATX_ATTR_ENCRYPTED'    # [I] File requires key to decrypt in fs
        __STATX_ATTR_AUTOMOUNT 'STATX_ATTR_AUTOMOUNT'    # Dir: Automount trigger
        __STATX_ATTR_MOUNT_ROOT 'STATX_ATTR_MOUNT_ROOT'  # Root of a mount
        __STATX_ATTR_VERITY 'STATX_ATTR_VERITY'          # [I] Verity protected file
        __STATX_ATTR_DAX 'STATX_ATTR_DAX'                # File is currently in DAX state
        # note: flags marked [I] correspond to the `FS_IOC_SETFLAGS` flags

    # NOTE: Bellow code should only be exposed to Cython or Wrapper Class
    enum:
        # Encoding of the file mode.
        __S_IFMT 'S_IFMT'       # These bits determine file type.
        # File types.
        __S_IFSOCK 'S_IFSOCK'   # socket
        __S_IFLNK 'S_IFLNK'     # symbolic link
        __S_IFREG 'S_IFREG'     # regular file
        __S_IFBLK 'S_IFBLK'     # block device
        __S_IFDIR 'S_IFDIR'     # directory
        __S_IFCHR 'S_IFCHR'     # character device
        __S_IFIFO 'S_IFIFO'     # FIFO

        __S_ISUID 'S_ISUID'
        __S_ISGID 'S_ISGID'
        __S_ISVTX 'S_ISVTX'

        __S_IRWXU 'S_IRWXU'
        __S_IRUSR 'S_IRUSR'
        __S_IWUSR 'S_IWUSR'
        __S_IXUSR 'S_IXUSR'

        __S_IRWXG 'S_IRWXG'
        __S_IRGRP 'S_IRGRP'
        __S_IWGRP 'S_IWGRP'
        __S_IXGRP 'S_IXGRP'

        __S_IRWXO 'S_IRWXO'
        __S_IROTH 'S_IROTH'
        __S_IWOTH 'S_IWOTH'
        __S_IXOTH 'S_IXOTH'

    # Macro
    bint __S_ISLNK 'S_ISLNK'(__u16 m)      # (((m) & S_IFMT) == S_IFLNK)
    bint __S_ISREG 'S_ISREG'(__u16 m)      # (((m) & S_IFMT) == S_IFREG)
    bint __S_ISDIR 'S_ISDIR'(__u16 m)      # (((m) & S_IFMT) == S_IFDIR)
    bint __S_ISCHR 'S_ISCHR'(__u16 m)      # (((m) & S_IFMT) == S_IFCHR)
    bint __S_ISBLK 'S_ISBLK'(__u16 m)      # (((m) & S_IFMT) == S_IFBLK)
    bint __S_ISFIFO 'S_ISFIFO'(__u16 m)    # (((m) & S_IFMT) == S_IFIFO)
    bint __S_ISSOCK 'S_ISSOCK'(__u16 m)    # (((m) & S_IFMT) == S_IFSOCK)
