import socket
import pytest
import liburing


def test_Sockaddr():
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_UNIX, " " * 109)
    addr = liburing.Sockaddr(liburing.AF_UNIX, "./path")
    with pytest.raises(NotImplementedError):
        addr.port
    with pytest.raises(NotImplementedError):
        addr.ip
    assert addr.family == liburing.AF_UNIX
    assert addr.path == "./path"

    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "./path")
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "bad. ad.dre.ss", 123)
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "::1", 123)  # ipv6 in ipv4

    addr = liburing.Sockaddr(liburing.AF_INET, "127.0.0.1", 80)
    assert addr.family == liburing.AF_INET
    assert addr.port == 80
    assert addr.ip == "127.0.0.1"
    with pytest.raises(NotImplementedError):
        addr.path

    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET6, "./path")
    with pytest.raises(TypeError):
        liburing.Sockaddr(liburing.AF_INET6, "123.123.123.123", 123, 234)  # IPv4 in IPv6
    assert liburing.Sockaddr(liburing.AF_INET6, "::fb%321", 12345)
    assert liburing.Sockaddr(liburing.AF_INET6, "::1", 65535)


def test_sockadr_un_connect(ring, cqe, tmp_dir):
    # prep create temp `.sock`
    sock_path = tmp_dir / "testing.sock"
    server = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    server.bind(str(sock_path).encode())

    ts = liburing.timespec(3)
    addr = liburing.Sockaddr(liburing.AF_UNIX, sock_path)

    # socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_socket(sqe, addr.family, liburing.SOCK_DGRAM)
    sqe.user_data = 1
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    fd = liburing.trap_error(entry.res)
    assert entry.user_data == 1
    liburing.io_uring_cqe_seen(ring, entry)

    # connect
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_connect(sqe, fd, addr)
    sqe.user_data = 2
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 0
    assert entry.user_data == 2
    liburing.io_uring_cqe_seen(ring, entry)

    # shutdown & close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_shutdown(sqe, fd, liburing.SHUT_RDWR)
    sqe.flags = liburing.IOSQE_IO_LINK
    sqe.user_data = 3
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, fd)
    sqe.user_data = 4

    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 3
    liburing.io_uring_cqe_seen(ring, entry)

    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 4
    liburing.io_uring_cqe_seen(ring, entry)
