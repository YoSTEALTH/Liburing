import os
import pytest
import liburing


@pytest.mark.skip_linux('5.6')
def test_io_uring_prep_statx(tmp_dir, ring, cqe):
    file_path = tmp_dir / "statx_test.txt"
    file_path.write_text("hi... bye!")

    statx = liburing.Statx()
    assert statx.mask == 0
    assert statx.blksize == 0
    assert statx.attributes == 0
    assert statx.nlink == 0
    assert statx.uid == 0
    assert statx.gid == 0
    assert statx.mode == 0
    assert statx.ino == 0
    assert statx.size == 0
    assert statx.blocks == 0
    assert statx.attributes_mask == 0
    assert statx.rdev_major == 0
    assert statx.rdev_minor == 0
    assert statx.dev_major == 0
    assert statx.dev_minor == 0
    assert statx.mnt_id == 0
    assert statx.dio_mem_align == 0
    # Timestamps
    assert statx.atime == 0.0
    assert statx.btime == 0.0
    assert statx.ctime == 0.0
    assert statx.mtime == 0.0
    # Inode
    assert statx.islink is False
    assert statx.isfile is False
    assert statx.isreg is False
    assert statx.isdir is False
    assert statx.ischr is False
    assert statx.isblk is False
    assert statx.isfifo is False
    assert statx.issock is False

    sqe = liburing.io_uring_get_sqe(ring)
    with pytest.raises(TypeError):
        liburing.io_uring_prep_statx(sqe, statx, file_path, 0, -1)
    liburing.io_uring_prep_statx(
        sqe,
        statx,
        file_path,
        liburing.AT_STATX_FORCE_SYNC,
        liburing.STATX_BASIC_STATS | liburing.STATX_BTIME,
    )
    sqe.user_data = 1

    # end time
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 1
    liburing.io_uring_cqe_seen(ring, entry)

    assert statx.islink is False
    assert statx.isfile is True
    assert statx.isreg is True
    assert statx.isdir is False
    assert statx.ischr is False
    assert statx.isblk is False
    assert statx.isfifo is False
    assert statx.issock is False

    assert statx.size == 10

    os_stat = os.lstat(file_path)
    assert statx.btime == statx.atime == os_stat.st_atime
    assert statx.ctime == os_stat.st_ctime
    assert statx.mtime == os_stat.st_mtime
