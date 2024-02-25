import liburing


def test_file_define():
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

    assert liburing.S_ISUID == 0o4000
    assert liburing.S_ISGID == 0o2000
    assert liburing.S_ISVTX == 0o1000
