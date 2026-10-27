"""sendmsg / recvmsg (`Msghdr`), the multishot receive helpers (`RecvmsgOut`, `Cmsghdr`) and epoll (`EpollEvent`)."""

import os
import select
import socket
import struct
import kernel
import pytest
from liburing import *

EPOLL_CTL_ADD = 1
FIXED_ZC = "`IORING_OP_SENDMSG_ZC` with `IORING_RECVSEND_FIXED_BUF`"


def one(ring, cqe, prep, *args, **kwargs):
    sqe = io_uring_get_sqe(ring)
    prep(sqe, *args, **kwargs)
    op = sqe.opcode
    sqe.user_data = 9
    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
    entry = cqe[0]
    try:
        assert entry.user_data == 9
        return kernel.res(entry, op)
    finally:
        io_uring_cqe_seen(ring, entry)


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
    msg = Msghdr()
    assert (msg.flags, msg.namelen, msg.controllen, msg.iovlen) == (0, 0, 0, 0)
    msg.flags = 3
    msg.namelen = 16
    assert (msg.flags, msg.namelen) == (3, 16)
    control = bytearray(32)
    iov_src = [bytearray(4), bytearray(4)]
    full = Msghdr(Sockaddr(AF_INET, "127.0.0.1", 9), iov_src, control)
    assert full.namelen == 16  # sockaddr_in
    assert full.iovlen == 2
    assert full.controllen == 32
    full.controllen = 8
    assert full.controllen == 8
    with pytest.raises(ValueError):
        full.controllen = 64  # longer than `control`
    with pytest.raises(ValueError, match="longer than a `Sockaddr`"):
        full.namelen = 129  # past `sockaddr_storage` (128)
    with pytest.raises(ValueError):
        Msghdr(control=control, controllen=64)
    with pytest.raises(TypeError):
        Msghdr(name=object())
    with pytest.raises(TypeError):
        Msghdr(iov=[object()])  # no buffer protocol


def test_sendmsg_recvmsg(ring, cqe, udp):
    rx, tx = udp
    dest = Sockaddr(AF_INET, "127.0.0.1", rx.getsockname()[1])
    parts = [bytearray(b"hel"), bytearray(b"lo")]
    iov = parts
    msg = Msghdr(dest, iov)
    assert one(ring, cqe, io_uring_prep_sendmsg, tx.fileno(), msg) == 5

    came_from = Sockaddr()
    got = [bytearray(16)]
    into = got
    rmsg = Msghdr(came_from, into)
    assert one(ring, cqe, io_uring_prep_recvmsg, rx.fileno(), rmsg) == 5
    assert bytes(got[0][:5]) == b"hello"
    assert (came_from.ip, came_from.port) == ("127.0.0.1", tx.getsockname()[1])
    assert rmsg.namelen == 16


def test_sendmsg_temporary_objects_survive(ring, cqe, udp):
    rx, tx = udp
    keep = [bytearray(b"temp")]
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_sendmsg(sqe, tx.fileno(), Msghdr(Sockaddr(AF_INET, "127.0.0.1", rx.getsockname()[1]), keep))
    junk = [Msghdr() for _ in range(100)]  # reuses the freed memory
    del junk
    sqe.user_data = 1
    assert io_uring_submit(ring) == 1
    assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
    assert cqe[0].res == 4
    io_uring_cqe_seen(ring, cqe[0])
    assert rx.recv(8) == b"temp"


def test_sendmsg_zc(ring, cqe, udp):
    rx, tx = udp
    src = [bytearray(b"zc!")]
    msg = Msghdr(Sockaddr(AF_INET, "127.0.0.1", rx.getsockname()[1]), src)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_sendmsg_zc(sqe, tx.fileno(), msg)
    assert io_uring_submit(ring) == 1
    while True:  # the result, then the notification that the buffer is free
        assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
        more = cqe[0].flags & IORING_CQE_F_MORE
        try:
            _ = cqe[0].res  # raises if the send failed (`ENOMEM`: no pages to account), instead of `recv` hanging
        finally:
            io_uring_cqe_seen(ring, cqe[0])
        if not more:
            break
    rx.settimeout(2)  # only now: a timeout makes the socket non-blocking
    assert rx.recv(8) == b"zc!"


def test_recvmsg_multishot_with_helpers(ring, cqe, udp):
    rx, tx = udp
    area = bytearray(2 * 256)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_provide_buffers(sqe, area, 2, 1, 0)  # 2 buffers of 256
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    assert cqe[0].res == 0
    io_uring_cqe_seen(ring, cqe[0])

    msg = Msghdr(namelen=16, controllen=0)  # the layout: [header][name 16][control 0][payload]
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_recvmsg_multishot(sqe, rx.fileno(), msg)
    sqe.flags = IOSQE_BUFFER_SELECT
    io_uring_sqe_set_buf_group(sqe, 1)
    sqe.user_data = 7
    assert io_uring_submit(ring) == 1
    tx.sendto(b"multishot!", rx.getsockname())
    assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
    _, flags = cqe[0].res, cqe[0].flags
    io_uring_cqe_seen(ring, cqe[0])
    assert flags & IORING_CQE_F_BUFFER
    bid = flags >> IORING_CQE_BUFFER_SHIFT
    buf = memoryview(area)[bid * 256 : (bid + 1) * 256]

    out = io_uring_recvmsg_validate(buf, msg)
    assert out.namelen == 16
    assert out.controllen == 0
    assert out.payloadlen == len(b"multishot!")
    assert io_uring_recvmsg_payload(out, msg) == b"multishot!"
    assert io_uring_recvmsg_payload_length(out, 256, msg) == 256 - 16 - 16
    name = io_uring_recvmsg_name(out)
    assert len(name) == 16
    family, port = struct.unpack_from("=HH", name)
    assert family == AF_INET
    assert socket.ntohs(port) == tx.getsockname()[1]
    assert io_uring_recvmsg_cmsg_firsthdr(out, msg) is None  # no control data

    assert one(ring, cqe, io_uring_prep_cancel, 7) == 0
    io_uring_wait_cqe_timeout(ring, cqe, timespec(1))
    io_uring_cq_advance(ring, io_uring_cq_ready(ring))


def test_recvmsg_validate_too_short():
    msg = Msghdr(namelen=16, controllen=0)
    with pytest.raises(ValueError):
        io_uring_recvmsg_validate(bytearray(8), msg)  # not even the header
    with pytest.raises(ValueError):
        io_uring_recvmsg_validate(bytearray(20), msg)  # header (16) + name (16) do not fit


def test_cmsg_walk_over_a_built_buffer():
    # [header][name][cmsg: SCM_RIGHTS with one int][payload]: what the kernel puts into a provided buffer
    name = bytes(16)
    cmsg = struct.pack("=QII", struct.calcsize("=QII") + 4, SOL_SOCKET, 1) + struct.pack("=i", 7) + bytes(4)
    header = struct.pack("=IIII", len(name), len(cmsg), 3, 0)
    buf = bytearray(header + name + cmsg + b"abc")
    msg = Msghdr(namelen=len(name), controllen=len(cmsg))
    out = io_uring_recvmsg_validate(buf, msg)
    first = io_uring_recvmsg_cmsg_firsthdr(out, msg)
    assert first
    assert (first.level, first.type) == (SOL_SOCKET, 1)
    assert first.len == struct.calcsize("=QII") + 4
    assert first.data == struct.pack("=i", 7)
    assert io_uring_recvmsg_cmsg_nexthdr(out, msg, first) is None
    assert io_uring_recvmsg_payload(out, msg) == b"abc"
    assert out.flags == 0


def test_cmsg_walk_two_messages():
    # [header][name][cmsg 1: level 1, type 2][cmsg 2: level 3, type 4][payload], `MSG_CTRUNC` in the flags
    name = bytes(16)
    one = struct.pack("=QII", struct.calcsize("=QII") + 4, 1, 2) + struct.pack("=i", 5) + bytes(4)
    two = struct.pack("=QII", struct.calcsize("=QII") + 4, 3, 4) + struct.pack("=i", 6) + bytes(4)
    header = struct.pack("=IIII", len(name), len(one + two), 2, socket.MSG_CTRUNC)
    buf = bytearray(header + name + one + two + b"hi")
    msg = Msghdr(namelen=len(name), controllen=len(one + two))
    out = io_uring_recvmsg_validate(buf, msg)
    assert out.flags == socket.MSG_CTRUNC
    first = io_uring_recvmsg_cmsg_firsthdr(out, msg)
    second = io_uring_recvmsg_cmsg_nexthdr(out, msg, first)
    assert (second.level, second.type, second.data) == (3, 4, struct.pack("=i", 6))
    assert io_uring_recvmsg_cmsg_nexthdr(out, msg, second) is None
    assert io_uring_recvmsg_payload(out, msg) == b"hi"


def test_epoll_event_fields():
    ev = EpollEvent(events=select.EPOLLIN, data=123)
    assert (ev.events, ev.data) == (select.EPOLLIN, 123)
    ev.events = select.EPOLLOUT
    ev.data = 5
    assert (ev.events, ev.data) == (select.EPOLLOUT, 5)
    assert len(ev) == 1
    many = EpollEvent(no=4)
    assert len(many) == 4
    many[2].data = 77
    assert many[2].data == 77 and many[0].data == 0
    with pytest.raises(IndexError):
        many[4]
    with pytest.raises(IndexError):
        many[2][0]
    with pytest.raises(ValueError):
        EpollEvent(no=0)
    with pytest.raises(ValueError):
        EpollEvent(no=2, data=1)


def test_epoll_ctl_wait(ring, cqe):
    ep = select.epoll()
    r, w = os.pipe()
    try:
        ev = EpollEvent(events=select.EPOLLIN, data=r)
        assert one(ring, cqe, io_uring_prep_epoll_ctl, ep.fileno(), r, EPOLL_CTL_ADD, ev) == 0
        assert ep.poll(0) == []
        os.write(w, b"x")
        ready = EpollEvent(no=4)
        assert one(ring, cqe, io_uring_prep_epoll_wait, ep.fileno(), ready, 4) == 1
        assert (ready[0].events & select.EPOLLIN, ready[0].data) == (select.EPOLLIN, r)
        with pytest.raises(ValueError):  # more than the array holds
            io_uring_prep_epoll_wait(Sqe(), ep.fileno(), ready, 5)
        with pytest.raises(ValueError):
            io_uring_prep_epoll_wait(Sqe(), ep.fileno(), ready[0], 1)
    finally:
        ep.close()
        os.close(r)
        os.close(w)


def test_sendmsg_zc_fixed(ring, cqe, udp):
    rx, tx = udp
    area = bytearray(b"fixed-zc")
    assert io_uring_register_buffers(ring, [area]) == 0
    try:
        msg = Msghdr(Sockaddr(AF_INET, "127.0.0.1", rx.getsockname()[1]), [area])
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_sendmsg_zc_fixed(sqe, tx.fileno(), msg, 0)
        assert io_uring_submit(ring) == 1
        while True:
            assert io_uring_wait_cqe_timeout(ring, cqe, timespec(2)) == 0
            more = cqe[0].flags & IORING_CQE_F_MORE
            try:  # registered buffers for vectored ops came with `IORING_OP_READV_FIXED` (6.15)
                kernel.res(cqe[0], "IORING_OP_READV_FIXED", name=FIXED_ZC)
            finally:
                io_uring_cqe_seen(ring, cqe[0])
            if not more:
                break
        assert rx.recv(16) == b"fixed-zc"
    finally:
        io_uring_unregister_buffers(ring)
