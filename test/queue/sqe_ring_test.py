"""`Sqe(ring)`: one object for the ring's lifetime; each prep takes the ring's next free entry."""

import gc
import mmap
import socket
import sys
import threading
import weakref
import pytest
from liburing import *


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


@pytest.fixture
def small():
    """A ring with 2 submission entries."""
    ring = Ring()
    io_uring_queue_init(2, ring)
    yield ring
    io_uring_queue_exit(ring)


def reap(ring, cqe, n):
    got = []
    for _ in range(n):
        assert io_uring_wait_cqe(ring, cqe) == 0
        got.append((cqe[0].user_data, cqe[0].res))
        io_uring_cqe_seen(ring, cqe[0])
    return sorted(got)


def test_preps_take_next_entries(ring, cqe):
    sqe = Sqe(ring)
    assert io_uring_prep_nop(sqe) is True
    sqe.user_data = 1
    assert io_uring_prep_nop(sqe) is True
    sqe.user_data = 2
    assert io_uring_sq_ready(ring) == 2
    assert io_uring_submit(ring) == 2
    assert reap(ring, cqe, 2) == [(1, 0), (2, 0)]


def test_properties_act_on_last_prep(ring, cqe):
    sqe = Sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 1
    io_uring_prep_nop(sqe)
    io_uring_sqe_set_data64(sqe, 2)
    sqe.flags = IOSQE_ASYNC
    assert (sqe.user_data, sqe.flags, sqe.opcode) == (2, IOSQE_ASYNC, io_uring_op.IORING_OP_NOP)
    assert io_uring_submit(ring) == 2
    assert reap(ring, cqe, 2) == [(1, 0), (2, 0)]


def test_user_data_starts_at_zero(small, cqe):
    sqe = Sqe(small)
    for i in range(4):  # 2 entries: every slot is used twice
        io_uring_prep_nop(sqe)
        assert sqe.user_data == 0
        sqe.user_data = 100 + i
        assert io_uring_submit(small) == 1
        assert reap(small, cqe, 1) == [(100 + i, 0)]


def test_full_queue_returns_false(small, cqe):
    sqe = Sqe(small)
    assert io_uring_prep_nop(sqe) is True
    sqe.user_data = 1
    assert io_uring_prep_nop(sqe) is True
    sqe.user_data = 2
    assert io_uring_prep_nop(sqe) is False
    with pytest.raises(RuntimeError, match='no entry'):
        sqe.user_data = 3  # no stray write into the last entry
    with pytest.raises(RuntimeError, match='no entry'):
        io_uring_sqe_set_flags(sqe, 0)
    assert io_uring_submit(small) == 2
    assert io_uring_prep_nop(sqe) is True
    sqe.user_data = 3
    assert io_uring_submit(small) == 1
    assert reap(small, cqe, 3) == [(1, 0), (2, 0), (3, 0)]


def test_full_queue_releases_buffer(small):
    sqe = Sqe(small)
    io_uring_prep_nop(sqe)
    io_uring_prep_nop(sqe)
    buf = bytearray(4)
    assert io_uring_prep_read(sqe, -1, buf) is False
    buf.extend(b'more')  # not held: no `BufferError`


def test_no_entry_before_first_prep(ring):
    sqe = Sqe(ring)
    with pytest.raises(RuntimeError, match='no entry'):
        _ = sqe.user_data
    with pytest.raises(RuntimeError, match='no entry'):
        sqe.flags = 0


def test_failed_prep_gives_entry_back(ring, cqe):
    sqe = Sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 1
    with pytest.raises(ValueError):
        io_uring_prep_msg_ring(sqe, -1, 0, 1 << 63)  # `data` with the message bit: refused after the slot
    with pytest.raises(RuntimeError, match='no entry'):
        _ = sqe.user_data
    assert io_uring_sq_ready(ring) == 1
    assert io_uring_submit(ring) == 1
    assert reap(ring, cqe, 1) == [(1, 0)]


def test_failed_prep_releases_hold(ring):
    sqe = Sqe(ring)
    events = EpollEvent(1)
    count = sys.getrefcount(events)
    with pytest.raises(ValueError):
        io_uring_prep_epoll_wait(sqe, -1, events, 2)  # `maxevents` > `EpollEvent(1)`
    assert sys.getrefcount(events) == count
    assert io_uring_sq_ready(ring) == 0


class BufferOnce:
    """A buffer the first time only (the argument check), refused when a prep takes its own view."""

    def __init__(self):
        self.calls = 0

    def __buffer__(self, flags):
        self.calls += 1
        if self.calls > 1:
            raise BufferError("only once")
        return memoryview(bytearray(8))


@pytest.fixture(scope="module")
def huge():
    """4 GiB of address space (no memory used): longer than a 32-bit length."""
    flags = mmap.MAP_PRIVATE | mmap.MAP_ANONYMOUS | mmap.MAP_NORESERVE
    return mmap.mmap(-1, 1 << 32, flags=flags)


SOCK_OP = io_uring_socket_op.SOCKET_URING_OP_SETSOCKOPT
# (prep call, the error it raises after taking the entry); `big` is `huge`
FAILS_AFTER_SLOT = {
    "read_fixed": (lambda s, big: io_uring_prep_read_fixed(s, 7, big, 0), OverflowError),
    "write_fixed": (lambda s, big: io_uring_prep_write_fixed(s, 7, big, 0), OverflowError),
    "write": (lambda s, big: io_uring_prep_write(s, 7, big), OverflowError),
    "madvise": (lambda s, big: io_uring_prep_madvise(s, big, mmap.MADV_NORMAL), OverflowError),
    "cmd_sock": (lambda s, big: io_uring_prep_cmd_sock(s, SOCK_OP, 7, SOL_SOCKET, SO_KEEPALIVE, big), OverflowError),
    "setsockopt": (lambda s, big: setsockopt(s, 7, SOL_SOCKET, SO_KEEPALIVE, big), OverflowError),
    "getsockopt": (lambda s, big: getsockopt(s, 7, SOL_SOCKET, SO_KEEPALIVE, big), OverflowError),
    "readv_fixed": (lambda s, big: io_uring_prep_readv_fixed(s, 7, [BufferOnce()], 0), BufferError),
    "writev_fixed": (lambda s, big: io_uring_prep_writev_fixed(s, 7, [BufferOnce()], 0), BufferError),
    "open": (lambda s, big: io_uring_prep_open(s, b"/a"), TypeError),  # a path is `str` or `os.PathLike`
    "open_direct": (lambda s, big: io_uring_prep_open_direct(s, b"/a"), TypeError),
    "statx": (lambda s, big: io_uring_prep_statx(s, Statx(), b"/a"), TypeError),
    "openat2": (lambda s, big: io_uring_prep_openat2(s, b"/a", OpenHow()), TypeError),
    "openat2_direct": (lambda s, big: io_uring_prep_openat2_direct(s, b"/a", OpenHow()), TypeError),
    "rename": (lambda s, big: io_uring_prep_rename(s, "/a", b"/b"), TypeError),
    "mkdir": (lambda s, big: io_uring_prep_mkdir(s, b"/a", 0o755), TypeError),
    "symlink": (lambda s, big: io_uring_prep_symlink(s, "/a", b"/b"), TypeError),
    "link": (lambda s, big: io_uring_prep_link(s, "/a", b"/b"), TypeError),
    "getxattr": (lambda s, big: io_uring_prep_getxattr(s, "user.x", bytearray(8), b"/a", 8), TypeError),
    "setxattr": (lambda s, big: io_uring_prep_setxattr(s, "user.x", b"v", b"/a", 0, 1), TypeError),
    "fsetxattr": (lambda s, big: io_uring_prep_fsetxattr(s, 7, b"user.x", b"v", 0, 1), TypeError),
    "pipe_direct": (lambda s, big: io_uring_prep_pipe_direct(s, bytearray(4), 0, 0), ValueError),  # not 2 ints
    "msg_ring_cqe_flags": (lambda s, big: io_uring_prep_msg_ring_cqe_flags(s, 7, 1, 1 << 63, 0, 0), ValueError),
    "msg_ring_fd": (lambda s, big: io_uring_prep_msg_ring_fd(s, 7, 8, 9, 1 << 63), ValueError),
    "msg_ring_fd_alloc": (lambda s, big: io_uring_prep_msg_ring_fd_alloc(s, 7, 8, 1 << 63), ValueError),
    "futex_waitv": (lambda s, big: io_uring_prep_futex_waitv(s, Futex()), ValueError),  # no vector
    "recvmsg_multishot": (lambda s, big: io_uring_prep_recvmsg_multishot(s, 7, Msghdr(Sockaddr(), [b"ro"])), TypeError),
}


@pytest.mark.parametrize("name", FAILS_AFTER_SLOT)
def test_prep_failing_after_slot_gives_entry_back(ring, huge, name):
    call, error = FAILS_AFTER_SLOT[name]
    sqe = Sqe(ring)
    with pytest.raises(error):
        call(sqe, huge)
    assert io_uring_sq_ready(ring) == 0
    with pytest.raises(RuntimeError, match='no entry'):
        _ = sqe.user_data


def test_holds_buffer_until_completion(ring, cqe):
    a, b = socket.socketpair()
    try:
        sqe = Sqe(ring)
        buf = Buf(5)
        ref = weakref.ref(buf)
        assert io_uring_prep_recv(sqe, a.fileno(), buf)
        sqe.user_data = 7
        del buf
        assert io_uring_submit(ring) == 1
        gc.collect()
        assert ref() is not None
        b.send(b'hello')
        assert reap(ring, cqe, 1) == [(7, 5)]
        assert ref() is None
    finally:
        a.close()
        b.close()


def test_no_index_len_or_put_sqe(ring):
    sqe = Sqe(ring)
    assert sqe
    with pytest.raises(TypeError):
        sqe[0]
    with pytest.raises(TypeError):
        len(sqe)
    with pytest.raises(TypeError):
        put_sqe(ring, sqe)


def test_bad_argument():
    with pytest.raises(TypeError):
        Sqe('x')
    assert len(Sqe(None)) == 1
    assert len(Sqe(3)) == 3


def test_ring_not_initialized():
    ring = Ring()
    sqe = Sqe(ring)
    with pytest.raises(RuntimeError):
        io_uring_prep_nop(sqe)


def test_keeps_ring_alive():
    ring = Ring()
    io_uring_queue_init(2, ring)
    count = sys.getrefcount(ring)
    sqe = Sqe(ring)
    assert sys.getrefcount(ring) == count + 1
    io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        io_uring_prep_nop(sqe)
    del sqe
    assert sys.getrefcount(ring) == count


def test_wide_prep_needs_sqe128(ring):
    sqe = Sqe(ring)
    with pytest.raises(ValueError, match='128'):
        io_uring_prep_nop128(sqe)
    assert io_uring_sq_ready(ring) == 0


def test_other_thread(ring):
    sqe = Sqe(ring)
    errors = []

    def run():
        try:
            io_uring_prep_nop(sqe)
        except RuntimeError as e:
            errors.append(e)

    t = threading.Thread(target=run)
    t.start()
    t.join()
    assert len(errors) == 1
    assert io_uring_sq_ready(ring) == 0


def test_other_sqes_return_true(ring):
    assert io_uring_prep_nop(io_uring_get_sqe(ring)) is True
    tmpl = Sqe(2)
    assert io_uring_prep_nop(tmpl[1]) is True
    assert io_uring_prep_nop(tmpl) is True
