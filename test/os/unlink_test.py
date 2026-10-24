import os
import os.path
import pytest
from liburing import *


def test_unlink(tmp_dir, ring, cqe):
    file_path = tmp_dir / "file-1.txt"
    file_path.write_text("file-1")

    dir_path = tmp_dir / "directory-1"
    dir_path.mkdir()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_unlink(sqe, file_path)  # io_uring_prep_unlinkat
    sqe.flags = IOSQE_IO_LINK | IOSQE_ASYNC
    sqe.user_data = 1

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_unlink(sqe, dir_path, AT_REMOVEDIR)  # io_uring_prep_unlinkat
    sqe.user_data = 2

    assert io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    for i in range(2):
        entry = cqe[i]
        assert entry.res == 0
        assert entry.user_data == i + 1
    io_uring_cq_advance(ring, 2)

    assert not os.path.exists(file_path)  # file should not exist
    assert not os.path.exists(dir_path)  # dir should not exist


def test_unlinkat_error(tmp_dir, ring, cqe):
    file_path = tmp_dir / "file-2.txt"
    file_path.write_text("file-2")

    dir_path = tmp_dir / "directory-2"
    dir_path.mkdir()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = io_uring_get_sqe(ring)
    with pytest.raises(TypeError):
        io_uring_prep_unlink(sqe, b"bytes_path")
    io_uring_prep_unlink(sqe, file_path, AT_REMOVEDIR)  # not wrong flag
    sqe.user_data = 1

    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0

    entry = cqe[0]
    with pytest.raises(NotADirectoryError):
        assert entry.res == 0
    assert entry.user_data == 1
    io_uring_cqe_seen(ring, entry)

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_unlink(sqe, dir_path)  # not using flag to remove dir
    sqe.user_data = 1

    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0

    entry = cqe[0]
    with pytest.raises(IsADirectoryError):
        assert entry.res == 0
    assert entry.user_data == 1

    io_uring_cqe_seen(ring, entry)
    assert os.path.exists(file_path)  # file should exist
    assert os.path.exists(dir_path)  # dir should exist
