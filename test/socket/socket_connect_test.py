import socket
import pytest
from liburing import *


def test_Sockaddr():
    with pytest.raises(ValueError):
        Sockaddr(AF_UNIX, " " * 109)
    addr = Sockaddr(AF_UNIX, "./path")
    with pytest.raises(NotImplementedError):
        _ = addr.port
    with pytest.raises(NotImplementedError):
        _ = addr.ip
    assert addr.family == AF_UNIX
    assert addr.path == "./path"

    with pytest.raises(ValueError):
        Sockaddr(AF_INET, "./path")
    with pytest.raises(ValueError):
        Sockaddr(AF_INET, "bad. ad.dre.ss", 123)
    with pytest.raises(ValueError):
        Sockaddr(AF_INET, "::1", 123)  # ipv6 in ipv4

    addr = Sockaddr(AF_INET, "127.0.0.1", 80)
    assert addr.family == AF_INET
    assert addr.port == 80
    assert addr.ip == "127.0.0.1"
    with pytest.raises(NotImplementedError):
        _ = addr.path

    with pytest.raises(ValueError):
        Sockaddr(AF_INET6, "./path")
    with pytest.raises(TypeError):
        Sockaddr(AF_INET6, "123.123.123.123", 123, 234)  # IPv4 in IPv6
    assert Sockaddr(AF_INET6, "::fb%321", 12345)
    assert Sockaddr(AF_INET6, "::1", 65535)


@pytest.mark.parametrize(
    "given",
    [
        "::1",
        "::",
        "2001:db8:0:0:0:0:0:1",
        "2001:DB8:0:0:1:0:0:1",
        "::ffff:1.2.3.4",
        "1::",
        "0:0:1:0:0:0:0:0",
        "fe80::a:b:c:d",
    ],
)
def test_sockaddr_ip6(given):
    addr = Sockaddr(AF_INET6, given, 80)
    assert addr.ip == socket.inet_ntop(socket.AF_INET6, socket.inet_pton(socket.AF_INET6, given))
    assert Sockaddr(AF_INET6, addr.ip, 80).ip == addr.ip  # round trip
    assert addr.port == 80


def test_sockaddr_ip6_scope():
    assert Sockaddr(AF_INET6, "fe80::1%2", 80).ip == "fe80::1%2"
    assert Sockaddr(AF_INET6, "ff01::fb%4294967295", 80).ip == "ff01::fb%4294967295"  # max
    lo = socket.if_nametoindex("lo")
    assert Sockaddr(AF_INET6, "fe80::1%lo", 80).ip == f"fe80::1%{lo}"  # a name: its index


def test_sockadr_un_connect(ring, cqe, tmp_dir):
    # prep create temp `.sock`
    sock_path = tmp_dir / "testing.sock"
    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server.bind(str(sock_path).encode())

    ts = timespec(3)
    addr = Sockaddr(AF_UNIX, sock_path)

    # socket
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_socket(sqe, addr.family, SOCK_DGRAM)
    sqe.user_data = 1
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    fd = entry.res
    assert entry.user_data == 1
    io_uring_cqe_seen(ring, entry)

    # connect
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_connect(sqe, fd, addr)
    sqe.user_data = 2
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 2
    io_uring_cqe_seen(ring, entry)

    # shutdown & close
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_shutdown(sqe, fd, SHUT_RDWR)
    sqe.flags = IOSQE_IO_LINK
    sqe.user_data = 3
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 4

    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 3
    io_uring_cqe_seen(ring, entry)

    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 4
    io_uring_cqe_seen(ring, entry)
