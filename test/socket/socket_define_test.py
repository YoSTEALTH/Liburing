import liburing


def test_define():
    assert liburing.AF_UNIX == 1
    assert liburing.AF_INET == 2
    assert liburing.AF_INET6 == 10

    assert liburing.SOCK_STREAM == 1
    assert liburing.SOCK_DGRAM == 2
    assert liburing.SOCK_RAW == 3
    assert liburing.SOCK_RDM == 4
    assert liburing.SOCK_SEQPACKET == 5
    assert liburing.SOCK_DCCP == 6
    assert liburing.SOCK_PACKET == 10
    assert liburing.SOCK_CLOEXEC == 0o2000000
    assert liburing.SOCK_NONBLOCK == 0o4000
