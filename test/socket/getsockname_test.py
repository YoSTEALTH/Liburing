import pytest
import liburing


@pytest.mark.skip_linux('6.11')
def test_getsockname(ring, cqe):
    with pytest.raises(TypeError):
        addr = liburing.sockaddr(liburing.AF_UNIX, b'./path')
        liburing.getsockname(-1, addr)

    ts = liburing.timespec(3)
    for i in range(2):
        # socket
        sqe = liburing.io_uring_get_sqe(ring)
        if i:
            addr = liburing.sockaddr(liburing.AF_INET6, b'::1', 0)
            liburing.io_uring_prep_socket(sqe, liburing.AF_INET6, liburing.SOCK_STREAM)
        else:
            addr = liburing.sockaddr(liburing.AF_INET, b'127.0.0.1', 0)
            liburing.io_uring_prep_socket(sqe, liburing.AF_INET, liburing.SOCK_STREAM)
        sqe.user_data = i+1
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        sockfd = liburing.trap_error(cqe.res)
        assert cqe.user_data == i+1
        liburing.io_uring_cqe_seen(ring, cqe)

        # bind
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_bind(sqe, sockfd, addr)
        sqe.user_data = i+1
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        liburing.trap_error(cqe.res)
        assert cqe.user_data == i+1
        liburing.io_uring_cqe_seen(ring, cqe)

        ip, port = liburing.getsockname(sockfd, addr)
        if i:
            assert ip == b'::1'
            assert port >= 1000
        else:
            assert ip == b'127.0.0.1'
            assert port >= 1000

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close(sqe, sockfd)
        sqe.user_data = i+1
        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        liburing.trap_error(cqe.res)
        assert cqe.user_data == i+1
        liburing.io_uring_cqe_seen(ring, cqe)
