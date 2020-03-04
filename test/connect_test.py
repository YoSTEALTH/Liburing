from socket import (AF_INET, AF_INET6, SO_ERROR, SO_REUSEADDR, SO_REUSEPORT,
                    SOCK_STREAM, SOL_SOCKET, socket)

import pytest

import liburing
from liburing import ffi


def create_socket(ipv6=False):
    if ipv6:
        family = AF_INET6
    else:
        family = AF_INET
    return socket(family, SOCK_STREAM, 0)


def connect_socket(ring, ipv6=False):
    with create_socket(ipv6) as conn_sock:
        conn_sock.setsockopt(SOL_SOCKET, SO_REUSEPORT, 1)
        conn_sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
        if ipv6:
            sa, sock_len = liburing.build_sockaddr_in6(AF_INET6, "::1", 12315)
        else:
            sa, sock_len = liburing.build_sockaddr_in(AF_INET, "127.0.0.1",
                                                      12315)
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_connect(
            sqe,
            conn_sock.fileno(),
            ffi.cast('struct sockaddr *', sa),
            sock_len[0]
        )
        sqe.user_data = 1
        res = submit_and_wait(ring)
        return res


def submit_and_wait(ring):
    assert liburing.io_uring_submit_and_wait(ring, 1) == 1, \
        "io_uring_submit() failed"
    cqes = liburing.io_uring_cqes()
    assert liburing.io_uring_peek_cqe(ring, cqes) == 0, \
        "io_uring_peek_cqe() failed."
    cqe = cqes[0]
    liburing.io_uring_cqe_seen(ring, cqe)
    return cqe.res


def test_connect_with_no_peer(ring, ipv6=False):
    assert connect_socket(ring, ipv6) == -111, "connect_socket() failed."
    return 0


def test_connect(ring, ipv6=False):
    with create_socket(ipv6) as listen_sock:
        if ipv6:
            listen_sock.bind(('::1', 12315))
        else:
            listen_sock.bind(('127.0.0.1', 12315))
        listen_sock.listen(5)
        assert connect_socket(ring, ipv6) == 0,\
            "connect_socket() failed"
        return 0


def main():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(32, ring, 0) == 0,\
        "io_uring_queue_setup() failed"
    assert test_connect_with_no_peer(ring) == 0,\
        "test_connect_with_no_peer() failed, ipv6: False"
    assert test_connect(ring) == 0,\
        "test_connect() failed, ipv6: False"
    assert test_connect_with_no_peer(ring, True) == 0,\
        "test_connect_with_no_peer() failed, ipv6: True"
    assert test_connect(ring, True) == 0,\
        "test_connect() failed, ipv6: True"
    liburing.io_uring_queue_exit(ring)
    return 0


main()
