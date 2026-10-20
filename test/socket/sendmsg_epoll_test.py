"""sendmsg / recvmsg (`Msghdr`), the multishot receive helpers (`RecvmsgOut`, `Cmsghdr`) and epoll (`EpollEvent`)."""

import array
import os
import select
import socket
import struct
import pytest
import liburing as L

EPOLL_CTL_ADD = 1


def one(ring, cqe, prep, *args, **kwargs):
    sqe = L.io_uring_get_sqe(ring)
    prep(sqe, *args, **kwargs)
    sqe.user_data = 9
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    entry = cqe[0]
    try:
        assert entry.user_data == 9
        return entry.res
    finally:
        L.io_uring_cqe_seen(ring, entry)


@pytest.fixture
def udp():
    rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    rx.bind(("127.0.0.1", 0))
    tx.bind(("127.0.0.1", 0))
    yield rx, tx
    rx.close()
    tx.close()


def test_msghdr_fields():
    msg = L.Msghdr()
    assert (msg.flags, msg.namelen, msg.controllen, msg.iovlen) == (0, 0, 0, 0)
    msg.flags = 3
    msg.namelen = 16
    assert (msg.flags, msg.namelen) == (3, 16)
    control = bytearray(32)
    iov_src = [bytearray(4), bytearray(4)]
    full = L.Msghdr(L.Sockaddr(L.AF_INET, "127.0.0.1", 9), L.Iovec(iov_src), control)
    assert full.namelen == 16  # sockaddr_in
    assert full.iovlen == 2
    assert full.controllen == 32
    full.controllen = 8
    assert full.controllen == 8
    with pytest.raises(ValueError):
        full.controllen = 64  # longer than `control`
    with pytest.raises(ValueError):
        L.Msghdr(control=control, controllen=64)
    with pytest.raises(TypeError):
        L.Msghdr(name=object())
    with pytest.raises(TypeError):
        L.Msghdr(iov=[b"x"])


def test_sendmsg_recvmsg(ring, cqe, udp):
    rx, tx = udp
    dest = L.Sockaddr(L.AF_INET, "127.0.0.1", rx.getsockname()[1])
    parts = [bytearray(b"hel"), bytearray(b"lo")]
    iov = L.Iovec(parts)
    msg = L.Msghdr(dest, iov)
    assert one(ring, cqe, L.io_uring_prep_sendmsg, tx.fileno(), msg) == 5

    came_from = L.Sockaddr()
    got = [bytearray(16)]
    into = L.Iovec(got)
    rmsg = L.Msghdr(came_from, into)
    assert one(ring, cqe, L.io_uring_prep_recvmsg, rx.fileno(), rmsg) == 5
    assert bytes(got[0][:5]) == b"hello"
    assert (came_from.ip, came_from.port) == ("127.0.0.1", tx.getsockname()[1])
    assert rmsg.namelen == 16


def test_sendmsg_temporary_objects_survive(ring, cqe, udp):
    rx, tx = udp
    keep = [bytearray(b"temp")]
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_sendmsg(sqe, tx.fileno(), L.Msghdr(L.Sockaddr(L.AF_INET, "127.0.0.1", rx.getsockname()[1]), L.Iovec(keep)))
    junk = [L.Msghdr() for _ in range(100)]  # reuses the freed memory
    del junk
    sqe.user_data = 1
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    assert cqe[0].res == 4
    L.io_uring_cqe_seen(ring, cqe[0])
    assert rx.recv(8) == b"temp"


def test_sendmsg_zc(ring, cqe, udp):
    rx, tx = udp
    src = [bytearray(b"zc!")]
    msg = L.Msghdr(L.Sockaddr(L.AF_INET, "127.0.0.1", rx.getsockname()[1]), L.Iovec(src))
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_sendmsg_zc(sqe, tx.fileno(), msg)
    assert L.io_uring_submit(ring) == 1
    while True:  # the result, then the notification that the buffer is free
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
        more = cqe[0].flags & L.IORING_CQE_F_MORE
        L.io_uring_cqe_seen(ring, cqe[0])
        if not more:
            break
    assert rx.recv(8) == b"zc!"


def test_recvmsg_multishot_with_helpers(ring, cqe, udp):
    rx, tx = udp
    area = bytearray(2 * 256)
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_provide_buffers(sqe, area, 2, 1, 0)  # 2 buffers of 256
    L.io_uring_submit(ring)
    L.io_uring_wait_cqe(ring, cqe)
    assert cqe[0].res == 0
    L.io_uring_cqe_seen(ring, cqe[0])

    msg = L.Msghdr(namelen=16, controllen=0)  # the layout: [header][name 16][control 0][payload]
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_recvmsg_multishot(sqe, rx.fileno(), msg)
    sqe.flags = L.IOSQE_BUFFER_SELECT
    L.io_uring_sqe_set_buf_group(sqe, 1)
    sqe.user_data = 7
    assert L.io_uring_submit(ring) == 1
    tx.sendto(b"multishot!", rx.getsockname())
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(2)) == 0
    res, flags = cqe[0].res, cqe[0].flags
    L.io_uring_cqe_seen(ring, cqe[0])
    assert flags & L.IORING_CQE_F_BUFFER
    bid = flags >> L.IORING_CQE_BUFFER_SHIFT
    buf = memoryview(area)[bid * 256 : (bid + 1) * 256]

    out = L.io_uring_recvmsg_validate(buf, msg)
    assert out.namelen == 16
    assert out.controllen == 0
    assert out.payloadlen == len(b"multishot!")
    assert L.io_uring_recvmsg_payload(out, msg) == b"multishot!"
    assert L.io_uring_recvmsg_payload_length(out, 256, msg) == 256 - 16 - 16
    name = L.io_uring_recvmsg_name(out)
    assert len(name) == 16
    family, port = struct.unpack_from("=HH", name)
    assert family == L.AF_INET
    assert socket.ntohs(port) == tx.getsockname()[1]
    assert L.io_uring_recvmsg_cmsg_firsthdr(out, msg) is None  # no control data

    assert one(ring, cqe, L.io_uring_prep_cancel, 7) == 0
    L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(1))
    L.io_uring_cq_advance(ring, L.io_uring_cq_ready(ring))


def test_recvmsg_validate_too_short():
    msg = L.Msghdr(namelen=16, controllen=0)
    with pytest.raises(ValueError):
        L.io_uring_recvmsg_validate(bytearray(8), msg)  # not even the header
    with pytest.raises(ValueError):
        L.io_uring_recvmsg_validate(bytearray(20), msg)  # header (16) + name (16) do not fit


def test_cmsg_walk_over_a_built_buffer():
    # [header][name][cmsg: SCM_RIGHTS with one int][payload]: what the kernel puts into a provided buffer
    name = bytes(16)
    cmsg = struct.pack("=QII", struct.calcsize("=QII") + 4, L.SOL_SOCKET, 1) + struct.pack("=i", 7) + bytes(4)
    header = struct.pack("=IIII", len(name), len(cmsg), 3, 0)
    buf = bytearray(header + name + cmsg + b"abc")
    msg = L.Msghdr(namelen=len(name), controllen=len(cmsg))
    out = L.io_uring_recvmsg_validate(buf, msg)
    first = L.io_uring_recvmsg_cmsg_firsthdr(out, msg)
    assert first
    assert (first.level, first.type) == (L.SOL_SOCKET, 1)
    assert first.len == struct.calcsize("=QII") + 4
    assert first.data == struct.pack("=i", 7)
    assert L.io_uring_recvmsg_cmsg_nexthdr(out, msg, first) is None
    assert L.io_uring_recvmsg_payload(out, msg) == b"abc"


def test_epoll_event_fields():
    ev = L.EpollEvent(events=select.EPOLLIN, data=123)
    assert (ev.events, ev.data) == (select.EPOLLIN, 123)
    ev.events = select.EPOLLOUT
    ev.data = 5
    assert (ev.events, ev.data) == (select.EPOLLOUT, 5)
    assert len(ev) == 1
    many = L.EpollEvent(no=4)
    assert len(many) == 4
    many[2].data = 77
    assert many[2].data == 77 and many[0].data == 0
    with pytest.raises(IndexError):
        many[4]
    with pytest.raises(IndexError):
        many[2][0]
    with pytest.raises(ValueError):
        L.EpollEvent(no=0)
    with pytest.raises(ValueError):
        L.EpollEvent(no=2, data=1)


def test_epoll_ctl_wait(ring, cqe):
    ep = select.epoll()
    r, w = os.pipe()
    try:
        ev = L.EpollEvent(events=select.EPOLLIN, data=r)
        assert one(ring, cqe, L.io_uring_prep_epoll_ctl, ep.fileno(), r, EPOLL_CTL_ADD, ev) == 0
        assert ep.poll(0) == []
        os.write(w, b"x")
        ready = L.EpollEvent(no=4)
        assert one(ring, cqe, L.io_uring_prep_epoll_wait, ep.fileno(), ready, 4) == 1
        assert (ready[0].events & select.EPOLLIN, ready[0].data) == (select.EPOLLIN, r)
        with pytest.raises(ValueError):  # more than the array holds
            L.io_uring_prep_epoll_wait(L.Sqe(), ep.fileno(), ready, 5)
        with pytest.raises(ValueError):
            L.io_uring_prep_epoll_wait(L.Sqe(), ep.fileno(), ready[0], 1)
    finally:
        ep.close()
        os.close(r)
        os.close(w)
