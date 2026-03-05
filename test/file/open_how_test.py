from liburing import O_RDWR, RESOLVE_CACHED, OpenHow


def test_open_how():
    how = OpenHow()
    assert how.flags == how.mode == how.resolve == 0

    how = OpenHow(O_RDWR, 0o777, RESOLVE_CACHED)
    assert how.flags == O_RDWR
    assert how.mode == 0o777
    assert how.resolve == RESOLVE_CACHED

    how = OpenHow()
    how.flags = O_RDWR
    how.mode = 0o666
    how.resolve = RESOLVE_CACHED
    assert how.flags == O_RDWR
    assert how.mode == 0o666
    assert how.resolve == RESOLVE_CACHED

    assert str(OpenHow(1, 2, 3)) == repr(OpenHow(1, 2, 3)) == "OpenHow(flags=1, mode=2, resolve=3)"
