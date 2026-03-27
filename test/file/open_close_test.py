import pytest
import liburing


def test_open_close(ring, cqe):
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_open(sqe, ".", flags)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)  # bug: liburing.io_uring_wait_cqe
    entry = cqe[0]
    fd = entry.res
    assert entry.user_data == 123
    liburing.io_uring_cqe_seen(ring, entry)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321


def test_openat2_close(ring, cqe):
    how = liburing.OpenHow(liburing.O_TMPFILE | liburing.O_WRONLY, 0o777, liburing.RESOLVE_IN_ROOT)
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2(sqe, ".", how)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    fd = entry.res
    assert entry.user_data == 123
    liburing.io_uring_cqe_seen(ring, entry)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321


def test_open_close_direct(ring, cqe):
    index = 3
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    ids = liburing.FileIndex([-1, -1, -1, -1])
    # register
    liburing.io_uring_register_files(ring, ids)
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_open_direct(sqe, ".", flags, index)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 123
    liburing.io_uring_cqe_seen(ring, entry)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close_direct(sqe, index)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    # unregister
    liburing.io_uring_unregister_files(ring)


def test_openat2_close_direct(ring, cqe, tmp_dir):
    how = liburing.OpenHow(liburing.O_CREAT | liburing.O_RDWR, 0o664)
    ids = liburing.FileIndex([-1, -1, -1, -1])
    index = 3
    # register
    liburing.io_uring_register_files(ring, ids)
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2_direct(sqe, tmp_dir / "_testing.txt", how, index)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 123
    liburing.io_uring_cqe_seen(ring, entry)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close_direct(sqe, index)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    # unregister
    liburing.io_uring_unregister_files(ring)


def test_openat2_close_direct_auto_file_index_alloc(ring, cqe):
    how = liburing.OpenHow(liburing.O_TMPFILE | liburing.O_RDWR)
    ids = liburing.FileIndex([-1, -1, -1, -1])
    # register
    liburing.io_uring_register_files(ring, ids)
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2_direct(sqe, ".", how)  # `file_index=IORING_FILE_INDEX_ALLOC`
    sqe.user_data = 123
    # submit
    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    find_index = entry.res
    assert entry.user_data == 123
    liburing.io_uring_cqe_seen(ring, entry)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close_direct(sqe, find_index)
    sqe.user_data = 321
    # submit
    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 321
    liburing.io_uring_cqe_seen(ring, entry)
    # unregister
    liburing.io_uring_unregister_files(ring)


def test_close_error(ring, cqe):
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, 12345)
    sqe.user_data = 123
    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0
    assert cqe[0].user_data == 123
    with pytest.raises(OSError, match="Bad file descriptor"):
        cqe[0].res
