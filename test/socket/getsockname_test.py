import errno
import kernel
import pytest
from liburing import *

# `SOCKET_URING_OP_GETSOCKNAME`: a socket command has no probe, the CQE says `EOPNOTSUPP`.
NO_GETSOCKNAME = f"Kernel `{LINUX_VERSION_MAJOR}.{LINUX_VERSION_MINOR}` does not support `SOCKET_URING_OP_GETSOCKNAME`"


def test_getsockname(ring, cqe):
    with pytest.raises(TypeError):
        addr = Sockaddr(AF_UNIX, "./path")
        getsockname(-1, addr)

    ts = timespec(3)
    for i in range(2):
        # socket
        sqe = io_uring_get_sqe(ring)
        if i:
            addr = Sockaddr(AF_INET6, "::1", 0)  # port will be auto set to whatever is available.
            io_uring_prep_socket(sqe, addr.family, SOCK_STREAM)
        else:
            addr = Sockaddr(AF_INET, "127.0.0.1", 0)
            io_uring_prep_socket(sqe, addr.family, SOCK_STREAM)
        sqe.user_data = i
        assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        sockfd = entry.res
        assert entry.user_data == i
        io_uring_cqe_seen(ring, entry)

        # bind
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_bind(sqe, sockfd, addr)
        sqe.user_data = i + 1
        assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        assert kernel.res(entry, "IORING_OP_BIND") == 0
        assert entry.user_data == i + 1
        io_uring_cqe_seen(ring, entry)

        # get sock name
        sockaddr = Sockaddr()
        sqe = io_uring_get_sqe(ring)
        getsockname(sqe, sockfd, sockaddr)
        sqe.user_data = i + 2
        assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        try:
            res = entry.res
        except OSError as e:
            if e.errno == errno.EOPNOTSUPP:
                pytest.skip(NO_GETSOCKNAME)
            raise
        assert res == 0
        assert entry.user_data == i + 2
        io_uring_cqe_seen(ring, entry)

        if i:
            assert sockaddr.ip == "::1"  # filled in by the kernel
            assert sockaddr.port >= 1000
        else:
            assert sockaddr.ip == "127.0.0.1"
            assert sockaddr.port >= 1000

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, sockfd)
        sqe.user_data = i + 1
        assert io_uring_submit_and_wait_timeout(ring, cqe, 1, ts) == 1
        entry = cqe[0]
        assert entry.res == 0
        assert entry.user_data == i + 1
        io_uring_cqe_seen(ring, entry)
