"""File system operations run for real through the ring: one sqe, one cqe, then look at the result on disk."""

import os
import pytest
import liburing as L
import kernel


def run(ring, cqe, prep, *args, **kwargs):
    """Prepares one operation, waits for it and gives its `res` (`OSError` if it failed, `UnsupportedError`
    when the kernel has no such operation)."""
    sqe = L.io_uring_get_sqe(ring)
    prep(sqe, *args, **kwargs)
    op = sqe.opcode
    sqe.user_data = 42
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    try:
        assert entry.user_data == 42
        return kernel.res(entry, op)
    finally:
        L.io_uring_cqe_seen(ring, entry)


def test_mkdir_rename_link_symlink(tmp_dir, ring, cqe):
    d = tmp_dir / "d"
    assert run(ring, cqe, L.io_uring_prep_mkdir, d, 0o755) == 0
    assert d.is_dir()
    (d / "a").write_text("x")
    assert run(ring, cqe, L.io_uring_prep_rename, d / "a", d / "b") == 0
    assert not (d / "a").exists() and (d / "b").read_text() == "x"
    assert run(ring, cqe, L.io_uring_prep_link, d / "b", d / "hard") == 0
    assert os.stat(d / "b").st_nlink == 2
    assert run(ring, cqe, L.io_uring_prep_symlink, "b", d / "soft") == 0
    assert os.readlink(d / "soft") == "b"
    with pytest.raises(OSError):  # exists already
        run(ring, cqe, L.io_uring_prep_mkdir, d, 0o755)


def test_fsync_fallocate_ftruncate_sync_range(tmp_dir, ring, cqe):
    fd = os.open(tmp_dir / "f.bin", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        assert run(ring, cqe, L.io_uring_prep_fallocate, fd, 0, 0, 4096) == 0
        assert os.fstat(fd).st_size == 4096
        assert run(ring, cqe, L.io_uring_prep_ftruncate, fd, 100) == 0
        assert os.fstat(fd).st_size == 100
        assert run(ring, cqe, L.io_uring_prep_fsync, fd) == 0
        assert run(ring, cqe, L.io_uring_prep_fsync, fd, L.IORING_FSYNC_DATASYNC) == 0
        assert run(ring, cqe, L.io_uring_prep_sync_file_range, fd, 100) == 0
        assert run(ring, cqe, L.io_uring_prep_fadvise, fd, 100, os.POSIX_FADV_NORMAL) == 0
        assert run(ring, cqe, L.io_uring_prep_fadvise64, fd, 100, os.POSIX_FADV_NORMAL) == 0
    finally:
        os.close(fd)


def test_xattr(tmp_dir, ring, cqe):
    path = tmp_dir / "x.txt"
    path.write_text("x")
    try:
        os.setxattr(path, "user.probe", b"1")
    except OSError:
        pytest.skip("filesystem has no user xattrs")
    # path variants
    assert run(ring, cqe, L.io_uring_prep_setxattr, "user.a", b"hello", path, 0, 5) == 0
    assert os.getxattr(path, "user.a") == b"hello"
    out = bytearray(8)
    assert run(ring, cqe, L.io_uring_prep_getxattr, "user.a", out, path, 8) == 5
    assert bytes(out[:5]) == b"hello"
    # fd variants
    fd = os.open(path, os.O_RDONLY)
    try:
        assert run(ring, cqe, L.io_uring_prep_fsetxattr, fd, "user.b", b"bye", 0, 3) == 0
        assert os.getxattr(path, "user.b") == b"bye"
        out = bytearray(8)
        assert run(ring, cqe, L.io_uring_prep_fgetxattr, fd, "user.b", out, 8) == 3
        assert bytes(out[:3]) == b"bye"
    finally:
        os.close(fd)


def test_read_write_fixed_and_vectors(tmp_dir, ring, cqe):
    fd = os.open(tmp_dir / "v.bin", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        out = bytearray(b"0123456789")
        assert L.io_uring_register_buffers(ring, L.Iovec([out])) == 0
        assert run(ring, cqe, L.io_uring_prep_write_fixed, fd, out, 0) == 10
        back = bytearray(10)
        assert L.io_uring_unregister_buffers(ring) == 0
        assert L.io_uring_register_buffers(ring, L.Iovec([back])) == 0
        assert run(ring, cqe, L.io_uring_prep_read_fixed, fd, back, 0) == 10
        assert back == out
        assert L.io_uring_unregister_buffers(ring) == 0

        # vectored, at an offset
        source = [bytearray(b"ab"), bytearray(b"cd")]  # the buffers must outlive `Iovec`'s use
        parts = L.Iovec(source)
        assert run(ring, cqe, L.io_uring_prep_writev, fd, parts, 10) == 4
        got = [bytearray(2), bytearray(2)]
        into = L.Iovec(got)  # io_uring reads the vector at submit: keep it alive (see `Iovec`)
        assert run(ring, cqe, L.io_uring_prep_readv, fd, into, 10) == 4
        assert got == [bytearray(b"ab"), bytearray(b"cd")]
    finally:
        os.close(fd)


def test_close_and_fixed_install(tmp_dir, ring, cqe):
    fd = os.open(tmp_dir / "c.txt", os.O_RDWR | os.O_CREAT, 0o600)
    assert run(ring, cqe, L.io_uring_prep_close, fd) == 0
    with pytest.raises(OSError):
        os.fstat(fd)
    with pytest.raises(OSError):  # no longer open: EBADF
        run(ring, cqe, L.io_uring_prep_close, fd)


def test_open_direct_close_direct(tmp_dir, ring, cqe):
    (tmp_dir / "o.txt").write_text("hi")
    assert L.io_uring_register_files_sparse(ring, 2) == 0
    assert run(ring, cqe, L.io_uring_prep_open_direct, tmp_dir / "o.txt", L.O_RDONLY, 0) == 0
    assert run(ring, cqe, L.io_uring_prep_close_direct, 0) == 0
    assert L.io_uring_unregister_files(ring) == 0


def test_openat2_direct(tmp_dir, ring, cqe):
    (tmp_dir / "o2.txt").write_text("hi")
    how = L.OpenHow(L.O_RDONLY)
    assert L.io_uring_register_files_sparse(ring, 2) == 0
    assert run(ring, cqe, L.io_uring_prep_openat2_direct, tmp_dir / "o2.txt", how, 1) == 0
    assert run(ring, cqe, L.io_uring_prep_close_direct, 1) == 0
    assert L.io_uring_unregister_files(ring) == 0


def test_files_update_prep(tmp_dir, ring, cqe):
    fd = os.open(tmp_dir / "u.txt", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        assert L.io_uring_register_files_sparse(ring, 4) == 0
        assert run(ring, cqe, L.io_uring_prep_files_update, L.FileIndex([fd]), 2) == 1
        assert L.io_uring_unregister_files(ring) == 0
    finally:
        os.close(fd)
