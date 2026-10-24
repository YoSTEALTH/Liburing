import pytest
from liburing import *


def test_socket_define():
    assert AF_UNIX == 1
    assert AF_INET == 2
    assert AF_INET6 == 10

    assert SOCK_STREAM == 1
    assert SOCK_DGRAM == 2
    assert SOCK_RAW == 3
    assert SOCK_RDM == 4
    assert SOCK_SEQPACKET == 5
    assert SOCK_DCCP == 6
    assert SOCK_PACKET == 10
    assert SOCK_CLOEXEC == 0o2000000
    assert SOCK_NONBLOCK == 0o4000

    assert SHUT_RD == 0
    assert SHUT_WR == 1
    assert SHUT_RDWR == 2

    # TODO: moved to enum
    # assert SOCKET_URING_OP_SIOCINQ == 0
    # assert SOCKET_URING_OP_SIOCOUTQ == 1
    # assert SOCKET_URING_OP_GETSOCKOPT == 2
    # assert SOCKET_URING_OP_SETSOCKOPT == 3

    # setsockopt & getsockopt start >>>
    assert SOL_SOCKET == 1
    assert SO_DEBUG == 1
    assert SO_REUSEADDR == 2
    assert SO_TYPE == 3
    assert SO_ERROR == 4
    assert SO_DONTROUTE == 5
    assert SO_BROADCAST == 6
    assert SO_SNDBUF == 7
    assert SO_RCVBUF == 8
    assert SO_SNDBUFFORCE == 32
    assert SO_RCVBUFFORCE == 33
    assert SO_KEEPALIVE == 9
    assert SO_OOBINLINE == 10
    assert SO_NO_CHECK == 11
    assert SO_PRIORITY == 12
    assert SO_LINGER == 13
    assert SO_BSDCOMPAT == 14
    assert SO_REUSEPORT == 15
    assert SO_PASSCRED == 16
    assert SO_PEERCRED == 17
    assert SO_RCVLOWAT == 18
    assert SO_SNDLOWAT == 19
    assert SO_BINDTODEVICE == 25

    # Socket filtering
    assert SO_ATTACH_FILTER == 26
    assert SO_DETACH_FILTER == 27
    assert SO_GET_FILTER == SO_ATTACH_FILTER
    assert SO_PEERNAME == 28
    assert SO_ACCEPTCONN == 30
    assert SO_PEERSEC == 31
    assert SO_PASSSEC == 34
    assert SO_MARK == 36
    assert SO_PROTOCOL == 38
    assert SO_DOMAIN == 39
    assert SO_RXQ_OVFL == 40
    assert SO_WIFI_STATUS == 41
    assert SCM_WIFI_STATUS == SO_WIFI_STATUS
    assert SO_PEEK_OFF == 42
    # setsockopt & getsockopt end <<<

    assert IPPROTO_IP == 0
    assert IPPROTO_ICMP == 1
    assert IPPROTO_IGMP == 2
    assert IPPROTO_IPIP == 4
    assert IPPROTO_TCP == 6
    assert IPPROTO_EGP == 8
    assert IPPROTO_PUP == 12
    assert IPPROTO_UDP == 17
    assert IPPROTO_IDP == 22
    assert IPPROTO_TP == 29
    assert IPPROTO_DCCP == 33
    assert IPPROTO_IPV6 == 41
    assert IPPROTO_RSVP == 46
    assert IPPROTO_GRE == 47
    assert IPPROTO_ESP == 50
    assert IPPROTO_AH == 51
    assert IPPROTO_MTP == 92
    assert IPPROTO_BEETPH == 94
    assert IPPROTO_ENCAP == 98
    assert IPPROTO_PIM == 103
    assert IPPROTO_COMP == 108
    # note: not supported
    # assert IPPROTO_L2TP == 115
    assert IPPROTO_SCTP == 132
    assert IPPROTO_UDPLITE == 136
    assert IPPROTO_MPLS == 137
    assert IPPROTO_ETHERNET == 143
    assert IPPROTO_RAW == 255
    assert IPPROTO_MPTCP == 262


@pytest.mark.skip("TODO")
def test_socket_extra_define():
    # getaddrinfo/getnameinfo start >>>
    assert AI_PASSIVE == 0x0001
    assert AI_CANONNAME == 0x0002
    assert AI_NUMERICHOST == 0x0004
    assert AI_V4MAPPED == 0x0008
    assert AI_ALL == 0x0010
    assert AI_ADDRCONFIG == 0x0020
    assert AI_IDN == 0x0040
    assert AI_CANONIDN == 0x0080
    assert AI_NUMERICSERV == 0x0400

    assert NI_NUMERICHOST == 1
    assert NI_NUMERICSERV == 2
    assert NI_NOFQDN == 4
    assert NI_NAMEREQD == 8
    assert NI_DGRAM == 16
    assert NI_IDN == 32
    # getaddrinfo/getnameinfo end <<<


def test_sockaddr_family_mismatch():
    with pytest.raises(ValueError):
        Sockaddr(AF_INET, "::", 12345)
    with pytest.raises(ValueError):
        Sockaddr(AF_INET6, "0.0.0.0", 12345)
