import liburing


def test_socket_define():
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

    assert liburing.SHUT_RD == 0
    assert liburing.SHUT_WR == 1
    assert liburing.SHUT_RDWR == 2


def test_socket_extra_define():
    # setsockopt & getsockopt
    assert liburing.SOL_SOCKET == 1
    assert liburing.SO_DEBUG == 1
    assert liburing.SO_REUSEADDR == 2
    assert liburing.SO_TYPE == 3
    assert liburing.SO_ERROR == 4
    assert liburing.SO_DONTROUTE == 5
    assert liburing.SO_BROADCAST == 6
    assert liburing.SO_SNDBUF == 7
    assert liburing.SO_RCVBUF == 8
    assert liburing.SO_SNDBUFFORCE == 32
    assert liburing.SO_RCVBUFFORCE == 33
    assert liburing.SO_KEEPALIVE == 9
    assert liburing.SO_OOBINLINE == 10
    assert liburing.SO_NO_CHECK == 11
    assert liburing.SO_PRIORITY == 12
    assert liburing.SO_LINGER == 13
    assert liburing.SO_BSDCOMPAT == 14
    assert liburing.SO_REUSEPORT == 15
    assert liburing.SO_PASSCRED == 16
    assert liburing.SO_PEERCRED == 17
    assert liburing.SO_RCVLOWAT == 18
    assert liburing.SO_SNDLOWAT == 19
    assert liburing.SO_BINDTODEVICE == 25

    # Socket filtering
    assert liburing.SO_ATTACH_FILTER == 26
    assert liburing.SO_DETACH_FILTER == 27
    assert liburing.SO_GET_FILTER == liburing.SO_ATTACH_FILTER
    assert liburing.SO_PEERNAME == 28
    assert liburing.SO_ACCEPTCONN == 30
    assert liburing.SO_PEERSEC == 31
    assert liburing.SO_PASSSEC == 34
    assert liburing.SO_MARK == 36
    assert liburing.SO_PROTOCOL == 38
    assert liburing.SO_DOMAIN == 39
    assert liburing.SO_RXQ_OVFL == 40
    assert liburing.SO_WIFI_STATUS == 41
    assert liburing.SCM_WIFI_STATUS == liburing.SO_WIFI_STATUS
    assert liburing.SO_PEEK_OFF == 42
