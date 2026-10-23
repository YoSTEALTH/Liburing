//! Liburing - file preps
const c = @import("c");
const h = @import("helper.zig");
const setu = @import("setu");
const class = @import("class.zig");
const AT_FDCWD = @import("const.zig").AT_FDCWD;
const FileIndex = @import("helper.zig").FileIndex;
const releaseFailed = @import("helper.zig").releaseFailed;
const Ring = @import("ring.zig").Ring;
const SQE = @import("sqe.zig").SQE;
const Statx = @import("statx.zig").Statx;
const StatxType = @import("statx.zig").StatxType;

const py = setu.py;
const Object = setu.c.Object;
const OpenHow = class.OpenHow;

pub fn io_uring_prep_splice(
    sqe: *SQE,
    fd_in: i32,
    off_in: i64,
    fd_out: i32,
    off_out: i64,
    nbytes: u32,
    splice_flags: u32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_splice(s, fd_in, off_in, fd_out, off_out, nbytes, splice_flags);
    return true;
}

pub fn io_uring_prep_tee(sqe: *SQE, fd_in: i32, fd_out: i32, nbytes: u32, splice_flags: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_tee(s, fd_in, fd_out, nbytes, splice_flags);
    return true;
}

/// Reads into several buffers at once (`preadv2`).
///
/// Example
///     >>> bufs = [bytearray(6), bytearray(4)]
///     >>> io_uring_prep_readv(sqe, fd, bufs)
///     True
///     ... # after the completion
///     >>> bufs
///     [bytearray(b'hi... '), bytearray(b'bye!')]
///
/// Note
///     - `bufs`: 1 to `IOV_MAX` writable buffers (`bytearray`, `memoryview`, `array.array`, ...); the request
///       holds them (locked: no resize) and their `struct iovec` array until its completion.
///     - `io_uring_prep_readv` includes `io_uring_prep_readv2` feature as well.
pub fn io_uring_prep_readv(sqe: *SQE, fd: i32, bufs: py.Sequence(py.WritableBuffer), offset: ?u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_readv(bufs)");
    try h.holdVecUntilCompletion(sqe, vec); // owns `vec` from here
    c.io_uring_prep_readv2(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0); // cast: <= IOV_MAX
    return true;
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> buffer = bytearray(5)
///     >>> io_uring_prep_read_fixed(sqe, fd, buffer, buf_index)
///     True
///     ...
///     >>> buffer
///     bytearray(b"hi...")
pub fn io_uring_prep_read_fixed(sqe: *SQE, fd: i32, buff: py.OwnedWritableBuffer, buf_index: i32, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buff) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buff, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_read_fixed(s, fd, buff.data.ptr, try py.narrow(c_uint, buff.data.len, "`io_uring_prep_read_fixed(buff)` length"), _offset, buf_index);
    return true;
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> bufs = [bytearray(5), bytearray(4)]
///     >>> io_uring_prep_readv_fixed(sqe, fd, bufs, buf_index)
///     True
///     ... # after the completion
///     >>> bufs
///     [bytearray(b'hi...'), bytearray(b'bye!')]
///
/// Note
///     - `bufs`: as `io_uring_prep_readv`, held until the completion.
pub fn io_uring_prep_readv_fixed(
    sqe: *SQE,
    fd: i32,
    bufs: py.Sequence(py.WritableBuffer),
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_readv_fixed(bufs)");
    try h.holdVecUntilCompletion(sqe, vec);
    c.io_uring_prep_readv_fixed(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0, buf_index); // cast: <= IOV_MAX
    return true;
}

/// Writes several buffers at once (`pwritev2`).
///
/// Example
///     >>> io_uring_prep_writev(sqe, fd, [b'hi... ', b'bye!'])
///     True
///     ... # after the completion
///     >>> cqe[0].res
///     10
///
/// Note
///     - `bufs`: 1 to `IOV_MAX` buffers (`bytes` too); the request holds them and their `struct iovec` array
///       until its completion.
///     - `io_uring_prep_writev` includes `io_uring_prep_writev2` feature as well.
pub fn io_uring_prep_writev(sqe: *SQE, fd: i32, bufs: py.Sequence(py.Buffer), offset: ?u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_writev(bufs)");
    try h.holdVecUntilCompletion(sqe, vec);
    c.io_uring_prep_writev2(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0); // cast: <= IOV_MAX
    return true;
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> io_uring_prep_write_fixed(sqe, fd, b'hi...', buf_index)
///     True
///     ... ...
///     >>> cqe[0].res
///     5
pub fn io_uring_prep_write_fixed(sqe: *SQE, fd: i32, buff: py.OwnedBuffer, buf_index: i32, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buff) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buff, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_write_fixed(s, fd, buff.data.ptr, try py.narrow(c_uint, buff.data.len, "`io_uring_prep_write_fixed(buff)` length"), _offset, buf_index);
    return true;
}

/// Example
///     >>> # `buf_index` = registered IO buffer
///     >>> io_uring_prep_writev_fixed(sqe, fd, [b"hi... ", b"bye!"], buf_index)
///     True
///     ... # after the completion
///     >>> cqe[0].res
///     10
///
/// Note
///     - `bufs`: as `io_uring_prep_writev`, held until the completion.
pub fn io_uring_prep_writev_fixed(
    sqe: *SQE,
    fd: i32,
    bufs: py.Sequence(py.Buffer),
    buf_index: i32,
    offset: ?u64,
    flags: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_writev_fixed(bufs)");
    try h.holdVecUntilCompletion(sqe, vec);
    c.io_uring_prep_writev_fixed(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0, buf_index); // cast: <= IOV_MAX
    return true;
}

pub fn io_uring_prep_fsync(sqe: *SQE, fd: i32, fsync_flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = fsync_flags orelse 0;
    c.io_uring_prep_fsync(s, fd, _flags);
    return true;
}

pub fn io_uring_prep_files_update(sqe: *SQE, fds: *FileIndex, offset: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    // note: a `FileIndex` (not a list) so the fds stay alive until the kernel reads them.
    c.io_uring_prep_files_update(s, fds.fdSlice().ptr, @intCast(fds._len), offset orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{h.FileIndexType.object(fds)});
    return true;
}

/// Mode
///     FALLOC_FL_KEEP_SIZE       # default is extend size
///     FALLOC_FL_PUNCH_HOLE      # de-allocates range
///     FALLOC_FL_NO_HIDE_STALE   # reserved codepoint
///     FALLOC_FL_COLLAPSE_RANGE
///     FALLOC_FL_ZERO_RANGE
///     FALLOC_FL_INSERT_RANGE
///     FALLOC_FL_UNSHARE_RANGE
pub fn io_uring_prep_fallocate(sqe: *SQE, fd: i32, mode: i32, offset: u64, len: u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_fallocate(s, fd, mode, offset, len);
    return true;
}

/// Open File
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_open(sqe, b'./file.ext')
///     True
///     >>> sqe.user_data = 123
///
/// Note
///     - Function argument `dfd` has been moved to end from how it is in C function.
///     - `io_uring_prep_open` includes `io_uring_prep_openat` as well.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_open(sqe: *SQE, path: *Object, flags: ?i32, mode: ?c.mode_t, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse 0;
    c.io_uring_prep_openat(s, _dfd, path_.path, _flags, _mode);
    try h.holdUntilCompletion(sqe, null, &.{path_.obj});
    return true;
}

/// Open Direct
///
/// Example
///     >>> indexed = FileIndex([-1, -1, -1, -1])
///     >>> index = 3  # position of last ---^ `fds` registered
///     >>> io_uring_register_files(ring, fds)
///     >>> flags = liburing.O_TMPFILE | liburing.O_WRONLY
///     >>> sqe = liburing.io_uring_get_sqe(ring)
///     >>> io_uring_prep_open_direct(sqe, ".", flags, index)
///     True
///     ... ...
///     >>>.io_uring_prep_close_direct(sqe, index)
///     ... ...
///     >>> io_uring_unregister_files(ring)
///
/// Note
///     - Open direct does not use `fd` but `index`
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_open_direct` includes `io_uring_prep_openat_direct` as well.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_open_direct(
    sqe: *SQE,
    path: *Object,
    flags: ?i32,
    file_index: ?u32,
    mode: ?c.mode_t,
    dfd: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse c.O_RDONLY;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat_direct(s, _dfd, path_.path, _flags, _mode, _file_index);
    try h.holdUntilCompletion(sqe, null, &.{path_.obj});
    return true;
}

/// >>> io_uring_prep_close(sqe, fd)
/// True
pub fn io_uring_prep_close(sqe: *SQE, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_close(s, fd);
    return true;
}

/// >>> io_uring_prep_close_direct(sqe, file_index)
/// True
pub fn io_uring_prep_close_direct(sqe: *SQE, file_index: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_close_direct(s, file_index);
    return true;
}

/// Example
///     >>> buf = bytearray(5)
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_read(sqe, fd, buf)
///     True
///     ... ...
///     >>> cqe[0].res
///     5
///     ... ...
///     >>> buf
///     bytearray(b'hi...')
pub fn io_uring_prep_read(sqe: *SQE, fd: i32, buf: py.OwnedWritableBuffer, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_read(s, fd, buf.data.ptr, try py.narrow(c_uint, buf.data.len, "`io_uring_prep_read(buf)` length"), _offset);
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_read_multishot(sqe: *SQE, fd: i32, buf_group: i32, nbytes: ?u32, offset: ?u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _nbytes = nbytes orelse 0;
    const _offset = offset orelse 0;
    c.io_uring_prep_read_multishot(s, fd, _nbytes, _offset, buf_group);
    return true;
}

/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_write(sqe, fd, b"hi...")
///     True
///     ... ...
///     >>> cqe.res
///     5
pub fn io_uring_prep_write(sqe: *SQE, fd: i32, buf: py.OwnedBuffer, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_write(s, fd, buf.data.ptr, try py.narrow(c_uint, buf.data.len, "`io_uring_prep_write(buf)` length"), _offset);
    return true;
}

/// Statx
///
/// Type
///     sqe:    SQE
///     stat:   Statx
///     path: str | os.PathLike[str]
///     flags:  int
///     mask:   int
///     dfd:    int
///     return: None
///
/// Example
///     >>> stat = Statx()
///     >>> if sqe := io_uring_get_sqe(ring)
///     ...     io_uring_prep_statx(sqe, stat, __file__)
///     ... ...
///     >>> stat.isfile
///     True
///     >>> stat.size
///     123
///
/// Flag
///     AT_EMPTY_PATH
///     AT_NO_AUTOMOUNT
///     AT_SYMLINK_NOFOLLOW     # Do not follow symbolic links.
///     AT_STATX_SYNC_AS_STAT
///     AT_STATX_FORCE_SYNC
///     AT_STATX_DONT_SYNC
///
/// Mask
///     STATX_TYPE          # Want|got `stx_mode & S_IFMT`
///     STATX_MODE          # Want|got `stx_mode & ~S_IFMT`
///     STATX_NLINK         # Want|got `stx_nlink`
///     STATX_UID           # Want|got `stx_uid`
///     STATX_GID           # Want|got `stx_gid`
///     STATX_ATIME         # Want|got `stx_atime`
///     STATX_MTIME         # Want|got `stx_mtime`
///     STATX_CTIME         # Want|got `stx_ctime`
///     STATX_INO           # Want|got `stx_ino`
///     STATX_SIZE          # Want|got `stx_size`
///     STATX_BLOCKS        # Want|got `stx_blocks`
///     STATX_BASIC_STATS   # [All of the above]
///     STATX_BTIME         # Want|got `stx_btime`
///     STATX_MNT_ID        # Got `stx_mnt_id`
///     # note: not supported
///     # STATX_DIOALIGN      # Want/got direct I/O alignment info
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `STATX_ALL` is depreciated, use `STATX_BASIC_STATS | STATX_BTIME` which is set by default.
pub fn io_uring_prep_statx(sqe: *SQE, statxbuf: *Statx, path: *Object, flags: ?i32, mask: ?u32, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    const _mask = mask orelse c.STATX_BASIC_STATS | c.STATX_BTIME; // replaces `STATX_ALL` as its depreciated!
    const _flags = flags orelse 0;
    c.io_uring_prep_statx(s, _dfd, path_.path, _flags, _mask, &statxbuf._statx);
    try h.holdUntilCompletion(sqe, null, &.{ path_.obj, StatxType.object(statxbuf) });
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_fadvise(sqe: *SQE, fd: i32, len: u32, advice: i32, offset: ?u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise(s, fd, _offset, len, advice);
    return true;
}

/// `madvise(2)` `advice` for the memory of `buf` (all of it), held until the completion.
///
/// Example
///     >>> m = mmap.mmap(-1, 4096)
///     >>> io_uring_prep_madvise(sqe, m, mmap.MADV_DONTNEED)
///     True
///
/// Note
///     - `buf`: writable (an `mmap.mmap`, or a `memoryview` slice of one): advice like `MADV_DONTNEED` changes
///     its contents. It must start on a page boundary (`OSError: EINVAL` otherwise), as `madvise(2)` asks.
///     - Up to `4 GiB - 1`; `io_uring_prep_madvise64` for more.
pub fn io_uring_prep_madvise(sqe: *SQE, buf: py.OwnedWritableBuffer, advice: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_madvise(s, buf.data.ptr, try py.narrow(u32, buf.data.len, "`io_uring_prep_madvise(buf)` length"), advice);
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_fadvise64(sqe: *SQE, fd: i32, len: c.off_t, advice: i32, offset: ?u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise64(s, fd, _offset, len, advice);
    return true;
}

/// `io_uring_prep_madvise` for any length.
///
/// Example
///     >>> m = mmap.mmap(-1, 4096)
///     >>> io_uring_prep_madvise64(sqe, m, mmap.MADV_WILLNEED)
///     True
pub fn io_uring_prep_madvise64(sqe: *SQE, buf: py.OwnedWritableBuffer, advice: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_madvise64(s, buf.data.ptr, @intCast(buf.data.len), advice); // cast: a size fits `off_t`
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_openat2(sqe: *SQE, path: *Object, how: *OpenHow, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_openat2(s, _dfd, path_.path, &how._open_how);
    try h.holdUntilCompletion(sqe, null, &.{ path_.obj, class.OpenHowType.object(how) });
    return true;
}

/// Note
///     - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
///     Allocated descriptor is returned in the `cqe.res`.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_openat2_direct(sqe: *SQE, path: *Object, how: *OpenHow, file_index: ?u32, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat2_direct(s, _dfd, path_.path, &how._open_how, _file_index);
    try h.holdUntilCompletion(sqe, null, &.{ path_.obj, class.OpenHowType.object(how) });
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_unlink` includes `io_uring_prep_unlinkat` feature.
///
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_unlink(sqe: *SQE, path: *Object, flags: ?i32, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    c.io_uring_prep_unlinkat(s, dfd orelse AT_FDCWD, path_.path, flags orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{path_.obj});
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_rename` includes `io_uring_prep_renameat` feature.
///
/// Type
///     oldpath: str | os.PathLike[str]
///     newpath: str | os.PathLike[str]
pub fn io_uring_prep_rename(
    sqe: *SQE,
    oldpath: *Object,
    newpath: *Object,
    flags: ?u32,
    olddfd: ?i32,
    newdfd: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const oldpath_ = try h.toPath(oldpath);
    defer oldpath_.deinit();
    const newpath_ = try h.toPath(newpath);
    defer newpath_.deinit();
    const _flags = flags orelse 0;
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    c.io_uring_prep_renameat(s, _olddfd, oldpath_.path, _newdfd, newpath_.path, _flags);
    try h.holdUntilCompletion(sqe, null, &.{ oldpath_.obj, newpath_.obj });
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
pub fn io_uring_prep_sync_file_range(sqe: *SQE, fd: i32, len: u32, offset: ?u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_sync_file_range(s, fd, len, _offset, _flags);
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_mkdir` includes `io_uring_prep_mkdirat` feature.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_mkdir(sqe: *SQE, path: *Object, mode: c.mode_t, dfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_mkdirat(s, _dfd, path_.path, mode);
    try h.holdUntilCompletion(sqe, null, &.{path_.obj});
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_symlink` includes `io_uring_prep_symlinkat` feature.
///
/// Type
///     target: str | os.PathLike[str]
///     linkpath: str | os.PathLike[str]
pub fn io_uring_prep_symlink(sqe: *SQE, target: *Object, linkpath: *Object, newdirfd: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const target_ = try h.toPath(target);
    defer target_.deinit();
    const linkpath_ = try h.toPath(linkpath);
    defer linkpath_.deinit();
    const _newdirfd = newdirfd orelse AT_FDCWD;
    c.io_uring_prep_symlinkat(s, target_.path, _newdirfd, linkpath_.path);
    try h.holdUntilCompletion(sqe, null, &.{ target_.obj, linkpath_.obj });
    return true;
}

/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_link` includes `io_uring_prep_linkat` feature.
///
/// Type
///     oldpath: str | os.PathLike[str]
///     newpath: str | os.PathLike[str]
pub fn io_uring_prep_link(
    sqe: *SQE,
    oldpath: *Object,
    newpath: *Object,
    flags: ?i32,
    olddfd: ?i32,
    newdfd: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const oldpath_ = try h.toPath(oldpath);
    defer oldpath_.deinit();
    const newpath_ = try h.toPath(newpath);
    defer newpath_.deinit();
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    const _flags = flags orelse 0;
    c.io_uring_prep_linkat(s, _olddfd, oldpath_.path, _newdfd, newpath_.path, _flags);
    try h.holdUntilCompletion(sqe, null, &.{ oldpath_.obj, newpath_.obj });
    return true;
}

/// Type
///     name: str
///     path: str | os.PathLike[str]
pub fn io_uring_prep_getxattr(sqe: *SQE, name: *Object, value: py.OwnedWritableBuffer, path: *Object, len: u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err); // a `str`, read by the kernel at submit
    const path_ = h.toPath(path) catch |err| return releaseFailed(value, err);
    defer path_.deinit();
    try h.holdUntilCompletion(sqe, &value, &.{ name, path_.obj }); // owns `value` from here
    c.io_uring_prep_getxattr(s, name_, value.data.ptr, path_.path, len);
    return true;
}

/// Type
///     name: str
///     path: str | os.PathLike[str]
pub fn io_uring_prep_setxattr(
    sqe: *SQE,
    name: *Object,
    value: py.OwnedBuffer,
    path: *Object,
    flags: i32,
    len: u32,
) py.Error!bool {
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err); // a `str`, read by the kernel at submit
    const path_ = h.toPath(path) catch |err| return releaseFailed(value, err);
    defer path_.deinit();
    try h.holdUntilCompletion(sqe, &value, &.{ name, path_.obj }); // owns `value` from here
    c.io_uring_prep_setxattr(
        s,
        name_,
        value.data.ptr,
        path_.path,
        flags,
        len,
    );
    return true;
}

/// Type
///     name: str
pub fn io_uring_prep_fgetxattr(sqe: *SQE, fd: i32, name: *Object, value: py.OwnedWritableBuffer, len: u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err); // a `str`, read by the kernel at submit
    try h.holdUntilCompletion(sqe, &value, &.{name}); // owns `value` from here
    c.io_uring_prep_fgetxattr(s, fd, name_, value.data.ptr, len);
    return true;
}

/// Type
///     name: str
pub fn io_uring_prep_fsetxattr(sqe: *SQE, fd: i32, name: *Object, value: py.OwnedBuffer, flags: i32, len: u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err); // a `str`, read by the kernel at submit
    try h.holdUntilCompletion(sqe, &value, &.{name}); // owns `value` from here
    c.io_uring_prep_fsetxattr(s, fd, name_, value.data.ptr, flags, len);
    return true;
}

pub fn io_uring_prep_fixed_fd_install(sqe: *SQE, fd: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_fixed_fd_install(s, fd, flags orelse 0);
    return true;
}

pub fn io_uring_prep_ftruncate(sqe: *SQE, fd: i32, len: ?c.loff_t) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _len = len orelse 0;
    c.io_uring_prep_ftruncate(s, fd, _len);
    return true;
}

/// The two fds of the new pipe are written into `fds` (read end, then write end) when the request completes.
///
/// Example
///     >>> fds = array.array("i", [-1, -1])  # or a `bytearray(8)`
///     >>> io_uring_prep_pipe(sqe, fds, O_CLOEXEC)
///     True
///     ... # after the completion: fds[0], fds[1]
///
/// Note
///     - The request holds `fds` until its completion.
pub fn io_uring_prep_pipe(sqe: *SQE, fds: py.OwnedWritableBuffer, pipe_flags: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &fds) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &fds, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_pipe(s, try pipeFds(fds), pipe_flags);
    return true;
}

/// Like `io_uring_prep_pipe`, but the pipe's fds go into the registered file table: `fds` gets the two
/// slots (`file_index` for the read end; `IORING_FILE_INDEX_ALLOC` lets the kernel pick both).
pub fn io_uring_prep_pipe_direct(sqe: *SQE, fds: py.OwnedWritableBuffer, pipe_flags: i32, file_index: ?u32) py.Error!bool {
    const s = try h.prepSlot(sqe, &fds) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &fds, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_pipe_direct(s, try pipeFds(fds), pipe_flags, file_index orelse c.IORING_FILE_INDEX_ALLOC);
    return true;
}

/// `fds` as the `int[2]` the kernel fills in (`ValueError` if it is too small).
fn pipeFds(fds: py.OwnedWritableBuffer) py.Error![*]c_int {
    if (fds.data.len < 2 * @sizeOf(c_int)) return py.raiseValueError("`fds` must hold two ints (8 bytes)", .{});
    return @ptrCast(@alignCast(fds.data.ptr));
}
