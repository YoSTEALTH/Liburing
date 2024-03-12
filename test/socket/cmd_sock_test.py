import array
import socket
import pytest
import liburing


def test_set_getsockopt(ring, cqe):
    ts = liburing.timespec(3)
    addr = liburing.sockaddr(liburing.AF_INET, b'0.0.0.0', 12345)  # not going to bind the socket
    # socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_socket(sqe, addr.family, liburing.SOL_SOCKET)
    sqe.user_data = 1
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert (sockfd := liburing.trap_error(cqe.res)) > 0
    assert cqe.user_data == 1
    liburing.io_uring_cqe_seen(ring, cqe)

    # python socket
    s = socket.socket(fileno=sockfd)
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 0

    sqe = liburing.io_uring_get_sqe(ring)  # will reuse
    with pytest.raises(ValueError):
        val = array.array('b', [0])
        liburing.io_uring_prep_setsockopt(sqe,
                                          sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val)
    with pytest.raises(ValueError):
        val = array.array('b', [0])
        liburing.io_uring_prep_getsockopt(sqe,
                                          sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val)
    # set
    val_set = array.array('i', [1])
    liburing.io_uring_prep_setsockopt(sqe,
                                      sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_set)
    sqe.user_data = 2
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 2
    liburing.io_uring_cqe_seen(ring, cqe)
    assert val_set[0] == 1

    # get
    val_get = array.array('i', [0])
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_getsockopt(sqe,
                                      sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_get)
    sqe.user_data = 3
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) >= 2  # return `sizeof` int
    assert cqe.user_data == 3
    liburing.io_uring_cqe_seen(ring, cqe)
    assert val_get[0] == 1
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 1

    # close socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 4
    liburing.io_uring_cqe_seen(ring, cqe)


def test_cmd_sock(ring, cqe):
    ts = liburing.timespec(3)
    addr = liburing.sockaddr(liburing.AF_INET, b'0.0.0.0', 12345)  # not going to bind the socket
    # socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_socket(sqe, addr.family, liburing.SOL_SOCKET)
    sqe.user_data = 1
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert (sockfd := liburing.trap_error(cqe.res)) > 0
    assert cqe.user_data == 1
    liburing.io_uring_cqe_seen(ring, cqe)

    sqe = liburing.io_uring_get_sqe(ring)
    with pytest.raises(ValueError):
        val = array.array('b', [0])
        liburing.io_uring_prep_cmd_sock(sqe, liburing.SOCKET_URING_OP_SETSOCKOPT,
                                        sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val)
    # set
    val_set = array.array('i', [1])
    liburing.io_uring_prep_cmd_sock(sqe, liburing.SOCKET_URING_OP_SETSOCKOPT,
                                    sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_set)
    sqe.user_data = 2
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 2
    liburing.io_uring_cqe_seen(ring, cqe)
    assert val_set[0] == 1

    # get
    val_get = array.array('i', [0])
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_cmd_sock(sqe, liburing.SOCKET_URING_OP_GETSOCKOPT,
                                    sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_get)
    sqe.user_data = 3
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) >= 2  # return `sizeof` int
    assert cqe.user_data == 3
    liburing.io_uring_cqe_seen(ring, cqe)
    assert val_get[0] == 1

    # close socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 4
    liburing.io_uring_cqe_seen(ring, cqe)
