import pytest
import liburing


@pytest.mark.skip_linux("6.19")
def test_getsockname(ring, cqe):
    with pytest.raises(TypeError):
        addr = liburing.Sockaddr(liburing.AF_UNIX, "./path")
        liburing.getsockname(-1, addr)

    ts = liburing.timespec(3)
    for i in range(2):
        # socket
        sqe = liburing.io_uring_get_sqe(ring)
        if i:
            addr = liburing.Sockaddr(liburing.AF_INET6, "::1", 0)  # port will be auto set to whatever is available.
            liburing.io_uring_prep_socket(sqe, addr.family, liburing.SOCK_STREAM)
        else:
            addr = liburing.Sockaddr(liburing.AF_INET, "127.0.0.1", 0)
            liburing.io_uring_prep_socket(sqe, addr.family, liburing.SOCK_STREAM)
        sqe.user_data = i
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        sockfd = entry.res
        assert entry.user_data == i
        liburing.io_uring_cqe_seen(ring, entry)

        # bind
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_bind(sqe, sockfd, addr)
        sqe.user_data = i + 1
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        assert entry.res == 0
        assert entry.user_data == i + 1
        liburing.io_uring_cqe_seen(ring, entry)

        # get sock name
        sockaddr = liburing.Sockaddr()
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.getsockname(sqe, sockfd, sockaddr)
        sqe.user_data = i + 2
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        assert entry.res == 0
        assert entry.user_data == i + 2
        liburing.io_uring_cqe_seen(ring, entry)

        if i:
            pass
            #     # assert sockaddr.ip == "::1" # TODO
            assert sockaddr.port >= 1000
        else:
            assert sockaddr.ip == "127.0.0.1"
            assert sockaddr.port >= 1000

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close(sqe, sockfd)
        sqe.user_data = i + 1
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        assert entry.res == 0
        assert entry.user_data == i + 1
        liburing.io_uring_cqe_seen(ring, entry)
