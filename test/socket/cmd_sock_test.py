import socket
import pytest
import liburing


@pytest.mark.skip_linux("6.7")
def test_setsockopt_getsockopt(ring, cqe):
    ts = liburing.timespec(3)
    # socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_socket(sqe, liburing.AF_INET, liburing.SOL_SOCKET)
    sqe.user_data = 1
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert (sockfd := liburing.trap_error(entry.res)) > 0
    assert entry.user_data == 1
    liburing.io_uring_cqe_seen(ring, entry)

    # python socket
    s = socket.socket(fileno=sockfd)
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 0

    # set
    val_set = (1).to_bytes(4, "little")
    sqe = liburing.io_uring_get_sqe(ring)  # will reuse
    liburing.setsockopt(sqe, sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_set)
    sqe.user_data = 2
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 0  # return `sizeof` int
    assert entry.user_data == 2
    liburing.io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_set, "little") == 1

    # get
    val_get = bytearray(4)
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.getsockopt(sqe, sockfd, liburing.SOL_SOCKET, liburing.SO_REUSEADDR, val_get)
    sqe.user_data = 3
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 4  # return `sizeof` int
    assert entry.user_data == 3
    liburing.io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_get, "little") == 1
    assert s.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) == 1

    # close socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 0
    assert entry.user_data == 4
    liburing.io_uring_cqe_seen(ring, entry)


@pytest.mark.skip_linux("6.7")
def test_cmd_sock(ring, cqe):
    ts = liburing.timespec(3)
    # socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_socket(sqe, liburing.AF_INET, liburing.SOL_SOCKET)
    sqe.user_data = 1
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert (sockfd := liburing.trap_error(entry.res)) > 0
    assert entry.user_data == 1
    liburing.io_uring_cqe_seen(ring, entry)

    # set
    sqe = liburing.io_uring_get_sqe(ring)
    val_set = bytearray((1).to_bytes(4, "big"))
    liburing.io_uring_prep_cmd_sock(
        sqe,
        liburing.io_uring_socket_op.SOCKET_URING_OP_SETSOCKOPT,
        sockfd,
        liburing.SOL_SOCKET,
        liburing.SO_REUSEADDR,
        val_set,
    )
    sqe.user_data = 2
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 0
    assert entry.user_data == 2
    liburing.io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_set, "big") == 1

    # get
    val_get = bytearray(4)
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_cmd_sock(
        sqe,
        liburing.io_uring_socket_op.SOCKET_URING_OP_GETSOCKOPT,
        sockfd,
        liburing.SOL_SOCKET,
        liburing.SO_REUSEADDR,
        val_get,
    )
    sqe.user_data = 3
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 4  # return `len()` int
    assert entry.user_data == 3
    liburing.io_uring_cqe_seen(ring, entry)
    assert int.from_bytes(val_get, "little") == 1

    # close socket
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, sockfd)
    sqe.user_data = 4
    assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
    entry = cqe[0]
    assert liburing.trap_error(entry.res) == 0
    assert entry.user_data == 4
    liburing.io_uring_cqe_seen(ring, entry)
