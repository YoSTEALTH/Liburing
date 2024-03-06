import os
import os.path
import pytest
import liburing


@pytest.mark.skip_linux(5.11)
def test_unlink(tmp_dir, ring, cqe):
    file_path = tmp_dir / 'file1.txt'
    file_path.write_text('test1')
    file_path = str(file_path).encode()

    dir_path = tmp_dir / 'directory1'
    dir_path.mkdir()
    dir_path = str(dir_path).encode()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlink(sqe, file_path)
    sqe.flags = liburing.IOSQE_IO_LINK | liburing.IOSQE_ASYNC
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlink(sqe, dir_path, liburing.AT_REMOVEDIR)
    sqe.user_data = 2

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    for i in range(2):
        assert liburing.trap_error(cqe[i].res) == 0
        assert cqe[i].user_data == i+1
    liburing.io_uring_cq_advance(ring, 2)

    assert not os.path.exists(file_path)  # file should not exist
    assert not os.path.exists(dir_path)   # dir should not exist


@pytest.mark.skip_linux(5.11)
def test_unlinkat(tmp_dir, ring, cqe):
    file_path = tmp_dir / 'file2.txt'
    file_path.write_text('test2')
    file_path = str(file_path).encode()

    dir_path = tmp_dir / 'directory2'
    dir_path.mkdir()
    dir_path = str(dir_path).encode()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlinkat(sqe, file_path)
    sqe.flags = liburing.IOSQE_IO_LINK | liburing.IOSQE_ASYNC
    sqe.user_data = 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlinkat(sqe, dir_path, liburing.AT_REMOVEDIR)
    sqe.user_data = 2

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    for i in range(2):
        assert liburing.trap_error(cqe[i].res) == 0
        assert cqe[i].user_data == i+1
    liburing.io_uring_cq_advance(ring, 2)

    assert not os.path.exists(file_path)  # file should not exist
    assert not os.path.exists(dir_path)   # dir should not exist


@pytest.mark.skip_linux(5.11)
def test_unlinkat_error(tmp_dir, ring, cqe):
    file_path = tmp_dir / 'file3.txt'
    file_path.write_text('test3')
    file_path = str(file_path).encode()

    dir_path = tmp_dir / 'directory3'
    dir_path.mkdir()
    dir_path = str(dir_path).encode()

    assert os.path.isfile(file_path)
    assert os.path.isdir(dir_path)

    sqe = liburing.io_uring_get_sqe(ring)
    with pytest.raises(TypeError):
        liburing.io_uring_prep_unlinkat(sqe, 'string_path')
    liburing.io_uring_prep_unlinkat(sqe, file_path, liburing.AT_REMOVEDIR)  # not wrong flag
    sqe.user_data = 1

    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    with pytest.raises(NotADirectoryError):
        assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 1
    liburing.io_uring_cqe_seen(ring, cqe)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_unlinkat(sqe, dir_path)  # not using flag to remove dir
    sqe.user_data = 1

    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0

    with pytest.raises(IsADirectoryError):
        assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 1

    liburing.io_uring_cqe_seen(ring, cqe)
    assert os.path.exists(file_path)  # dir should exist
    assert os.path.exists(dir_path)   # dir should exist
