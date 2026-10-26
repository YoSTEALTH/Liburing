//! Liburing - Statx related class, ...
const c = @import("c");
const setu = @import("setu");
const std = @import("std");

pub const StatxType = setu.Class(Statx, @embedFile("statx.zig"));

/// Statx - Structures for the extended file attribute retrieval system call `statx()`.
///
/// Example
///     >>> stat = Statx()
///     >>> if sqe := io_uring_get_sqe(ring):
///     ...     io_uring_prep_statx(sqe, stat, 'file.txt')
///     ...
///     True
///     >>> io_uring_submit_and_wait(ring, 1)  # submit and wait for the completion
///     1
///     >>> stat.isfile
///     True
///     >>> stat.size
///     10
///
/// Note
///     - Takes no arguments (`TypeError` for any); the kernel fills it in at the completion of the request.
///     - Properties are the `statx` fields (`size`, `mode`, `uid`, `mask`, `mnt_id`, ...). `atime`, `btime`,
///       `ctime` and `mtime` are seconds as `float`. `isfile`, `isreg`, `isdir`, `islink`, `ischr`, `isblk`,
///       `isfifo` and `issock` test the file type in `mode`.
///     - `io_uring_prep_statx(sqe, statx, path, flags, mask)`: `mask` is the `STATX_*` fields wanted
///       (`STATX_BASIC_STATS` is what `stat` gives, `| STATX_BTIME` for the birth time; `STATX_ALL` is deprecated),
///       `flags` the `AT_*` lookup flags and `AT_STATX_SYNC_AS_STAT` / `AT_STATX_FORCE_SYNC` / `AT_STATX_DONT_SYNC`
///       for how fresh a network file system's answer must be. Only read a field whose bit is in `mask` after
///       the completion: the kernel may fill more or fewer fields than asked. `cqe.res` is `0` on success.
///     - Needs Linux 5.6+ (`IORING_OP_STATX`).
///     - For more information visit:
///         https://man7.org/linux/man-pages/man2/statx.2.html
///         https://man7.org/linux/man-pages/man7/inode.7.html
pub const Statx = struct {
    _statx: c.struct_statx = std.mem.zeroes(c.struct_statx), // lives inside the Python object

    const Self = @This();

    pub fn __new__(_: *Self) void {} // no arguments: `TypeError` for any

    /// `STATX_*` bits of the fields the kernel filled in (what was asked for, less what the file system does not
    /// have, plus what came for free).
    pub fn get_mask(self: *const Self) u32 {
        return self._statx.stx_mask;
    }

    /// Preferred I/O block size, in bytes.
    pub fn get_blksize(self: *const Self) u32 {
        return self._statx.stx_blksize;
    }

    /// `STATX_ATTR_*` attributes of the file (`STATX_ATTR_IMMUTABLE`, `STATX_ATTR_ENCRYPTED`, ...): only the bits
    /// set in `attributes_mask` mean anything.
    pub fn get_attributes(self: *const Self) u64 {
        return self._statx.stx_attributes;
    }

    /// Number of hard links (`STATX_NLINK`).
    pub fn get_nlink(self: *const Self) u32 {
        return self._statx.stx_nlink;
    }

    /// Owner's user id (`STATX_UID`).
    pub fn get_uid(self: *const Self) u32 {
        return self._statx.stx_uid;
    }

    /// Owner's group id (`STATX_GID`).
    pub fn get_gid(self: *const Self) u32 {
        return self._statx.stx_gid;
    }

    /// File type (`mode & S_IFMT`, `STATX_TYPE`) and permission bits (`mode & ~S_IFMT`: `S_IRUSR`, `S_ISUID`, ...,
    /// `STATX_MODE`).
    pub fn get_mode(self: *const Self) u32 {
        return self._statx.stx_mode;
    }

    /// Inode number (`STATX_INO`).
    pub fn get_ino(self: *const Self) u64 {
        return self._statx.stx_ino;
    }

    /// Size in bytes (`STATX_SIZE`); for a symbolic link the length of its target.
    pub fn get_size(self: *const Self) u64 {
        return self._statx.stx_size;
    }

    /// Number of 512-byte blocks allocated (`STATX_BLOCKS`).
    pub fn get_blocks(self: *const Self) u64 {
        return self._statx.stx_blocks;
    }

    /// Which `STATX_ATTR_*` bits of `attributes` the file system supports.
    pub fn get_attributes_mask(self: *const Self) u64 {
        return self._statx.stx_attributes_mask;
    }

    /// Major number of the device a character or block device file (`ischr` / `isblk`) stands for.
    pub fn get_rdev_major(self: *const Self) u32 {
        return self._statx.stx_rdev_major;
    }

    /// Minor number of the device a character or block device file stands for.
    pub fn get_rdev_minor(self: *const Self) u32 {
        return self._statx.stx_rdev_minor;
    }

    /// Major number of the device the file lives on.
    pub fn get_dev_major(self: *const Self) u32 {
        return self._statx.stx_dev_major;
    }

    /// Minor number of the device the file lives on.
    pub fn get_dev_minor(self: *const Self) u32 {
        return self._statx.stx_dev_minor;
    }

    /// Id of the mount the file is on (`STATX_MNT_ID`, Linux 5.8+), as in `/proc/self/mountinfo`.
    pub fn get_mnt_id(self: *const Self) u64 {
        return self._statx.stx_mnt_id;
    }

    /// Memory alignment `O_DIRECT` I/O on the file needs, in bytes (`STATX_DIOALIGN`, Linux 6.1+); `0` when the
    /// file does not support direct I/O.
    pub fn get_dio_mem_align(self: *const Self) u32 {
        return self._statx.stx_dio_mem_align;
    }

    // Timestamps
    // ----------
    /// Seconds as `float` (nanoseconds are kept to the precision of a `float`).
    fn timestamp(t: c.struct_statx_timestamp) f64 {
        const sec: f64 = @floatFromInt(t.tv_sec);
        const nsec: f64 = @floatFromInt(t.tv_nsec);
        return sec + nsec * 0.000_000_001;
    }

    /// Last access, seconds since the epoch as `float` (`STATX_ATIME`).
    pub fn get_atime(self: *const Self) f64 {
        return timestamp(self._statx.stx_atime);
    }

    /// Creation (birth) time as `float` (`STATX_BTIME`; `0.0` where the file system does not keep it).
    pub fn get_btime(self: *const Self) f64 {
        return timestamp(self._statx.stx_btime);
    }

    /// Last status (inode) change as `float` (`STATX_CTIME`).
    pub fn get_ctime(self: *const Self) f64 {
        return timestamp(self._statx.stx_ctime);
    }

    /// Last modification of the contents as `float` (`STATX_MTIME`).
    pub fn get_mtime(self: *const Self) f64 {
        return timestamp(self._statx.stx_mtime);
    }

    // Inode
    // -----
    /// A symbolic link.
    pub fn get_islink(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFLNK;
    }

    /// Same as `isreg`: a regular file.
    pub fn get_isfile(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFREG;
    }

    /// A regular file.
    pub fn get_isreg(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFREG;
    }

    /// A directory.
    pub fn get_isdir(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFDIR;
    }

    /// A character device (`rdev_major` / `rdev_minor` name it).
    pub fn get_ischr(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFCHR;
    }

    /// A block device (`rdev_major` / `rdev_minor` name it).
    pub fn get_isblk(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFBLK;
    }

    /// A FIFO (named pipe).
    pub fn get_isfifo(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFIFO;
    }

    /// A socket.
    pub fn get_issock(self: *const Self) bool {
        return (self._statx.stx_mode & c.S_IFMT) == c.S_IFSOCK;
    }
};

pub const STATX_TYPE = c.STATX_TYPE;
pub const STATX_MODE = c.STATX_MODE;
pub const STATX_NLINK = c.STATX_NLINK;
pub const STATX_UID = c.STATX_UID;
pub const STATX_GID = c.STATX_GID;
pub const STATX_ATIME = c.STATX_ATIME;
pub const STATX_MTIME = c.STATX_MTIME;
pub const STATX_CTIME = c.STATX_CTIME;
pub const STATX_INO = c.STATX_INO;
pub const STATX_SIZE = c.STATX_SIZE;
pub const STATX_BLOCKS = c.STATX_BLOCKS;
pub const STATX_BASIC_STATS = c.STATX_BASIC_STATS;
pub const STATX_BTIME = c.STATX_BTIME;
pub const STATX_MNT_ID = c.STATX_MNT_ID;
pub const STATX_DIOALIGN = c.STATX_DIOALIGN;

// note: STATX_ALL is depreciated, use: `STATX_BASIC_STATS | STATX_BTIME`

pub const STATX_ATTR_COMPRESSED = c.STATX_ATTR_COMPRESSED;
pub const STATX_ATTR_IMMUTABLE = c.STATX_ATTR_IMMUTABLE;
pub const STATX_ATTR_APPEND = c.STATX_ATTR_APPEND;
pub const STATX_ATTR_NODUMP = c.STATX_ATTR_NODUMP;
pub const STATX_ATTR_ENCRYPTED = c.STATX_ATTR_ENCRYPTED;
pub const STATX_ATTR_AUTOMOUNT = c.STATX_ATTR_AUTOMOUNT;
pub const STATX_ATTR_MOUNT_ROOT = c.STATX_ATTR_MOUNT_ROOT;
pub const STATX_ATTR_VERITY = c.STATX_ATTR_VERITY;
pub const STATX_ATTR_DAX = c.STATX_ATTR_DAX;

pub const S_IFMT = c.S_IFMT;

pub const S_IFSOCK = c.S_IFSOCK;
pub const S_IFLNK = c.S_IFLNK;
pub const S_IFREG = c.S_IFREG;
pub const S_IFBLK = c.S_IFBLK;
pub const S_IFDIR = c.S_IFDIR;
pub const S_IFCHR = c.S_IFCHR;
pub const S_IFIFO = c.S_IFIFO;

pub const S_ISUID = c.S_ISUID;
pub const S_ISGID = c.S_ISGID;
pub const S_ISVTX = c.S_ISVTX;

pub const S_IRWXU = c.S_IRWXU;
pub const S_IRUSR = c.S_IRUSR;
pub const S_IWUSR = c.S_IWUSR;
pub const S_IXUSR = c.S_IXUSR;

pub const S_IRWXG = c.S_IRWXG;
pub const S_IRGRP = c.S_IRGRP;
pub const S_IWGRP = c.S_IWGRP;
pub const S_IXGRP = c.S_IXGRP;

pub const S_IRWXO = c.S_IRWXO;
pub const S_IROTH = c.S_IROTH;
pub const S_IWOTH = c.S_IWOTH;
pub const S_IXOTH = c.S_IXOTH;

pub const AT_STATX_SYNC_TYPE = std.os.linux.AT.STATX_SYNC_TYPE; // skipping: not document
pub const AT_STATX_SYNC_AS_STAT = std.os.linux.AT.STATX_SYNC_AS_STAT;
pub const AT_STATX_FORCE_SYNC = std.os.linux.AT.STATX_FORCE_SYNC;
pub const AT_STATX_DONT_SYNC = std.os.linux.AT.STATX_DONT_SYNC;
