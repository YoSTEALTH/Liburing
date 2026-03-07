const c = @import("c.zig").c;
const oz = @import("PyOZ");
const std = @import("std");

// Liburing
// --------
// miscellaneous
pub const IO_URING_VERSION_MAJOR = c.IO_URING_VERSION_MAJOR;
pub const IO_URING_VERSION_MINOR = c.IO_URING_VERSION_MINOR;
pub const IORING_REGISTER_USE_REGISTERED_RING = c.IORING_REGISTER_USE_REGISTERED_RING;
pub const IORING_SETUP_IOPOLL = c.IORING_SETUP_IOPOLL;
pub const IORING_SETUP_SQPOLL = c.IORING_SETUP_SQPOLL;
pub const IOSQE_IO_LINK = c.IOSQE_IO_LINK;
pub const IOSQE_ASYNC = c.IOSQE_ASYNC;
pub const IOV_MAX = std.posix.IOV_MAX;
pub const IORING_FILE_INDEX_ALLOC = c.IORING_FILE_INDEX_ALLOC;
pub const LIBURING_UDATA_TIMEOUT = c.LIBURING_UDATA_TIMEOUT;

// fcntl.h
// --------
pub const RESOLVE_NO_XDEV = c.RESOLVE_NO_XDEV;
pub const RESOLVE_NO_MAGICLINKS = c.RESOLVE_NO_MAGICLINKS;
pub const RESOLVE_NO_SYMLINKS = c.RESOLVE_NO_SYMLINKS;
pub const RESOLVE_BENEATH = c.RESOLVE_BENEATH;
pub const RESOLVE_IN_ROOT = c.RESOLVE_IN_ROOT;
pub const RESOLVE_CACHED = c.RESOLVE_CACHED;

// `sync_file_range` flags for `io_uring_prep_sync_file_range`
// -----------------------------------------------------------
pub const SYNC_FILE_RANGE_WAIT_BEFORE = c.SYNC_FILE_RANGE_WAIT_BEFORE;
pub const SYNC_FILE_RANGE_WRITE = c.SYNC_FILE_RANGE_WRITE;
pub const SYNC_FILE_RANGE_WAIT_AFTER = c.SYNC_FILE_RANGE_WAIT_AFTER;

pub const O_ACCMODE = c.O_ACCMODE;
pub const O_RDONLY = c.O_RDONLY;
pub const O_WRONLY = c.O_WRONLY;
pub const O_RDWR = c.O_RDWR;

pub const O_APPEND = c.O_APPEND;
pub const O_ASYNC = c.O_ASYNC;
pub const O_CLOEXEC = c.O_CLOEXEC;
pub const O_CREAT = c.O_CREAT;
// ...
pub const O_DIRECT = c.__O_DIRECT;
pub const O_DIRECTORY = c.O_DIRECTORY;
pub const O_DSYNC = c.O_DSYNC;
pub const O_EXCL = c.O_EXCL;
pub const O_LARGEFILE = c.__O_LARGEFILE;
pub const O_NOATIME = c.__O_NOATIME;
pub const O_NOCTTY = c.O_NOCTTY;
pub const O_NOFOLLOW = c.O_NOFOLLOW;
pub const O_NONBLOCK = c.O_NONBLOCK; // 'O_NDELA;
pub const O_PATH = c.__O_PATH;
// ...
pub const O_SYNC = c.O_SYNC;
pub const O_TMPFILE = c.__O_TMPFILE; // must be specified with `O_RDWR` | `O_WRONLY`. `O_EXCL` (optiona;
pub const O_TRUNC = c.O_TRUNC;

// TODO:
// AT_* flags
pub const AT_FDCWD = c.AT_FDCWD;
pub const AT_SYMLINK_FOLLOW = c.AT_SYMLINK_FOLLOW;
pub const AT_SYMLINK_NOFOLLOW = c.AT_SYMLINK_NOFOLLOW;
pub const AT_REMOVEDIR = c.AT_REMOVEDIR;
pub const AT_NO_AUTOMOUNT = c.AT_NO_AUTOMOUNT;
pub const AT_EMPTY_PATH = c.AT_EMPTY_PATH;
pub const AT_RECURSIVE = c.AT_RECURSIVE;

// splice flags
pub const SPLICE_F_MOVE = c.SPLICE_F_MOVE;
pub const SPLICE_F_NONBLOCK = c.SPLICE_F_NONBLOCK;
pub const SPLICE_F_MORE = c.SPLICE_F_MORE;
pub const SPLICE_F_GIFT = c.SPLICE_F_GIFT;

// `fallocate` mode
pub const FALLOC_FL_KEEP_SIZE = c.FALLOC_FL_KEEP_SIZE;
pub const FALLOC_FL_PUNCH_HOLE = c.FALLOC_FL_PUNCH_HOLE;
pub const FALLOC_FL_NO_HIDE_STALE = c.FALLOC_FL_NO_HIDE_STALE;
pub const FALLOC_FL_COLLAPSE_RANGE = c.FALLOC_FL_COLLAPSE_RANGE;
pub const FALLOC_FL_ZERO_RANGE = c.FALLOC_FL_ZERO_RANGE;
pub const FALLOC_FL_INSERT_RANGE = c.FALLOC_FL_INSERT_RANGE;
pub const FALLOC_FL_UNSHARE_RANGE = c.FALLOC_FL_UNSHARE_RANGE;

pub const RWF_APPEND = c.RWF_APPEND;
pub const RWF_DSYNC = c.RWF_DSYNC;
pub const RWF_HIPRI = c.RWF_HIPRI;
pub const RWF_NOWAIT = c.RWF_NOWAIT;
pub const RWF_SYNC = c.RWF_SYNC;
pub const RWF_NOAPPEND = c.RWF_NOAPPEND;
pub const RWF_ATOMIC = c.RWF_ATOMIC;

// oz.constant("HELLO", if (@hasDecl(c, "IO_URING_VERSION_MAJOR")) c.IO_URING_VERSION_MAJOR else 0),
