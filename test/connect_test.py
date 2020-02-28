from socket import socket, AF_INET, SOCK_STREAM, \
        SOL_SOCKET, SO_REUSEADDR, SO_REUSEPORT, SO_ERROR

import liburing
from liburing import ffi


def connect_socket(ring):
    conn_sock = socket(AF_INET, SOCK_STREAM, 0)
    with conn_sock:
        conn_sock.setsockopt(SOL_SOCKET, SO_REUSEPORT, 1)
        conn_sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)

        sa, sock_len = liburing.build_sockaddr_in("127.0.0.1", 12315)
        sa.sin_family = AF_INET
        # DEBUG print sockaddr_in
        # buffer = liburing.ffi.new('char []', 1024)
        # liburing.inet_ntop(
        #     AF_INET,
        #     liburing.ffi.addressof(sa.sin_addr),
        #     buffer,
        #     len(buffer)
        # )
        # liburing.printf(b'address: %s\n', buffer)
        # print("port: ", liburing.ntohs(sa.sin_port))

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
    # DEBUG print cqe info
    # print("user_data: ", cqe.user_data)
    # print("res: ", cqe.res)
    # print("flags: ", cqe.flags)
    return cqe.res


def test_connect_with_no_peer(ring):
    assert connect_socket(ring) == -111, "connect_socket() failed."
    return 0


def test_connect(ring):
    listen_sock = socket(AF_INET, SOCK_STREAM, 0)
    listen_sock.bind(('127.0.0.1', 12315))
    listen_sock.listen(5)
    with listen_sock:
        assert connect_socket(ring) == 0,\
            "connect_socket() failed"
        return 0


def main():
    ring = liburing.io_uring()
    assert liburing.io_uring_queue_init(32, ring, 0) == 0,\
        "io_uring_queue_setup() failed"
    assert test_connect_with_no_peer(ring) == 0,\
        "test_connect_with_no_peer() failed"
    assert test_connect(ring) == 0,\
        "test_connect() failed"
    liburing.io_uring_queue_exit(ring)
    return 0


main()
