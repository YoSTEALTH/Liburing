from liburing import timespec


def test_timespec():
    ts = timespec(1)
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 0

    ts = timespec(1.5)
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 500000000

    ts = timespec()
    assert ts.tv_sec == 0
    assert ts.tv_nsec == 0
    ts.tv_sec = 1
    ts.tv_nsec = 500000000
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 500000000
