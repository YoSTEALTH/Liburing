"""Network, poll, timeout and cancel operations run for real through the ring (loopback only)."""

import array
import errno
import os
import socket
import select
import pytest
import liburing as L


def one(ring, cqe, prep, *args, **kwargs):
    """Prepares one operation and gives its `res` (`OSError` for a failed one)."""
    sqe = L.io_uring_get_sqe(ring)
    prep(sqe, *args, **kwargs)
    sqe.user_data = 9
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    try:
        assert entry.user_data == 9
        return entry.res
    finally:
        L.io_uring_cqe_seen(ring, entry)


@pytest.fixture
def pair():
    """A connected TCP pair on loopback: (listener, client, server-side connection)."""
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(4)
    client = socket.create_connection(listener.getsockname())
    conn, _ = listener.accept()
    yield listener, client, conn
    for s in (listener, client, conn):
        s.close()


def test_send_recv(ring, cqe, pair):
    _, client, conn = pair
    assert one(ring, cqe, L.io_uring_prep_send, client.fileno(), b"ping") == 4
    buf = bytearray(8)
    assert one(ring, cqe, L.io_uring_prep_recv, conn.fileno(), buf) == 4
    assert buf[:4] == b"ping"


def test_send_zc(ring, cqe, pair):
    _, client, conn = pair
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_send_zc(sqe, client.fileno(), b"zero-copy")
    sqe.user_data = 1
    assert L.io_uring_submit(ring) == 1
    seen = 0
    while True:  # a result cqe (more=notification follows), then the notification cqe
        assert L.io_uring_wait_cqe(ring, cqe) == 0
        flags, res = cqe[0].flags, cqe[0].res
        L.io_uring_cqe_seen(ring, cqe[0])
        seen += 1
        if not flags & L.IORING_CQE_F_MORE:
            break
    assert seen == 2
    assert conn.recv(16) == b"zero-copy"


def test_sendto_recv_udp(ring, cqe):
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        rx.bind(("127.0.0.1", 0))
        addr = L.Sockaddr(L.AF_INET, "127.0.0.1", rx.getsockname()[1])
        assert one(ring, cqe, L.io_uring_prep_sendto, tx.fileno(), b"udp", addr) == 3
        assert rx.recv(8) == b"udp"
    finally:
        rx.close()
        tx.close()


def test_accept_and_multishot_accept(ring, cqe):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(4)
    port = listener.getsockname()[1]
    clients = []
    try:
        clients.append(socket.create_connection(("127.0.0.1", port)))
        fd = one(ring, cqe, L.io_uring_prep_accept, listener.fileno())
        assert fd > 0
        os.close(fd)

        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_multishot_accept(sqe, listener.fileno())
        sqe.user_data = 5
        L.io_uring_submit(ring)
        clients.append(socket.create_connection(("127.0.0.1", port)))
        clients.append(socket.create_connection(("127.0.0.1", port)))
        got = 0
        while got < 2:  # one cqe per connection (the first connect was accepted above)
            assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
            assert cqe[0].flags & L.IORING_CQE_F_MORE
            os.close(cqe[0].res)
            L.io_uring_cqe_seen(ring, cqe[0])
            got += 1
        assert one(ring, cqe, L.io_uring_prep_cancel, 5) == 0
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0  # the cancelled multishot accept
        assert cqe[0].user_data == 5
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        for s in clients + [listener]:
            s.close()


def test_accept_direct(ring, cqe):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(4)
    client = socket.create_connection(listener.getsockname())
    try:
        assert L.io_uring_register_files_sparse(ring, 4) == 0
        assert one(ring, cqe, L.io_uring_prep_accept_direct, listener.fileno(), None, 2) == 0
        assert one(ring, cqe, L.io_uring_prep_close_direct, 2) == 0
        assert L.io_uring_unregister_files(ring) == 0
    finally:
        client.close()
        listener.close()


def test_socket_listen_bind_connect_shutdown(ring, cqe):
    fd = one(ring, cqe, L.io_uring_prep_socket, L.AF_INET, L.SOCK_STREAM, 0)
    assert fd > 0
    cl = None
    try:
        addr = L.Sockaddr(L.AF_INET, "127.0.0.1", 0)
        assert one(ring, cqe, L.io_uring_prep_bind, fd, addr) == 0
        assert one(ring, cqe, L.io_uring_prep_listen, fd, 4) == 0
        port = socket.socket(fileno=os.dup(fd)).getsockname()[1]
        cl = socket.socket()
        target = L.Sockaddr(L.AF_INET, "127.0.0.1", port)
        cfd = one(ring, cqe, L.io_uring_prep_socket, L.AF_INET, L.SOCK_STREAM, 0)
        try:
            assert one(ring, cqe, L.io_uring_prep_connect, cfd, target) == 0
            assert one(ring, cqe, L.io_uring_prep_shutdown, cfd, L.SHUT_WR) == 0
        finally:
            os.close(cfd)
    finally:
        if cl:
            cl.close()
        os.close(fd)


def test_socket_direct(ring, cqe):
    assert L.io_uring_register_files_sparse(ring, 2) == 0
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_socket_direct(sqe, L.AF_INET, L.SOCK_STREAM, 0, 1)
    sqe.user_data = 1
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    assert cqe[0].res == 0
    L.io_uring_cqe_seen(ring, cqe[0])
    assert one(ring, cqe, L.io_uring_prep_close_direct, 1) == 0
    assert L.io_uring_unregister_files(ring) == 0


def test_poll(ring, cqe, pair):
    _, client, conn = pair
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_poll_add(sqe, conn.fileno(), select.POLLIN)
    sqe.user_data = 1
    assert L.io_uring_submit(ring) == 1
    client.send(b"x")
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    assert cqe[0].res & select.POLLIN
    L.io_uring_cqe_seen(ring, cqe[0])


def test_poll_multishot_remove(ring, cqe, pair):
    _, client, conn = pair
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_poll_multishot(sqe, conn.fileno(), select.POLLIN)
    sqe.user_data = 77
    assert L.io_uring_submit(ring) == 1
    client.send(b"x")
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    assert cqe[0].flags & L.IORING_CQE_F_MORE
    L.io_uring_cqe_seen(ring, cqe[0])
    assert one(ring, cqe, L.io_uring_prep_poll_remove, 77) == 0
    # the removed poll posts a final cqe of its own
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    L.io_uring_cqe_seen(ring, cqe[0])


def test_poll_update(ring, cqe, pair):
    _, client, conn = pair
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_poll_add(sqe, conn.fileno(), select.POLLOUT | select.POLLIN)
    sqe.user_data = 1
    L.io_uring_submit(ring)
    L.io_uring_wait_cqe(ring, cqe)  # POLLOUT is ready at once
    L.io_uring_cqe_seen(ring, cqe[0])
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_poll_add(sqe, conn.fileno(), select.POLLIN)
    sqe.user_data = 2
    L.io_uring_submit(ring)
    r = one(
        ring, cqe, L.io_uring_prep_poll_update, 2, 3, select.POLLIN, L.IORING_POLL_UPDATE_EVENTS | L.IORING_POLL_UPDATE_USER_DATA
    )
    assert r == 0
    client.send(b"x")
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    assert cqe[0].user_data == 3  # reported under the new user_data
    L.io_uring_cqe_seen(ring, cqe[0])


def test_timeout_remove_update_cancel(ring, cqe):
    ts = L.timespec(30)
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_timeout(sqe, ts, 0)
    sqe.user_data = 10
    assert L.io_uring_submit(ring) == 1
    assert one(ring, cqe, L.io_uring_prep_timeout_update, L.timespec(0.01), 10) == 0
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    assert cqe[0].user_data == 10
    with pytest.raises(OSError) as e:  # a timeout that ran out reports ETIME
        cqe[0].res
    assert e.value.errno == 62
    L.io_uring_cqe_seen(ring, cqe[0])

    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_timeout(sqe, ts, 0)
    sqe.user_data = 11
    L.io_uring_submit(ring)
    assert one(ring, cqe, L.io_uring_prep_timeout_remove, 11) == 0
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    assert cqe[0].user_data == 11
    L.io_uring_cqe_seen(ring, cqe[0])  # removed: ECANCELED


def test_cancel_variants(ring, cqe, pair):
    _, client, conn = pair
    for prep, arg in ((L.io_uring_prep_cancel, 3), (L.io_uring_prep_cancel64, 3)):
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_recv(sqe, conn.fileno(), bytearray(4))
        sqe.user_data = 3
        L.io_uring_submit(ring)
        assert one(ring, cqe, prep, arg) == 0
        L.io_uring_wait_cqe(ring, cqe)
        assert cqe[0].user_data == 3
        L.io_uring_cqe_seen(ring, cqe[0])  # the cancelled recv: ECANCELED
    # by fd
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_recv(sqe, conn.fileno(), bytearray(4))
    sqe.user_data = 3
    L.io_uring_submit(ring)
    assert one(ring, cqe, L.io_uring_prep_cancel_fd, conn.fileno()) == 0
    L.io_uring_wait_cqe(ring, cqe)
    L.io_uring_cqe_seen(ring, cqe[0])


def test_link_timeout(ring, cqe, pair):
    _, _, conn = pair
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_recv(sqe, conn.fileno(), bytearray(4))  # nothing will arrive
    sqe.flags = L.IOSQE_IO_LINK
    sqe.user_data = 1
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_link_timeout(sqe, L.timespec(0.05), 0)
    sqe.user_data = 2
    assert L.io_uring_submit(ring) == 2
    seen = {}
    for _ in range(2):
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
        seen[cqe[0].user_data] = cqe[0].flags
        L.io_uring_cqe_seen(ring, cqe[0])
    assert set(seen) == {1, 2}


def test_msg_ring(ring, cqe):
    other = L.Ring()
    L.io_uring_queue_init(8, other)
    try:
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_msg_ring(sqe, other.ring_fd, 7, 1234)
        sqe.user_data = 1
        assert L.io_uring_submit(ring) == 1
        got = L.Cqe()
        assert L.io_uring_wait_cqe_timeout(other, got, L.timespec(2)) == 0
        assert (got[0].user_data, got[0].res) == (1234, 7)
        L.io_uring_cqe_seen(other, got[0])
        assert L.io_uring_wait_cqe(ring, cqe) == 0  # the sender's own completion
        L.io_uring_cqe_seen(ring, cqe[0])

        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_msg_ring_cqe_flags(sqe, other.ring_fd, 5, 99, 0, 3)
        sqe.user_data = 2
        L.io_uring_submit(ring)
        assert L.io_uring_wait_cqe_timeout(other, got, L.timespec(2)) == 0
        assert (got[0].user_data, got[0].res, got[0].flags) == (99, 5, 3)
        L.io_uring_cqe_seen(other, got[0])
        L.io_uring_wait_cqe(ring, cqe)
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        L.io_uring_queue_exit(other)


def test_splice_tee_pipe(ring, cqe, tmp_dir):
    r, w = os.pipe()
    r2, w2 = os.pipe()
    f = os.open(tmp_dir / "s.txt", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        os.write(f, b"spliced!")
        assert one(ring, cqe, L.io_uring_prep_splice, f, 0, w, -1, 8, 0) == 8
        assert one(ring, cqe, L.io_uring_prep_tee, r, w2, 8, 0) == 8
        assert os.read(r, 8) == b"spliced!"
        assert os.read(r2, 8) == b"spliced!"
    finally:
        for fd in (r, w, r2, w2, f):
            os.close(fd)


def test_prep_pipe(ring, cqe):
    fds = array.array("i", [-1, -1])  # the kernel fills it in when the request completes
    assert one(ring, cqe, L.io_uring_prep_pipe, fds, 0) == 0
    try:
        os.write(fds[1], b"hi")
        assert os.read(fds[0], 2) == b"hi"
    finally:
        os.close(fds[0])
        os.close(fds[1])
    with pytest.raises(ValueError):
        L.io_uring_prep_pipe(L.Sqe(), bytearray(4), 0)


def test_prep_pipe_direct(ring, cqe):
    fds = array.array("i", [-1, -1])
    assert L.io_uring_register_files_sparse(ring, 4) == 0
    assert one(ring, cqe, L.io_uring_prep_pipe_direct, fds, 0, 0) == 0
    if L.linux_version_check(7.0):
        # kernel bug fixed in 7.0 (stable backports vary): `io_pipe_fixed()` reported `(0, 0)`
        assert fds[0] == 0
    else:
        assert tuple(fds) == (0, 1)  # the slots used in the file table
    assert one(ring, cqe, L.io_uring_prep_close_direct, 0) == 0
    assert one(ring, cqe, L.io_uring_prep_close_direct, 1) == 0
    assert L.io_uring_unregister_files(ring) == 0


def test_provide_remove_buffers(ring, cqe):
    area = bytearray(32)
    assert one(ring, cqe, L.io_uring_prep_provide_buffers, area, 2, 1, 0) == 0
    assert one(ring, cqe, L.io_uring_prep_remove_buffers, 2, 1) == 2


def test_read_multishot_with_provided_buffers(ring, cqe):
    r, w = os.pipe()
    area = bytearray(64)
    try:
        assert one(ring, cqe, L.io_uring_prep_provide_buffers, area, 4, 1, 0) == 0
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_read_multishot(sqe, r, 1)
        sqe.user_data = 1
        assert L.io_uring_submit(ring) == 1
        os.write(w, b"abc")
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
        assert cqe[0].res == 3
        assert cqe[0].flags & L.IORING_CQE_F_MORE
        L.io_uring_cqe_seen(ring, cqe[0])
        assert one(ring, cqe, L.io_uring_prep_cancel, 1) == 0
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0  # the cancelled read
        assert cqe[0].user_data == 1
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        os.close(r)
        os.close(w)


def test_provide_buffers_are_split_evenly(ring, cqe):
    r, w = os.pipe()
    area = bytearray(b"\xaa" * 64)
    try:
        assert one(ring, cqe, L.io_uring_prep_provide_buffers, area, 4, 1, 0) == 0  # 4 buffers of 16 bytes
        os.write(w, b"x" * 40)
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_read_multishot(sqe, r, 1)  # picks a buffer from group 1
        sqe.user_data = 1
        assert L.io_uring_submit(ring) == 1
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
        assert cqe[0].res == 16  # one buffer, never more: nothing is written past `area`
        L.io_uring_cqe_seen(ring, cqe[0])
        L.io_uring_prep_cancel(L.io_uring_get_sqe(ring), 1)
        assert L.io_uring_submit(ring) == 1
        assert L.io_uring_wait_cqe_nr(ring, cqe, 2) == 0  # the cancel and the cancelled read
        L.io_uring_cq_advance(ring, 2)
    finally:
        os.close(r)
        os.close(w)


def test_provide_buffers_arguments(ring):
    sqe = L.io_uring_get_sqe(ring)
    with pytest.raises(ValueError):
        L.io_uring_prep_provide_buffers(sqe, bytearray(8), 0, 1, 0)
    with pytest.raises(ValueError):
        L.io_uring_prep_provide_buffers(sqe, bytearray(2), 4, 1, 0)


def test_send_set_addr_udp(ring, cqe):
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        rx.bind(("127.0.0.1", 0))
        addr = L.Sockaddr(L.AF_INET, "127.0.0.1", rx.getsockname()[1])
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_send(sqe, tx.fileno(), b"set-addr")
        L.io_uring_prep_send_set_addr(sqe, addr)  # a temporary would be fine too: kept until the submit
        sqe.user_data = 4
        assert L.io_uring_submit(ring) == 1
        assert L.io_uring_wait_cqe(ring, cqe) == 0
        assert cqe[0].res == 8
        L.io_uring_cqe_seen(ring, cqe[0])
        assert rx.recv(16) == b"set-addr"
    finally:
        rx.close()
        tx.close()


# `SOCKET_URING_OP_GETSOCKNAME`: a socket command has no probe, the CQE says `EOPNOTSUPP`.
NO_GETSOCKNAME = (
    f"Kernel `{L.LINUX_VERSION_MAJOR}.{L.LINUX_VERSION_MINOR}` does not support `SOCKET_URING_OP_GETSOCKNAME`"
)


def test_cmd_getsockname(ring, cqe, pair):
    listener, client, _ = pair
    for peer, expect in ((0, client.getsockname()), (1, client.getpeername())):
        out = L.Sockaddr()
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_cmd_getsockname(sqe, client.fileno(), out, peer)
        sqe.user_data = 6
        assert L.io_uring_submit(ring) == 1
        assert L.io_uring_wait_cqe(ring, cqe) == 0
        try:
            assert cqe[0].res >= 0
        except OSError as e:
            if e.errno == errno.EOPNOTSUPP:
                pytest.skip(NO_GETSOCKNAME)
            raise
        L.io_uring_cqe_seen(ring, cqe[0])
        assert (out.ip, out.port) == expect
