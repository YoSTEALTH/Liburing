import liburing


def test_version_define():
    with open('/proc/version', 'rb') as file:
        major, minor, *_ = file.read().split()[2].split(b'.', 2)
    assert liburing.LINUX_VERSION_MAJOR == int(major)
    assert liburing.LINUX_VERSION_MINOR == int(minor)


def test_type_define():
    # flags for `renameat2`.
    assert liburing.RENAME_NOREPLACE == 1 << 0
    assert liburing.RENAME_EXCHANGE == 1 << 1
    assert liburing.RENAME_WHITEOUT == 1 << 2

    # AT_* flags
    assert liburing.AT_FDCWD == -100
    assert liburing.AT_SYMLINK_FOLLOW == 0x400
    assert liburing.AT_SYMLINK_NOFOLLOW == 0x100
    assert liburing.AT_REMOVEDIR == 0x200
    assert liburing.AT_NO_AUTOMOUNT == 0x800
    assert liburing.AT_EMPTY_PATH == 0x1000
    assert liburing.AT_RECURSIVE == 0x8000

    # splice flags
    assert liburing.SPLICE_F_MOVE == 1
    assert liburing.SPLICE_F_NONBLOCK == 2
    assert liburing.SPLICE_F_MORE == 4
    assert liburing.SPLICE_F_GIFT == 8

    # `fallocate` mode
    assert liburing.FALLOC_FL_KEEP_SIZE == 0x01
    assert liburing.FALLOC_FL_PUNCH_HOLE == 0x02
    assert liburing.FALLOC_FL_NO_HIDE_STALE == 0x04
    assert liburing.FALLOC_FL_COLLAPSE_RANGE == 0x08
    assert liburing.FALLOC_FL_ZERO_RANGE == 0x10
    assert liburing.FALLOC_FL_INSERT_RANGE == 0x20
    assert liburing.FALLOC_FL_UNSHARE_RANGE == 0x40
