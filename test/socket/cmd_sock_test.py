import socket
from liburing import *


def test_setsockopt_getsockopt(ring, cqe):
    ts = timespec(3)
    # socket
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_socket(sqe, AF_INET, SOL_SOCKET)
    sqe.user_data = 1
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    sockfd = entry.res
    assert sockfd > 0
    assert entry.user_data == 1
    io_uring_cqe_seen(ring, entry)

    # python socket
    s = socket.socket(fileno=sockfd)
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 0

    # set
    val_set = (1).to_bytes(4, "little")
    sqe = io_uring_get_sqe(ring)  # will reuse
    setsockopt(sqe, sockfd, SOL_SOCKET, SO_REUSEADDR, val_set)
    sqe.user_data = 2
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0  # return `sizeof` int
    assert entry.user_data == 2
    io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_set, "little") == 1

    # get
    val_get = bytearray(4)
    sqe = io_uring_get_sqe(ring)
    getsockopt(sqe, sockfd, SOL_SOCKET, SO_REUSEADDR, val_get)
    sqe.user_data = 3
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 4  # return `sizeof` int
    assert entry.user_data == 3
    io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_get, "little") == 1
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 1

    # close socket
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 4
    io_uring_cqe_seen(ring, entry)


def test_cmd_sock(ring, cqe):
    ts = timespec(3)
    # socket
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_socket(sqe, AF_INET, SOL_SOCKET)
    sqe.user_data = 1
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    sockfd = entry.res
    assert sockfd > 0
    assert entry.user_data == 1
    io_uring_cqe_seen(ring, entry)

    # set
    sqe = io_uring_get_sqe(ring)
    val_set = bytearray((1).to_bytes(4, "big"))
    io_uring_prep_cmd_sock(
        sqe,
        io_uring_socket_op.SOCKET_URING_OP_SETSOCKOPT,
        sockfd,
        SOL_SOCKET,
        SO_REUSEADDR,
        val_set,
    )
    sqe.user_data = 2
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 2
    io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_set, "big") == 1

    # get
    val_get = bytearray(4)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_cmd_sock(
        sqe,
        io_uring_socket_op.SOCKET_URING_OP_GETSOCKOPT,
        sockfd,
        SOL_SOCKET,
        SO_REUSEADDR,
        val_get,
    )
    sqe.user_data = 3
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 4  # return `len()` int
    assert entry.user_data == 3
    io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_get, "little") == 1

    # close socket
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert entry.res == 0
    assert entry.user_data == 4
    io_uring_cqe_seen(ring, entry)
