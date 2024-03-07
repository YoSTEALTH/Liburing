import os
import pytest
import liburing


@pytest.mark.skip_linux('5.6')
def test_statx_define():
    # assert liburing.AT_STATX_SYNC_TYPE == 0x6000  # skipping: not documented
    assert liburing.AT_STATX_SYNC_AS_STAT == 0x0000
    assert liburing.AT_STATX_FORCE_SYNC == 0x2000
    assert liburing.AT_STATX_DONT_SYNC == 0x4000

    assert liburing.STATX_TYPE == 0x00000001
    assert liburing.STATX_MODE == 0x00000002
    assert liburing.STATX_NLINK == 0x00000004
    assert liburing.STATX_UID == 0x00000008
    assert liburing.STATX_GID == 0x00000010
    assert liburing.STATX_ATIME == 0x00000020
    assert liburing.STATX_MTIME == 0x00000040
    assert liburing.STATX_CTIME == 0x00000080
    assert liburing.STATX_INO == 0x00000100
    assert liburing.STATX_SIZE == 0x00000200
    assert liburing.STATX_BLOCKS == 0x00000400
    assert liburing.STATX_BASIC_STATS == 0x000007ff
    assert liburing.STATX_BTIME == 0x00000800
    assert liburing.STATX_MNT_ID == 0x00001000
    # note: not supported
    # assert liburing.STATX_DIOALIGN == 0x00002000

    assert liburing.STATX_ATTR_COMPRESSED == 0x00000004
    assert liburing.STATX_ATTR_IMMUTABLE == 0x00000010
    assert liburing.STATX_ATTR_APPEND == 0x00000020
    assert liburing.STATX_ATTR_NODUMP == 0x00000040
    assert liburing.STATX_ATTR_ENCRYPTED == 0x00000800
    assert liburing.STATX_ATTR_AUTOMOUNT == 0x00001000
    assert liburing.STATX_ATTR_MOUNT_ROOT == 0x00002000
    assert liburing.STATX_ATTR_VERITY == 0x00100000
    assert liburing.STATX_ATTR_DAX == 0x00200000

    assert liburing.S_IFMT == 0o170000

    assert liburing.S_IFSOCK == 0o140000
    assert liburing.S_IFLNK == 0o120000
    assert liburing.S_IFREG == 0o100000
    assert liburing.S_IFBLK == 0o60000
    assert liburing.S_IFDIR == 0o40000
    assert liburing.S_IFCHR == 0o20000
    assert liburing.S_IFIFO == 0o10000

    assert liburing.S_ISUID == 0o4000
    assert liburing.S_ISGID == 0o2000
    assert liburing.S_ISVTX == 0o1000

    assert liburing.S_IRWXU == 0o700
    assert liburing.S_IRUSR == 0o400
    assert liburing.S_IWUSR == 0o200
    assert liburing.S_IXUSR == 0o100

    assert liburing.S_IRWXG == 0o70
    assert liburing.S_IRGRP == 0o40
    assert liburing.S_IWGRP == 0o20
    assert liburing.S_IXGRP == 0o10

    assert liburing.S_IRWXO == 0o7
    assert liburing.S_IROTH == 0o4
    assert liburing.S_IWOTH == 0o2
    assert liburing.S_IXOTH == 0o1


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
