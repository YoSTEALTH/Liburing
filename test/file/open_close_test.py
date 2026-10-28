import pytest
from liburing import *


def test_open_close(ring, cqe):
    flags = O_TMPFILE | O_WRONLY
    # open
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_open(sqe, ".", flags)
    sqe.user_data = 123
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)  # bug: io_uring_wait_cqe
    entry = cqe[0]
    fd = entry.res
    assert entry.user_data == 123
    io_uring_cqe_seen(ring, entry)
    # close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321


def test_open_path_errors(ring):
    class BytesPath:
        def __fspath__(self):
            return b"/tmp"

    sqe = io_uring_get_sqe(ring)
    with pytest.raises(TypeError):  # an `os.PathLike` giving `bytes`
        io_uring_prep_open(sqe, BytesPath())
    with pytest.raises(UnicodeEncodeError):  # a lone surrogate has no UTF-8
        io_uring_prep_open(sqe, "/tmp/\udcff")
    io_uring_prep_nop(sqe)  # the slot is still free


def test_openat2_close(ring, cqe):
    how = OpenHow(O_TMPFILE | O_WRONLY, 0o777, RESOLVE_IN_ROOT)
    # open
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_openat2(sqe, ".", how)
    sqe.user_data = 123
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    fd = entry.res
    assert entry.user_data == 123
    io_uring_cqe_seen(ring, entry)
    # close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321


def test_open_close_direct(ring, cqe):
    index = 3
    flags = O_TMPFILE | O_WRONLY
    ids = FileIndex([-1, -1, -1, -1])
    # register
    io_uring_register_files(ring, ids)
    # open
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_open_direct(sqe, ".", flags, index)
    sqe.user_data = 123
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 123
    io_uring_cqe_seen(ring, entry)
    # close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close_direct(sqe, index)
    sqe.user_data = 321
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    # unregister
    io_uring_unregister_files(ring)


def test_openat2_close_direct(ring, cqe, tmp_dir):
    how = OpenHow(O_CREAT | O_RDWR, 0o664)
    ids = FileIndex([-1, -1, -1, -1])
    index = 3
    # register
    io_uring_register_files(ring, ids)
    # open
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_openat2_direct(sqe, tmp_dir / "_testing.txt", how, index)
    sqe.user_data = 123
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 123
    io_uring_cqe_seen(ring, entry)
    # close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close_direct(sqe, index)
    sqe.user_data = 321
    # submit
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    # unregister
    io_uring_unregister_files(ring)


def test_openat2_close_direct_auto_file_index_alloc(ring, cqe):
    how = OpenHow(O_TMPFILE | O_RDWR)
    ids = FileIndex([-1, -1, -1, -1])
    # register
    io_uring_register_files(ring, ids)
    # open
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_openat2_direct(sqe, ".", how)  # `file_index=IORING_FILE_INDEX_ALLOC`
    sqe.user_data = 123
    # submit
    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    find_index = entry.res
    assert entry.user_data == 123
    io_uring_cqe_seen(ring, entry)
    # close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close_direct(sqe, find_index)
    sqe.user_data = 321
    # submit
    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    io_uring_cqe_seen(ring, entry)
    # unregister
    io_uring_unregister_files(ring)


def test_close_error(ring, cqe):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, 12345)
    sqe.user_data = 123
    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    assert cqe[0].user_data == 123
    with pytest.raises(OSError, match="Bad file descriptor"):
        _ = cqe[0].res
