import os
import os.path
import pytest
import liburing


@pytest.mark.skip_linux(5.11)
def test_unlink(tmp_dir, ring, cqe):
    file_path = tmp_dir / "file-1.txt"
    file_path.write_text("file-1")

    dir_path = tmp_dir / "directory-1"
    dir_path.mkdir()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlink(sqe, file_path)  # io_uring_prep_unlinkat
    sqe.flags = liburing.IOSQE_IO_LINK | liburing.IOSQE_ASYNC
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlink(sqe, dir_path, liburing.AT_REMOVEDIR)  # io_uring_prep_unlinkat
    sqe.user_data = 2

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    for i in range(2):
        entry = cqe[i]
        assert entry.res == 0
        assert entry.user_data == i + 1
    liburing.io_uring_cq_advance(ring, 2)

    assert not os.path.exists(file_path)  # file should not exist
    assert not os.path.exists(dir_path)  # dir should not exist


@pytest.mark.skip_linux(5.11)
def test_unlinkat_error(tmp_dir, ring, cqe):
    file_path = tmp_dir / "file-2.txt"
    file_path.write_text("file-2")

    dir_path = tmp_dir / "directory-2"
    dir_path.mkdir()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = liburing.io_uring_get_sqe(ring)
    with pytest.raises(TypeError):
        liburing.io_uring_prep_unlink(sqe, b"bytes_path")
    liburing.io_uring_prep_unlink(sqe, file_path, liburing.AT_REMOVEDIR)  # not wrong flag
    sqe.user_data = 1

    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    entry = cqe[0]
    with pytest.raises(NotADirectoryError):
        assert entry.res == 0
    assert entry.user_data == 1
    liburing.io_uring_cqe_seen(ring, entry)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlink(sqe, dir_path)  # not using flag to remove dir
    sqe.user_data = 1

    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    entry = cqe[0]
    with pytest.raises(IsADirectoryError):
        assert entry.res == 0
    assert entry.user_data == 1

    liburing.io_uring_cqe_seen(ring, entry)
    assert os.path.exists(file_path)  # file should exist
    assert os.path.exists(dir_path)  # dir should exist
