from liburing import O_RDWR, RESOLVE_CACHED, open_how


def test_open_how():
    how = open_how(O_RDWR, 0o777, RESOLVE_CACHED)
    assert how.flags == O_RDWR
    assert how.mode == 0o777
    assert how.resolve == RESOLVE_CACHED

    how = open_how()
    how.flags = O_RDWR
    how.mode = 0o777
    how.resolve = RESOLVE_CACHED
    assert how.flags == O_RDWR
    assert how.mode == 0o777
    assert how.resolve == RESOLVE_CACHED
