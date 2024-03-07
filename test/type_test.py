import liburing


def test_type_define():
    assert liburing.AT_FDCWD == -100
    assert liburing.AT_SYMLINK_FOLLOW == 0x400
    assert liburing.AT_SYMLINK_NOFOLLOW == 0x100
    assert liburing.AT_REMOVEDIR == 0x200
    assert liburing.AT_NO_AUTOMOUNT == 0x800
    assert liburing.AT_EMPTY_PATH == 0x1000
    assert liburing.AT_RECURSIVE == 0x8000
