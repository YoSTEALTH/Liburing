import os
import socket
from liburing import *


def test_send_recv(ring, cqe):
    s, r = socket.socketpair(
        socket.AF_UNIX,
        socket.SOCK_STREAM | socket.SOCK_NONBLOCK,
    )

    try:
        data = os.urandom(1024)
        user_data1 = int.from_bytes(os.urandom(1))
        user_data2 = int.from_bytes(os.urandom(1))
        rbuf = bytearray(1024)

        ssqe = io_uring_get_sqe(ring)
        assert ssqe is not None

        io_uring_prep_send(
            ssqe,
            s.fileno(),
            data,
        )

        rsqe = io_uring_get_sqe(ring)
        assert rsqe is not None

        io_uring_prep_recv(
            rsqe,
            r.fileno(),
            rbuf,
        )

        io_uring_sqe_set_data64(ssqe, user_data1)
        io_uring_sqe_set_data64(rsqe, user_data2)

        assert io_uring_submit(ring) == 2

        completions = []
        user_data = []

        for _ in range(2):
            assert io_uring_wait_cqe(ring, cqe) == 0

            completions.append(cqe[0].res)
            user_data.append(cqe[0].user_data)

            io_uring_cqe_seen(ring, cqe[0])

        assert completions == [1024, 1024]
        assert sorted(user_data) == sorted([user_data1, user_data2])
        assert bytes(rbuf) == data

    finally:
        s.close()
        r.close()
