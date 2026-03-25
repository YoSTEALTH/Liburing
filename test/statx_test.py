import os
import pytest
import liburing


@pytest.mark.skip_linux("5.6")
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
    with pytest.raises(OverflowError):
        liburing.io_uring_prep_statx(sqe, statx, file_path, 0, -1)
    liburing.io_uring_prep_statx(
        sqe, statx, file_path, liburing.AT_STATX_FORCE_SYNC, liburing.STATX_BASIC_STATS | liburing.STATX_BTIME
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


@pytest.mark.skip_linux("5.6")
def test_statx_define():
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
    assert liburing.STATX_BASIC_STATS == 0x000007FF
    assert liburing.STATX_BTIME == 0x00000800
    assert liburing.STATX_MNT_ID == 0x00001000
    assert liburing.STATX_DIOALIGN == 0x00002000

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

    assert liburing.AT_STATX_SYNC_TYPE == 0x6000
    assert liburing.AT_STATX_SYNC_AS_STAT == 0x0000
    assert liburing.AT_STATX_FORCE_SYNC == 0x2000
    assert liburing.AT_STATX_DONT_SYNC == 0x4000
