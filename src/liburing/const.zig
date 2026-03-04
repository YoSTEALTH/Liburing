const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

pub const Constants = .{
    // Liburing
    // --------
    // .{ .key = "LIBURING_HAVE_DATA64", .value = c.LIBURING_HAVE_DATA64 }, // TODO: error look into ic.
    // miscellaneous
    oz.constant("IO_URING_VERSION_MAJOR", c.IO_URING_VERSION_MAJOR),
    oz.constant("IO_URING_VERSION_MINOR", c.IO_URING_VERSION_MINOR),
    oz.constant("IORING_REGISTER_USE_REGISTERED_RING", c.IORING_REGISTER_USE_REGISTERED_RING),

    oz.constant("IORING_SETUP_IOPOLL", c.IORING_SETUP_IOPOLL),
    oz.constant("IORING_SETUP_SQPOLL", c.IORING_SETUP_SQPOLL),

    oz.constant("IOSQE_IO_LINK", c.IOSQE_IO_LINK),
    oz.constant("IOSQE_ASYNC", c.IOSQE_ASYNC),

    oz.constant("IOV_MAX", std.posix.IOV_MAX),

    oz.constant("IORING_FILE_INDEX_ALLOC", c.IORING_FILE_INDEX_ALLOC),

    oz.constant("LIBURING_UDATA_TIMEOUT", c.LIBURING_UDATA_TIMEOUT),

    // oz.constant("HELLO", if (@hasDecl(c, "IO_URING_VERSION_MAJOR")) c.IO_URING_VERSION_MAJOR else 0),

    // `18446744073709551615` is too long for `c_long`, manual set define inside Python.
    // LIBURING_UDATA_TIMEOUT = lib.LIBURING_UDATA_TIMEOUT,

    // fcntl.h
    // --------

    oz.constant("RESOLVE_NO_XDEV", c.RESOLVE_NO_XDEV),
    oz.constant("RESOLVE_NO_MAGICLINKS", c.RESOLVE_NO_MAGICLINKS),
    oz.constant("RESOLVE_NO_SYMLINKS", c.RESOLVE_NO_SYMLINKS),
    oz.constant("RESOLVE_BENEATH", c.RESOLVE_BENEATH),
    oz.constant("RESOLVE_IN_ROOT", c.RESOLVE_IN_ROOT),
    oz.constant("RESOLVE_CACHED", c.RESOLVE_CACHED),

    // `sync_file_range` flags for `io_uring_prep_sync_file_range`
    // -----------------------------------------------------------
    oz.constant("SYNC_FILE_RANGE_WAIT_BEFORE", c.SYNC_FILE_RANGE_WAIT_BEFORE),
    oz.constant("SYNC_FILE_RANGE_WRITE", c.SYNC_FILE_RANGE_WRITE),
    oz.constant("SYNC_FILE_RANGE_WAIT_AFTER", c.SYNC_FILE_RANGE_WAIT_AFTER),

    oz.constant("O_ACCMODE", c.O_ACCMODE),
    oz.constant("O_RDONLY", c.O_RDONLY),
    oz.constant("O_WRONLY", c.O_WRONLY),
    oz.constant("O_RDWR", c.O_RDWR),

    oz.constant("O_APPEND", c.O_APPEND),
    oz.constant("O_ASYNC", c.O_ASYNC),
    oz.constant("O_CLOEXEC", c.O_CLOEXEC),
    oz.constant("O_CREAT", c.O_CREAT),
    // ...
    oz.constant("O_DIRECT", c.__O_DIRECT),
    oz.constant("O_DIRECTORY", c.O_DIRECTORY),
    oz.constant("O_DSYNC", c.O_DSYNC),
    oz.constant("O_EXCL", c.O_EXCL),
    oz.constant("O_LARGEFILE", c.__O_LARGEFILE),
    oz.constant("O_NOATIME", c.__O_NOATIME),
    oz.constant("O_NOCTTY", c.O_NOCTTY),
    oz.constant("O_NOFOLLOW", c.O_NOFOLLOW),
    oz.constant("O_NONBLOCK", c.O_NONBLOCK), // 'O_NDELAY'
    oz.constant("O_PATH", c.__O_PATH),
    // ...
    oz.constant("O_SYNC", c.O_SYNC),
    oz.constant("O_TMPFILE", c.__O_TMPFILE), // must be specified with `O_RDWR` | `O_WRONLY`. `O_EXCL` (optional)
    oz.constant("O_TRUNC", c.O_TRUNC),

    // // AT_* flags
    // oz.constant("AT_FDCWD", c.AT_FDCWD),
    // oz.constant("AT_SYMLINK_FOLLOW", c.AT_SYMLINK_FOLLOW),
    // oz.constant("AT_SYMLINK_NOFOLLOW", c.AT_SYMLINK_NOFOLLOW),
    // oz.constant("AT_REMOVEDIR", c.AT_REMOVEDIR),
    // // oz.constant("AT_NO_AUTOMOUNT", c.AT_NO_AUTOMOUNT), // error
    // // oz.constant("AT_EMPTY_PATH", c.AT_EMPTY_PATH), // error
    // // oz.constant("AT_RECURSIVE", c.AT_RECURSIVE), // error

    // // splice flags
    // // oz.constant("SPLICE_F_MOVE", c.SPLICE_F_MOVE), // error
    // oz.constant("SPLICE_F_NONBLOCK", c.SPLICE_F_NONBLOCK), // error
    // oz.constant("SPLICE_F_MORE", c.SPLICE_F_MORE),
    // oz.constant("SPLICE_F_GIFT", c.SPLICE_F_GIFT),

    // // `fallocate` mode
    // oz.constant("FALLOC_FL_KEEP_SIZE", c.FALLOC_FL_KEEP_SIZE),
    // oz.constant("FALLOC_FL_PUNCH_HOLE", c.FALLOC_FL_PUNCH_HOLE),
    // oz.constant("FALLOC_FL_NO_HIDE_STALE", c.FALLOC_FL_NO_HIDE_STALE),
    // oz.constant("FALLOC_FL_COLLAPSE_RANGE", c.FALLOC_FL_COLLAPSE_RANGE),
    // oz.constant("FALLOC_FL_ZERO_RANGE", c.FALLOC_FL_ZERO_RANGE),
    // oz.constant("FALLOC_FL_INSERT_RANGE", c.FALLOC_FL_INSERT_RANGE),
    // oz.constant("FALLOC_FL_UNSHARE_RANGE", c.FALLOC_FL_UNSHARE_RANGE),
};
