import liburing


def test_renameat_define():
    assert liburing.RENAME_NOREPLACE == 1 << 0
    assert liburing.RENAME_EXCHANGE == 1 << 1
    assert liburing.RENAME_WHITEOUT == 1 << 2


def test_fallocate_define():
    assert liburing.FALLOC_FL_KEEP_SIZE == 0x01
    assert liburing.FALLOC_FL_PUNCH_HOLE == 0x02
    assert liburing.FALLOC_FL_NO_HIDE_STALE == 0x04
    assert liburing.FALLOC_FL_COLLAPSE_RANGE == 0x08
    assert liburing.FALLOC_FL_ZERO_RANGE == 0x10
    assert liburing.FALLOC_FL_INSERT_RANGE == 0x20
    assert liburing.FALLOC_FL_UNSHARE_RANGE == 0x40
