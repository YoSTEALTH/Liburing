//! Liburing - Statx related class, ...
const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

pub const Classes = .{
    oz.class("statx", Statx),
};

pub const Statx = struct {
    _statx: ?*c.struct_statx,

    const Self = @This();

    pub const __doc__: [*:0]const u8 =
        \\Statx - Structures for the extended file attribute retrieval system call `statx()`.
        \\
        \\Example
        \\    >>> stat = statx()
        \\    >>> if sqe := io_uring_get_sqe(ring)
        \\    ...     io_uring_prep_statx(sqe, stat, __file__)
        \\    ... ...
        \\    >>> stat.isfile
        \\    True
        \\    >>> stat.size
        \\    123
        \\
        \\Note
        \\    - For more information visit:
        \\        https://man7.org/linux/man-pages/man2/statx.2.html
        \\        https://man7.org/linux/man-pages/man7/inode.7.html
    ;
    pub fn __new__() ?Self {
        const statx = std.heap.c_allocator.create(c.struct_statx) catch {
            return oz.raiseMemoryError("`statx()` - Out of Memory!");
        };
        statx.* = std.mem.zeroes(c.struct_statx); // set default value to `0`
        return .{ ._statx = statx };
    }

    pub fn __del__(self: *Self) void {
        if (self._statx) |ptr| std.heap.c_allocator.destroy(ptr);
    }

    pub fn get_mask(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_mask else 0;
    }

    pub fn get_blksize(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_blksize else 0;
    }

    pub fn get_attributes(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_attributes else 0;
    }

    pub fn get_nlink(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_nlink else 0;
    }

    pub fn get_uid(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_uid else 0;
    }

    pub fn get_gid(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_gid else 0;
    }

    pub fn get_mode(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_mode else 0;
    }

    pub fn get_ino(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_ino else 0;
    }

    pub fn get_size(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_size else 0;
    }

    pub fn get_blocks(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_blocks else 0;
    }

    pub fn get_attributes_mask(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_attributes_mask else 0;
    }

    pub fn get_rdev_major(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_rdev_major else 0;
    }

    pub fn get_rdev_minor(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_rdev_minor else 0;
    }

    pub fn get_dev_major(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_dev_major else 0;
    }

    pub fn get_dev_minor(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_dev_minor else 0;
    }

    pub fn get_mnt_id(self: *const Self) u64 {
        return if (self._statx) |x| x.stx_mnt_id else 0;
    }

    pub fn get_dio_mem_align(self: *const Self) u32 {
        return if (self._statx) |x| x.stx_dio_mem_align else 0;
    }

    // Timestamps
    // ----------
    pub fn get_atime(self: *const Self) f64 {
        if (self._statx) |x| {
            const sec: f64 = @floatFromInt(x.stx_atime.tv_sec);
            const nsec: f64 = @floatFromInt(x.stx_atime.tv_nsec);
            return sec + nsec * 0.000_000_001;
        }
        return 0.0;
    }

    pub fn get_btime(self: *const Self) f64 {
        if (self._statx) |x| {
            const sec: f64 = @floatFromInt(x.stx_btime.tv_sec);
            const nsec: f64 = @floatFromInt(x.stx_btime.tv_nsec);
            return sec + nsec * 0.000_000_001;
        }
        return 0.0;
    }

    pub fn get_ctime(self: *const Self) f64 {
        if (self._statx) |x| {
            const sec: f64 = @floatFromInt(x.stx_ctime.tv_sec);
            const nsec: f64 = @floatFromInt(x.stx_ctime.tv_nsec);
            return sec + nsec * 0.000_000_001;
        }
        return 0.0;
    }

    pub fn get_mtime(self: *const Self) f64 {
        if (self._statx) |x| {
            const sec: f64 = @floatFromInt(x.stx_mtime.tv_sec);
            const nsec: f64 = @floatFromInt(x.stx_mtime.tv_nsec);
            return sec + nsec * 0.000_000_001;
        }
        return 0.0;
    }

    // Inode
    // -----
    pub fn get_islink(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFLNK else false;
    }

    pub fn get_isfile(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFREG else false;
    }

    pub fn get_isreg(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFREG else false;
    }

    pub fn get_isdir(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFDIR else false;
    }

    pub fn get_ischr(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFCHR else false;
    }

    pub fn get_isblk(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFBLK else false;
    }

    pub fn get_isfifo(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFIFO else false;
    }

    pub fn get_issock(self: *const Self) bool {
        return if (self._statx) |x| (x.stx_mode & c.S_IFMT) == c.S_IFSOCK else false;
    }
};

pub const Constants = .{
    oz.constant("STATX_TYPE", c.STATX_TYPE),
    oz.constant("STATX_MODE", c.STATX_MODE),
    oz.constant("STATX_NLINK", c.STATX_NLINK),
    oz.constant("STATX_UID", c.STATX_UID),
    oz.constant("STATX_GID", c.STATX_GID),
    oz.constant("STATX_ATIME", c.STATX_ATIME),
    oz.constant("STATX_MTIME", c.STATX_MTIME),
    oz.constant("STATX_CTIME", c.STATX_CTIME),
    oz.constant("STATX_INO", c.STATX_INO),
    oz.constant("STATX_SIZE", c.STATX_SIZE),
    oz.constant("STATX_BLOCKS", c.STATX_BLOCKS),
    oz.constant("STATX_BASIC_STATS", c.STATX_BASIC_STATS),
    oz.constant("STATX_BTIME", c.STATX_BTIME),
    oz.constant("STATX_MNT_ID", c.STATX_MNT_ID),
    oz.constant("STATX_DIOALIGN", c.STATX_DIOALIGN),

    oz.constant("STATX_ALL", c.STATX_ALL),

    oz.constant("STATX_ATTR_COMPRESSED", c.STATX_ATTR_COMPRESSED),
    oz.constant("STATX_ATTR_IMMUTABLE", c.STATX_ATTR_IMMUTABLE),
    oz.constant("STATX_ATTR_APPEND", c.STATX_ATTR_APPEND),
    oz.constant("STATX_ATTR_NODUMP", c.STATX_ATTR_NODUMP),
    oz.constant("STATX_ATTR_ENCRYPTED", c.STATX_ATTR_ENCRYPTED),
    oz.constant("STATX_ATTR_AUTOMOUNT", c.STATX_ATTR_AUTOMOUNT),
    oz.constant("STATX_ATTR_MOUNT_ROOT", c.STATX_ATTR_MOUNT_ROOT),
    oz.constant("STATX_ATTR_VERITY", c.STATX_ATTR_VERITY),
    oz.constant("STATX_ATTR_DAX", c.STATX_ATTR_DAX),

    oz.constant("S_IFMT", c.S_IFMT),

    oz.constant("S_IFSOCK", c.S_IFSOCK),
    oz.constant("S_IFLNK", c.S_IFLNK),
    oz.constant("S_IFREG", c.S_IFREG),
    oz.constant("S_IFBLK", c.S_IFBLK),
    oz.constant("S_IFDIR", c.S_IFDIR),
    oz.constant("S_IFCHR", c.S_IFCHR),
    oz.constant("S_IFIFO", c.S_IFIFO),

    oz.constant("S_ISUID", c.S_ISUID),
    oz.constant("S_ISGID", c.S_ISGID),
    oz.constant("S_ISVTX", c.S_ISVTX),

    oz.constant("S_IRWXU", c.S_IRWXU),
    oz.constant("S_IRUSR", c.S_IRUSR),
    oz.constant("S_IWUSR", c.S_IWUSR),
    oz.constant("S_IXUSR", c.S_IXUSR),

    oz.constant("S_IRWXG", c.S_IRWXG),
    oz.constant("S_IRGRP", c.S_IRGRP),
    oz.constant("S_IWGRP", c.S_IWGRP),
    oz.constant("S_IXGRP", c.S_IXGRP),

    oz.constant("S_IRWXO", c.S_IRWXO),
    oz.constant("S_IROTH", c.S_IROTH),
    oz.constant("S_IWOTH", c.S_IWOTH),
    oz.constant("S_IXOTH", c.S_IXOTH),
    oz.constant("AT_STATX_SYNC_TYPE", std.os.linux.AT.STATX_SYNC_TYPE), // skipping: not documented
    oz.constant("AT_STATX_SYNC_AS_STAT", std.os.linux.AT.STATX_SYNC_AS_STAT),
    oz.constant("AT_STATX_FORCE_SYNC", std.os.linux.AT.STATX_FORCE_SYNC),
    oz.constant("AT_STATX_DONT_SYNC", std.os.linux.AT.STATX_DONT_SYNC),
};
