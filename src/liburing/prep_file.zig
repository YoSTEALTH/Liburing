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

/// Moves `nbytes` from `fd_in` at `off_in` to `fd_out` at `off_out` (`splice(2)`), one of them a pipe.
/// `-1` as an offset means the fd's own position; `splice_flags` are `SPLICE_F_*`.
///
/// Note
///     - Linux 5.7+.
///     - `cqe.res`: bytes spliced.
///     - A pipe's offset must be `-1`; the other fd's `-1` reads/writes at its file position and advances it.
///     - `SPLICE_F_FD_IN_FIXED` in `splice_flags` makes `fd_in` a registered file index; for a registered
///       `fd_out` set `IOSQE_FIXED_FILE` in `sqe.flags`.
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

/// Copies `nbytes` between two pipes (`tee(2)`) without consuming the input; `splice_flags` are `SPLICE_F_*`.
///
/// Note
///     - Linux 5.8+.
///     - `cqe.res`: bytes duplicated, at most `INT_MAX` per request (limits as low as 65536 have been seen, as
///       with `tee(2)`).
///     - `SPLICE_F_FD_IN_FIXED` in `splice_flags` makes `fd_in` a registered file index; for a registered
///       `fd_out` set `IOSQE_FIXED_FILE` in `sqe.flags`.
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
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> bufs  # after the completion
///     [bytearray(b'hi... '), bytearray(b'bye!')]
///
/// Note
///     - `bufs`: 1 to `IOV_MAX` writable buffers (`bytearray`, `memoryview`, `array.array`, ...); the request
///       holds them (locked: no resize) and their `struct iovec` array until its completion.
///     - `io_uring_prep_readv` includes `io_uring_prep_readv2` feature as well.
///     - `cqe.res`: bytes read (`0` at end of file).
///     - `offset` defaults to `0`; a non-seekable file (pipe, socket, ...) needs `0`.
///     - `flags` are `RWF_*` (`preadv2(2)`), default `0`.
///     - For a single buffer `io_uring_prep_read` is cheaper: no `iovec` state to keep.
pub fn io_uring_prep_readv(
    sqe: *SQE,
    fd: i32,
    bufs: py.Sequence(py.WritableBuffer),
    offset: ?u64,
    flags: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_readv(bufs)");
    try h.holdVecUntilCompletion(sqe, vec); // owns `vec` from here
    // cast: <= IOV_MAX
    c.io_uring_prep_readv2(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0);
    return true;
}

/// Reads into `buff` (all of it) from a registered buffer `buf_index` at `offset` (default `0`).
/// The request holds `buff` until its completion.
///
/// Example
///     >>> buffer = bytearray(5)
///     >>> io_uring_register_buffers(ring, [buffer])  # `buf_index` 0
///     0
///     >>> io_uring_prep_read_fixed(sqe, fd, buffer, 0)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> buffer
///     bytearray(b'hi...')
///
/// Note
///     - `cqe.res`: bytes read.
///     - `buff` must lie inside the registered buffer `buf_index` (`OSError: EFAULT` otherwise); it need not
///       start at its beginning (a `memoryview` slice of it works).
pub fn io_uring_prep_read_fixed(
    sqe: *SQE,
    fd: i32,
    buff: py.OwnedWritableBuffer,
    buf_index: i32,
    offset: ?u64,
) py.Error!bool {
    const s = try h.prepSlot(sqe, &buff) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buff, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_read_fixed(
        s,
        fd,
        buff.data.ptr,
        try py.narrow(c_uint, buff.data.len, "`io_uring_prep_read_fixed(buff)` length"),
        _offset,
        buf_index,
    );
    return true;
}

/// Reads into several buffers at once, from the registered buffer `buf_index`.
///
/// Example
///     >>> mem = bytearray(10)
///     >>> io_uring_register_buffers(ring, [mem])  # `buf_index` 0
///     0
///     >>> view = memoryview(mem)
///     >>> bufs = [view[:6], view[6:]]  # parts of the registered buffer
///     >>> io_uring_prep_readv_fixed(sqe, fd, bufs, 0)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> mem  # after the completion
///     bytearray(b'hi... bye!')
///
/// Note
///     - Linux 6.15+.
///     - `cqe.res`: bytes read.
///     - `bufs`: as `io_uring_prep_readv`, held until the completion; every buffer must lie inside the
///       registered buffer `buf_index`.
///     - `flags` are `RWF_*` (`preadv2(2)`), default `0`.
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
    // cast: <= IOV_MAX
    c.io_uring_prep_readv_fixed(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0, buf_index);
    return true;
}

/// Writes several buffers at once (`pwritev2`).
///
/// Example
///     >>> io_uring_prep_writev(sqe, fd, [b'hi... ', b'bye!'])
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # bytes written
///     10
///
/// Note
///     - `bufs`: 1 to `IOV_MAX` buffers (`bytes` too); the request holds them and their `struct iovec` array
///       until its completion.
///     - `io_uring_prep_writev` includes `io_uring_prep_writev2` feature as well.
///     - `offset` defaults to `0`; a non-seekable file (pipe, socket, ...) needs `0`.
///     - `flags` are `RWF_*` (`pwritev2(2)`), default `0`.
///     - At most `INT_MAX` bytes per request. For a single buffer `io_uring_prep_write` is cheaper.
pub fn io_uring_prep_writev(sqe: *SQE, fd: i32, bufs: py.Sequence(py.Buffer), offset: ?u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const vec = try Ring.Vec.fromBuffers(bufs.items, "io_uring_prep_writev(bufs)");
    try h.holdVecUntilCompletion(sqe, vec);
    // cast: <= IOV_MAX
    c.io_uring_prep_writev2(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0);
    return true;
}

/// Writes `buff` (all of it) from the registered buffer `buf_index` at `offset` (default `0`).
/// The request holds `buff` until its completion.
///
/// Example
///     >>> buffer = bytearray(b'hi...')
///     >>> io_uring_register_buffers(ring, [buffer])  # `buf_index` 0
///     0
///     >>> io_uring_prep_write_fixed(sqe, fd, buffer, 0)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # bytes written
///     5
///
/// Note
///     - `cqe.res`: bytes written, at most `INT_MAX` per request.
///     - `buff` must lie inside the registered buffer `buf_index` (`OSError: EFAULT` otherwise): a `bytes` object
///       can not. It need not start at its beginning (a `memoryview` slice of it works).
pub fn io_uring_prep_write_fixed(sqe: *SQE, fd: i32, buff: py.OwnedBuffer, buf_index: i32, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buff) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buff, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_write_fixed(
        s,
        fd,
        buff.data.ptr,
        try py.narrow(c_uint, buff.data.len, "`io_uring_prep_write_fixed(buff)` length"),
        _offset,
        buf_index,
    );
    return true;
}

/// Writes several buffers at once, from the registered buffer `buf_index`.
///
/// Example
///     >>> mem = bytearray(b'hi... bye!')
///     >>> io_uring_register_buffers(ring, [mem])  # `buf_index` 0
///     0
///     >>> view = memoryview(mem)
///     >>> io_uring_prep_writev_fixed(sqe, fd, [view[:6], view[6:]], 0)  # parts of the registered buffer
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # bytes written
///     10
///
/// Note
///     - Linux 6.15+.
///     - `cqe.res`: bytes written, at most `INT_MAX` per request.
///     - `bufs`: as `io_uring_prep_writev`, held until the completion; every buffer must lie inside the
///       registered buffer `buf_index` (so no `bytes`).
///     - `flags` are `RWF_*` (`pwritev2(2)`), default `0`.
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
    // cast: <= IOV_MAX
    c.io_uring_prep_writev_fixed(s, fd, vec.iov.ptr, @intCast(vec.iov.len), offset orelse 0, flags orelse 0, buf_index);
    return true;
}

/// Syncs the file `fd` to disk (`fsync(2)`); `fsync_flags` is `0` (default) or `IORING_FSYNC_DATASYNC`
/// (`fdatasync(2)`).
///
/// Note
///     - `cqe.res`: `0`.
///     - Requests run in parallel: an fsync submitted after a write does not cover that write unless they are
///       linked (`IOSQE_IO_LINK` on the write), `IOSQE_IO_DRAIN` is set, or the write's CQE arrived first.
///     - Syncs the whole file: the C range fields (`sqe.off`, `sqe.len`) are not settable from Python.
pub fn io_uring_prep_fsync(sqe: *SQE, fd: i32, fsync_flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _flags = fsync_flags orelse 0;
    c.io_uring_prep_fsync(s, fd, _flags);
    return true;
}

/// Updates the registered files table from `fds`, starting at slot `offset` (default `0`).
/// The request holds `fds` until its completion.
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res`: the number of slots updated.
///     - A slot that already holds a file is closed and replaced (as unregister then register, in one step);
///       `-1` in `fds` empties the slot.
///     - `IORING_FILE_INDEX_ALLOC` as `offset` lets the kernel pick free slots, written back into `fds`, with
///       `cqe.res` the number allocated.
pub fn io_uring_prep_files_update(sqe: *SQE, fds: *FileIndex, offset: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    // coverage-off: out of memory only
    errdefer sqe.undoSlot();
    // coverage-on
    // note: a `FileIndex` (not a list) so the fds stay alive until the kernel reads them.
    c.io_uring_prep_files_update(s, fds.fdSlice().ptr, @intCast(fds._len), offset orelse 0);
    try h.holdUntilCompletion(sqe, null, &.{h.FileIndexType.object(fds)});
    return true;
}

/// Preallocates or deallocates the file range `offset` to `offset + len` (`fallocate(2)`).
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res`: `0`.
///     - `mode` `0` allocates the range, growing the file if it ends past the current size.
///
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

/// Opens `path`; the new fd is returned in `cqe.res`.
///
/// Type
///     path: str | os.PathLike[str]
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_open(sqe, './file.txt')
///     True
///     >>> sqe.user_data = 123
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> fd = cqe[0].res  # the new fd
///     >>> os.read(fd, 5)
///     b'hi...'
///
/// Note
///     - Linux 5.6+.
///     - Function argument `dfd` has been moved to end from how it is in C function.
///     - `io_uring_prep_open` includes `io_uring_prep_openat` as well.
///     - `flags` defaults to `0` (`O_RDONLY`), `mode` to `0o777` (used with `O_CREAT`, masked by the umask),
///       `dfd` to `AT_FDCWD`; `dfd` is always a normal fd, never a registered one.
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

/// Opens `path` into the registered files table at slot `file_index` instead of returning an fd.
///
/// Type
///     path: str | os.PathLike[str]
///
/// Example
///     >>> fds = FileIndex([-1, -1, -1, -1])
///     >>> index = 3  # position of last ---^ `fds` registered
///     >>> io_uring_register_files(ring, fds)
///     0
///     >>> flags = O_TMPFILE | O_WRONLY
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_open_direct(sqe, ".", flags, index)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # `0`: opened into slot `index`
///     0
///     >>> io_uring_cqe_seen(ring, cqe[0])
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_close_direct(sqe, index)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_unregister_files(ring)
///     0
///
/// Note
///     - Linux 5.15+.
///     - Open direct does not use `fd` but `index`
///     - `file_index` defaults to `IORING_FILE_INDEX_ALLOC`: a free direct descriptor is auto assigned.
///       The allocated descriptor is returned in the `cqe.res`; `OSError: ENFILE` when the table has no free slot.
///       With an explicit slot `cqe.res` is `0`; a slot that already holds a file is closed and replaced.
///     - Needs a registered files table (`io_uring_register_files`, sparse `-1` entries are fine); the slot is
///       then used as `fd` with `IOSQE_FIXED_FILE` in `sqe.flags`, only by io_uring requests.
///     - `flags` defaults to `O_RDONLY`, `mode` to `0o777`, `dfd` to `AT_FDCWD` (always a normal fd).
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_open_direct` includes `io_uring_prep_openat_direct` as well.
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

/// Closes the file `fd`.
///
/// Example
///     >>> io_uring_prep_close(sqe, fd)
///     True
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res`: `0`.
pub fn io_uring_prep_close(sqe: *SQE, fd: i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_close(s, fd);
    return true;
}

/// Closes the registered (direct) file at slot `file_index`.
///
/// Example
///     >>> io_uring_prep_close_direct(sqe, 0)  # slot 0 of the registered files
///     True
///
/// Note
///     - Linux 5.15+.
///     - `cqe.res`: `0`. Same as unregistering the slot; fails only on an invalid slot or out of memory.
///     - Do not set `IOSQE_FIXED_FILE` in `sqe.flags` here: the request would raise `OSError: EBADF`.
pub fn io_uring_prep_close_direct(sqe: *SQE, file_index: u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_close_direct(s, file_index);
    return true;
}

/// Reads into `buf` (all of it) from `fd` at `offset` (default `0`), held until the completion.
///
/// Example
///     >>> buf = bytearray(5)
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_read(sqe, fd, buf)
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # bytes read
///     5
///     >>> buf
///     bytearray(b'hi...')
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res`: bytes read (`0` at end of file); a non-seekable file (pipe, socket, ...) needs `offset` `0`.
pub fn io_uring_prep_read(sqe: *SQE, fd: i32, buf: py.OwnedWritableBuffer, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_read(
        s,
        fd,
        buf.data.ptr,
        try py.narrow(c_uint, buf.data.len, "`io_uring_prep_read(buf)` length"),
        _offset,
    );
    return true;
}

/// Reads from `fd` repeatedly, each time into a buffer the kernel picks from the provided buffer group
/// `buf_group`; `nbytes` of `0` (default) reads up to the buffer's size.
///
/// Note
///     - Linux 6.7+.
///     - Function arguments position has changed for C origin for better usability.
///     - Pollable files only (pipes, tun devices, ...): a regular file raises `OSError: EBADFD`.
///     - Each CQE: `cqe.res` the bytes read, `IORING_CQE_F_BUFFER` in `cqe.flags` with the buffer id, and
///       `IORING_CQE_F_MORE` while the request stays armed; a CQE without it (or an error) ends the request.
///     - `nbytes` larger than the group's buffers is clamped to the buffer size.
pub fn io_uring_prep_read_multishot(sqe: *SQE, fd: i32, buf_group: i32, nbytes: ?u32, offset: ?u64) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _nbytes = nbytes orelse 0;
    const _offset = offset orelse 0;
    c.io_uring_prep_read_multishot(s, fd, _nbytes, _offset, buf_group);
    return true;
}

/// Writes `buf` (all of it) to `fd` at `offset` (default `0`), held until the completion.
///
/// Example
///     >>> sqe = io_uring_get_sqe(ring)
///     >>> io_uring_prep_write(sqe, fd, b"hi...")
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> io_uring_wait_cqe(ring, cqe)
///     0
///     >>> cqe[0].res  # bytes written
///     5
///
/// Note
///     - Linux 5.6+.
///     - At most `INT_MAX` bytes per request; a non-seekable file (pipe, socket, ...) needs `offset` `0`.
pub fn io_uring_prep_write(sqe: *SQE, fd: i32, buf: py.OwnedBuffer, offset: ?u64) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    const _offset = offset orelse 0;
    c.io_uring_prep_write(
        s,
        fd,
        buf.data.ptr,
        try py.narrow(c_uint, buf.data.len, "`io_uring_prep_write(buf)` length"),
        _offset,
    );
    return true;
}

/// Gets the file's `statx(2)` info into `statxbuf` (held until the completion).
///
/// Type
///     sqe:      SQE
///     statxbuf: Statx
///     path:     str | os.PathLike[str]
///     flags:    int
///     mask:     int
///     dfd:      int
///     return:   bool
///
/// Example
///     >>> stat = Statx()
///     >>> if sqe := io_uring_get_sqe(ring):
///     ...     io_uring_prep_statx(sqe, stat, 'file.txt')
///     ...
///     True
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> stat.isfile
///     True
///     >>> stat.size
///     10
///
/// Flags
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
///     - Linux 5.6+.
///     - `cqe.res`: `0`; the fields are in `statxbuf` after the completion.
///     - Function arguments position has changed for C origin for better usability.
///     - `STATX_ALL` is deprecated, use `STATX_BASIC_STATS | STATX_BTIME` which is set by default.
///     - `dfd` defaults to `AT_FDCWD`; to stat an open fd pass it as `dfd` with `path` `''` and
///       `AT_EMPTY_PATH` in `flags`.
pub fn io_uring_prep_statx(
    sqe: *SQE,
    statxbuf: *Statx,
    path: *Object,
    flags: ?i32,
    mask: ?u32,
    dfd: ?i32,
) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const path_ = try h.toPath(path);
    defer path_.deinit();
    const _dfd = dfd orelse AT_FDCWD;
    const _mask = mask orelse c.STATX_BASIC_STATS | c.STATX_BTIME; // replaces `STATX_ALL` as its deprecated!
    const _flags = flags orelse 0;
    c.io_uring_prep_statx(s, _dfd, path_.path, _flags, _mask, &statxbuf._statx);
    try h.holdUntilCompletion(sqe, null, &.{ path_.obj, StatxType.object(statxbuf) });
    return true;
}

/// Advises the kernel on the file use of `len` bytes from `offset` (default `0`) (`posix_fadvise(2)`);
/// `advice` is `POSIX_FADV_*`. Up to `4 GiB - 1`; `io_uring_prep_fadvise64` for more.
///
/// Note
///     - Linux 5.6+.
///     - `cqe.res`: `0`.
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
///       its contents. It must start on a page boundary (`OSError: EINVAL` otherwise), as `madvise(2)` asks.
///     - Up to `4 GiB - 1`; `io_uring_prep_madvise64` for more.
///     - Linux 5.6+.
///     - `cqe.res`: `0`.
pub fn io_uring_prep_madvise(sqe: *SQE, buf: py.OwnedWritableBuffer, advice: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_madvise(
        s,
        buf.data.ptr,
        try py.narrow(u32, buf.data.len, "`io_uring_prep_madvise(buf)` length"),
        advice,
    );
    return true;
}

/// `io_uring_prep_fadvise` for any `len`.
///
/// Note
///     - Function arguments position has changed for C origin for better usability.
///     - A `len` over `4 GiB - 1` raises `OSError: EINVAL` on older kernels without 64-bit length support.
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
///
/// Note
///     - A `buf` over `4 GiB - 1` raises `OSError: EINVAL` on older kernels without 64-bit length support.
pub fn io_uring_prep_madvise64(sqe: *SQE, buf: py.OwnedWritableBuffer, advice: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &buf) orelse return false;
    // coverage-off: out of memory only
    errdefer sqe.undoSlot();
    // coverage-on
    try h.holdUntilCompletion(sqe, &buf, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_madvise64(s, buf.data.ptr, @intCast(buf.data.len), advice); // cast: a size fits `off_t`
    return true;
}

/// Opens `path` as described by `how` (`openat2(2)`); the new fd is returned in `cqe.res`.
///
/// Note
///     - Linux 5.6+.
///     - Function arguments position has changed for C origin for better usability.
///     - `how` (an `OpenHow`) carries the `O_*` flags, the `mode` and the `RESOLVE_*` path rules; `dfd` defaults
///       to `AT_FDCWD` and is always a normal fd.
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

/// `io_uring_prep_openat2`, but the file goes into the registered files table at slot `file_index`
/// (default `IORING_FILE_INDEX_ALLOC`) instead of becoming an fd.
///
/// Note
///     - Linux 5.15+.
///     - `file_index` defaults to `IORING_FILE_INDEX_ALLOC`: a free direct descriptor is auto assigned.
///       The allocated descriptor is returned in the `cqe.res`; `OSError: ENFILE` when the table has no free slot.
///       With an explicit slot `cqe.res` is `0`; a slot that already holds a file is closed and replaced.
///     - Needs a registered files table (`io_uring_register_files`); see `io_uring_prep_open_direct`.
///
/// Type
///     path: str | os.PathLike[str]
pub fn io_uring_prep_openat2_direct(
    sqe: *SQE,
    path: *Object,
    how: *OpenHow,
    file_index: ?u32,
    dfd: ?i32,
) py.Error!bool {
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

/// Removes the file `path` (`unlinkat(2)`); `flags` is `0` (default) or `AT_REMOVEDIR`.
///
/// Note
///     - Linux 5.11+.
///     - `cqe.res`: `0`.
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_unlink` includes `io_uring_prep_unlinkat` feature.
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

/// Renames `oldpath` to `newpath` (`renameat2(2)`); `flags` are `RENAME_*` (default `0`: plain `renameat(2)`).
///
/// Note
///     - Linux 5.11+.
///     - `cqe.res`: `0`.
///     - Function arguments position has changed for C origin for better usability.
///     - `io_uring_prep_rename` includes `io_uring_prep_renameat` feature.
///
/// Flags
///     RENAME_NOREPLACE    # OSError: EEXIST instead of replacing newpath
///     RENAME_EXCHANGE     # swap the two paths atomically
///     RENAME_WHITEOUT     # leave a whiteout at oldpath (overlay filesystems)
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

/// Syncs `len` bytes of the file `fd` from `offset` (default `0`) (`sync_file_range(2)`);
/// `flags` are `SYNC_FILE_RANGE_*` (default `0`).
///
/// Note
///     - Linux 5.2+.
///     - `cqe.res`: `0`.
///     - Function arguments position has changed for C origin for better usability.
///     - `len` `0` means to the end of the file.
///
/// Flags
///     SYNC_FILE_RANGE_WAIT_BEFORE   # wait for pending writeback of the range first
///     SYNC_FILE_RANGE_WRITE         # start writeback of dirty pages in the range
///     SYNC_FILE_RANGE_WAIT_AFTER    # wait for the writeback to finish
pub fn io_uring_prep_sync_file_range(sqe: *SQE, fd: i32, len: u32, offset: ?u64, flags: ?i32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_sync_file_range(s, fd, len, _offset, _flags);
    return true;
}

/// Creates the directory `path` with `mode` (`mkdirat(2)`, masked by the umask).
///
/// Note
///     - Linux 5.15+.
///     - `cqe.res`: `0`.
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

/// Creates the symbolic link `linkpath` (relative to `newdirfd`) pointing to `target` (`symlinkat(2)`).
///
/// Note
///     - Linux 5.15+.
///     - `cqe.res`: `0`.
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

/// Creates the hard link `newpath` to `oldpath` (`linkat(2)`); `flags` are `AT_SYMLINK_FOLLOW` or `0` (default).
///
/// Note
///     - Linux 5.15+.
///     - `cqe.res`: `0`.
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

/// Reads the extended attribute `name` of `path` into `value`, `len` bytes at most (`getxattr(2)`).
///
/// Note
///     - Linux 5.19+.
///     - `cqe.res`: the attribute value's length (bytes written into `value`); `OSError: ERANGE` if `len` is
///       too small.
///     - `ValueError` if `len` is larger than `value`.
///
/// Type
///     name: str
///     path: str | os.PathLike[str]
pub fn io_uring_prep_getxattr(
    sqe: *SQE,
    name: *Object,
    value: py.OwnedWritableBuffer,
    path: *Object,
    len: u32,
) py.Error!bool {
    if (len > value.data.len) return releaseFailed(
        value,
        py.raiseValueError("`io_uring_prep_getxattr(len)` is larger than `value`", .{}),
    );
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    // a `str`, read by the kernel at submit
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err);
    const path_ = h.toPath(path) catch |err| return releaseFailed(value, err);
    defer path_.deinit();
    try h.holdUntilCompletion(sqe, &value, &.{ name, path_.obj }); // owns `value` from here
    c.io_uring_prep_getxattr(s, name_, value.data.ptr, path_.path, len);
    return true;
}

/// Sets the extended attribute `name` of `path` to `value`, `len` bytes (`setxattr(2)`);
/// `flags` is `0` (create or replace), `XATTR_CREATE` (`OSError: EEXIST` if it exists) or `XATTR_REPLACE`
/// (`OSError: ENODATA` if it does not).
///
/// Note
///     - Linux 5.19+.
///     - `cqe.res`: `0`.
///     - `ValueError` if `len` is larger than `value`.
///
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
    if (len > value.data.len) return releaseFailed(
        value,
        py.raiseValueError("`io_uring_prep_setxattr(len)` is larger than `value`", .{}),
    );
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    // a `str`, read by the kernel at submit
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err);
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

/// `io_uring_prep_getxattr` for the open file `fd` (`fgetxattr(2)`).
///
/// Note
///     - Linux 5.19+.
///     - `cqe.res`: the attribute value's length; `OSError: ERANGE` if `len` is too small.
///
/// Type
///     name: str
pub fn io_uring_prep_fgetxattr(
    sqe: *SQE,
    fd: i32,
    name: *Object,
    value: py.OwnedWritableBuffer,
    len: u32,
) py.Error!bool {
    if (len > value.data.len) return releaseFailed(
        value,
        py.raiseValueError("`io_uring_prep_fgetxattr(len)` is larger than `value`", .{}),
    );
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    // a `str`, read by the kernel at submit
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err);
    try h.holdUntilCompletion(sqe, &value, &.{name}); // owns `value` from here
    c.io_uring_prep_fgetxattr(s, fd, name_, value.data.ptr, len);
    return true;
}

/// `io_uring_prep_setxattr` for the open file `fd` (`fsetxattr(2)`).
///
/// Note
///     - Linux 5.19+.
///     - `cqe.res`: `0`.
///
/// Type
///     name: str
pub fn io_uring_prep_fsetxattr(
    sqe: *SQE,
    fd: i32,
    name: *Object,
    value: py.OwnedBuffer,
    flags: i32,
    len: u32,
) py.Error!bool {
    if (len > value.data.len) return releaseFailed(
        value,
        py.raiseValueError("`io_uring_prep_fsetxattr(len)` is larger than `value`", .{}),
    );
    const s = try h.prepSlot(sqe, &value) orelse return false;
    errdefer sqe.undoSlot();
    // a `str`, read by the kernel at submit
    const name_ = py.fromPython([:0]const u8, name) catch |err| return releaseFailed(value, err);
    try h.holdUntilCompletion(sqe, &value, &.{name}); // owns `value` from here
    c.io_uring_prep_fsetxattr(s, fd, name_, value.data.ptr, flags, len);
    return true;
}

/// Installs the registered (direct) file `fd` as a normal fd; the new fd is returned in `cqe.res`.
/// `flags` is `0` (default) or `IORING_FIXED_FD_NO_CLOEXEC`.
///
/// Note
///     - Linux 6.8+.
///     - `fd` is the slot in the registered files table, so set `IOSQE_FIXED_FILE` in `sqe.flags`.
///     - The new fd gets `O_CLOEXEC` unless `IORING_FIXED_FD_NO_CLOEXEC`; any other `flags` value raises
///       `OSError: EINVAL`.
///     - Afterwards the slot and the new fd both refer to the file; either can be closed without affecting the
///       other.
pub fn io_uring_prep_fixed_fd_install(sqe: *SQE, fd: i32, flags: ?u32) py.Error!bool {
    const s = try sqe.prepSlot(false) orelse return false;
    errdefer sqe.undoSlot();
    c.io_uring_prep_fixed_fd_install(s, fd, flags orelse 0);
    return true;
}

/// Truncates the file `fd` to `len` bytes (default `0`) (`ftruncate(2)`).
///
/// Note
///     - Linux 6.9+.
///     - `cqe.res`: `0`. A `len` past the current size extends the file with a hole.
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
///     >>> io_uring_submit_and_wait(ring, 1)
///     1
///     >>> os.write(fds[1], b'hi'), os.read(fds[0], 2)  # after the completion: read end, write end
///     (2, b'hi')
///
/// Note
///     - Linux 6.16+.
///     - `cqe.res`: `0`; the fds are valid only after the completion.
///     - The request holds `fds` until its completion.
///     - `pipe_flags` (`pipe2(2)`): `O_CLOEXEC`, `O_NONBLOCK`, `O_DIRECT`, `O_NOTIFICATION_PIPE`.
pub fn io_uring_prep_pipe(sqe: *SQE, fds: py.OwnedWritableBuffer, pipe_flags: i32) py.Error!bool {
    const s = try h.prepSlot(sqe, &fds) orelse return false;
    errdefer sqe.undoSlot();
    try h.holdUntilCompletion(sqe, &fds, &.{}); // first: owns the buffer from here, on every path
    c.io_uring_prep_pipe(s, try pipeFds(fds), pipe_flags);
    return true;
}

/// Like `io_uring_prep_pipe`, but the pipe's fds go into the registered file table: `fds` gets the two
/// slots (`file_index` for the read end and the next slot for the write end; `IORING_FILE_INDEX_ALLOC` lets the
/// kernel pick both).
///
/// Note
///     - Linux 6.16+.
///     - Needs a registered files table (`io_uring_register_files`); with an explicit `file_index` both slots
///       must be free or the request fails.
///     - `cqe.res`: `0`; `fds` holds the two slots after the completion, used as `fd` with `IOSQE_FIXED_FILE`.
pub fn io_uring_prep_pipe_direct(
    sqe: *SQE,
    fds: py.OwnedWritableBuffer,
    pipe_flags: i32,
    file_index: ?u32,
) py.Error!bool {
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
