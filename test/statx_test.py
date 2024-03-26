import os
import pytest
import liburing


@pytest.mark.skip_linux('5.6')
def test_io_uring_prep_statx(tmp_dir, ring, cqe):
    file_path = tmp_dir / 'statx_test.txt'
    file_path.write_text('hello world')
    file_path = str(file_path).encode()

    statx = liburing.statx()
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_statx(sqe, statx, file_path, liburing.AT_STATX_FORCE_SYNC,
                                 liburing.STATX_BASIC_STATS | liburing.STATX_BTIME)
    sqe.user_data = 1

    # end time
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1) == 1
    assert cqe.res == 0
    assert cqe.user_data == 1
    liburing.io_uring_cqe_seen(ring, cqe)

    assert statx.islink is False
    assert statx.isfile is True
    assert statx.isreg is True
    assert statx.isdir is False
    assert statx.ischr is False
    assert statx.isblk is False
    assert statx.isfifo is False
    assert statx.issock is False

    assert statx.stx_size == 11

    os_stat = os.lstat(file_path)
    assert statx.stx_btime == statx.stx_atime == os_stat.st_atime
    assert statx.stx_ctime == os_stat.st_ctime
    assert statx.stx_mtime == os_stat.st_mtime
