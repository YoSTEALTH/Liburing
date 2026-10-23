"""`Sqe(ring)`: one object for the ring's lifetime; each prep takes the ring's next free entry."""

import gc
import socket
import sys
import threading
import weakref

import pytest

import liburing as u


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


@pytest.fixture
def small():
    """A ring with 2 submission entries."""
    ring = u.Ring()
    u.io_uring_queue_init(2, ring)
    yield ring
    u.io_uring_queue_exit(ring)


def reap(ring, cqe, n):
    got = []
    for _ in range(n):
        assert u.io_uring_wait_cqe(ring, cqe) == 0
        got.append((cqe[0].user_data, cqe[0].res))
        u.io_uring_cqe_seen(ring, cqe[0])
    return sorted(got)


def test_preps_take_next_entries(ring, cqe):
    sqe = u.Sqe(ring)
    assert u.io_uring_prep_nop(sqe) is True
    sqe.user_data = 1
    assert u.io_uring_prep_nop(sqe) is True
    sqe.user_data = 2
    assert u.io_uring_sq_ready(ring) == 2
    assert u.io_uring_submit(ring) == 2
    assert reap(ring, cqe, 2) == [(1, 0), (2, 0)]


def test_properties_act_on_last_prep(ring, cqe):
    sqe = u.Sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.user_data = 1
    u.io_uring_prep_nop(sqe)
    u.io_uring_sqe_set_data64(sqe, 2)
    sqe.flags = u.IOSQE_ASYNC
    assert (sqe.user_data, sqe.flags, sqe.opcode) == (2, u.IOSQE_ASYNC, u.io_uring_op.IORING_OP_NOP)
    assert u.io_uring_submit(ring) == 2
    assert reap(ring, cqe, 2) == [(1, 0), (2, 0)]


def test_user_data_starts_at_zero(small, cqe):
    sqe = u.Sqe(small)
    for i in range(4):  # 2 entries: every slot is used twice
        u.io_uring_prep_nop(sqe)
        assert sqe.user_data == 0
        sqe.user_data = 100 + i
        assert u.io_uring_submit(small) == 1
        assert reap(small, cqe, 1) == [(100 + i, 0)]


def test_full_queue_returns_false(small, cqe):
    sqe = u.Sqe(small)
    assert u.io_uring_prep_nop(sqe) is True
    sqe.user_data = 1
    assert u.io_uring_prep_nop(sqe) is True
    sqe.user_data = 2
    assert u.io_uring_prep_nop(sqe) is False
    with pytest.raises(RuntimeError, match='no entry'):
        sqe.user_data = 3  # no stray write into the last entry
    with pytest.raises(RuntimeError, match='no entry'):
        u.io_uring_sqe_set_flags(sqe, 0)
    assert u.io_uring_submit(small) == 2
    assert u.io_uring_prep_nop(sqe) is True
    sqe.user_data = 3
    assert u.io_uring_submit(small) == 1
    assert reap(small, cqe, 3) == [(1, 0), (2, 0), (3, 0)]


def test_full_queue_releases_buffer(small):
    sqe = u.Sqe(small)
    u.io_uring_prep_nop(sqe)
    u.io_uring_prep_nop(sqe)
    buf = bytearray(4)
    assert u.io_uring_prep_read(sqe, -1, buf) is False
    buf.extend(b'more')  # not held: no `BufferError`


def test_no_entry_before_first_prep(ring):
    sqe = u.Sqe(ring)
    with pytest.raises(RuntimeError, match='no entry'):
        _ = sqe.user_data
    with pytest.raises(RuntimeError, match='no entry'):
        sqe.flags = 0


def test_failed_prep_gives_entry_back(ring, cqe):
    sqe = u.Sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.user_data = 1
    with pytest.raises(ValueError):
        u.io_uring_prep_msg_ring(sqe, -1, 0, 1 << 63)  # `data` with the message bit: refused after the slot
    with pytest.raises(RuntimeError, match='no entry'):
        _ = sqe.user_data
    assert u.io_uring_sq_ready(ring) == 1
    assert u.io_uring_submit(ring) == 1
    assert reap(ring, cqe, 1) == [(1, 0)]


def test_failed_prep_releases_hold(ring):
    sqe = u.Sqe(ring)
    events = u.EpollEvent(1)
    count = sys.getrefcount(events)
    with pytest.raises(ValueError):
        u.io_uring_prep_epoll_wait(sqe, -1, events, 2)  # `maxevents` > `EpollEvent(1)`
    assert sys.getrefcount(events) == count
    assert u.io_uring_sq_ready(ring) == 0


def test_holds_buffer_until_completion(ring, cqe):
    a, b = socket.socketpair()
    try:
        sqe = u.Sqe(ring)
        buf = Buf(5)
        ref = weakref.ref(buf)
        assert u.io_uring_prep_recv(sqe, a.fileno(), buf)
        sqe.user_data = 7
        del buf
        assert u.io_uring_submit(ring) == 1
        gc.collect()
        assert ref() is not None
        b.send(b'hello')
        assert reap(ring, cqe, 1) == [(7, 5)]
        assert ref() is None
    finally:
        a.close()
        b.close()


def test_no_index_len_or_put_sqe(ring):
    sqe = u.Sqe(ring)
    assert sqe
    with pytest.raises(TypeError):
        sqe[0]
    with pytest.raises(TypeError):
        len(sqe)
    with pytest.raises(TypeError):
        u.put_sqe(ring, sqe)


def test_bad_argument():
    with pytest.raises(TypeError):
        u.Sqe('x')
    assert len(u.Sqe(None)) == 1
    assert len(u.Sqe(3)) == 3


def test_ring_not_initialized():
    ring = u.Ring()
    sqe = u.Sqe(ring)
    with pytest.raises(RuntimeError):
        u.io_uring_prep_nop(sqe)


def test_keeps_ring_alive():
    ring = u.Ring()
    u.io_uring_queue_init(2, ring)
    count = sys.getrefcount(ring)
    sqe = u.Sqe(ring)
    assert sys.getrefcount(ring) == count + 1
    u.io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        u.io_uring_prep_nop(sqe)
    del sqe
    assert sys.getrefcount(ring) == count


def test_wide_prep_needs_sqe128(ring):
    sqe = u.Sqe(ring)
    with pytest.raises(ValueError, match='128'):
        u.io_uring_prep_nop128(sqe)
    assert u.io_uring_sq_ready(ring) == 0


def test_other_thread(ring):
    sqe = u.Sqe(ring)
    errors = []

    def run():
        try:
            u.io_uring_prep_nop(sqe)
        except RuntimeError as e:
            errors.append(e)

    t = threading.Thread(target=run)
    t.start()
    t.join()
    assert len(errors) == 1
    assert u.io_uring_sq_ready(ring) == 0


def test_other_sqes_return_true(ring):
    assert u.io_uring_prep_nop(u.io_uring_get_sqe(ring)) is True
    tmpl = u.Sqe(2)
    assert u.io_uring_prep_nop(tmpl[1]) is True
    assert u.io_uring_prep_nop(tmpl) is True


def test_sqe_ring_example(capsys):
    # `example/sqe_ring.py`: the README's `Sqe(ring)` example
    import pathlib
    import runpy

    path = pathlib.Path(__file__).parents[2] / "example" / "sqe_ring.py"
    runpy.run_path(str(path), run_name="__main__")
    assert capsys.readouterr().out == "user_data: [0, 1, 2]\n"
