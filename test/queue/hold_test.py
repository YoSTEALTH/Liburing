"""What a request holds until its completion: its buffer (locked: no resize) and objects (paths, `Sockaddr`,
`Timespec`, ...), so a temporary or a `del` can not free memory the kernel still reads or writes."""

import gc
import os
import socket
import sys
import weakref

import pytest

import liburing as u


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


def recv(ring, fd, buf, user_data=1, flags=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_recv(sqe, fd, buf)
    sqe.user_data = user_data
    sqe.flags = flags
    return sqe


def reap(ring, cqe):
    assert u.io_uring_wait_cqe(ring, cqe) == 0
    entry = cqe[0]
    try:
        return entry.user_data, entry.res
    finally:
        u.io_uring_cqe_seen(ring, entry)


@pytest.fixture
def pair():
    a, b = socket.socketpair()
    yield a, b
    a.close()
    b.close()


def test_temporary_buffer_lives_until_completion(ring, cqe, pair):
    a, b = pair
    buf = Buf(5)
    ref = weakref.ref(buf)
    recv(ring, a.fileno(), buf)
    del buf  # only the request holds it now
    assert u.io_uring_submit(ring) == 1
    gc.collect()
    assert ref() is not None
    b.send(b"hello")
    assert reap(ring, cqe) == (1, 5)
    assert ref() is None  # released with the completion


def test_held_buffer_can_not_resize(ring, cqe, pair):
    a, b = pair
    buf = bytearray(5)
    recv(ring, a.fileno(), buf)
    with pytest.raises(BufferError):
        buf.extend(b"x")  # held from the prep on
    assert u.io_uring_submit(ring) == 1
    with pytest.raises(BufferError):
        buf.extend(b"x")
    b.send(b"hello")
    assert reap(ring, cqe) == (1, 5)
    assert buf == b"hello"
    buf.extend(b"!")  # released
    assert buf == b"hello!"


def test_read_write_hold(ring, cqe):
    r, w = os.pipe()
    try:
        data = Buf(b"abc")
        out = Buf(3)
        refs = weakref.ref(data), weakref.ref(out)
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_write(sqe, w, data)
        sqe.user_data = 1
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_read(sqe, r, out)
        sqe.user_data = 2
        del data, out
        assert u.io_uring_submit_and_wait(ring, 2) == 2
        assert sorted([reap(ring, cqe), reap(ring, cqe)]) == [(1, 3), (2, 3)]
        assert refs[0]() is None and refs[1]() is None
    finally:
        os.close(r)
        os.close(w)


def test_object_held_until_completion(ring, cqe):
    ts = u.timespec(0.001)
    before = sys.getrefcount(ts)
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_timeout(sqe, ts, 0)
    sqe.user_data = 3
    assert sys.getrefcount(ts) == before + 1  # its slot's, from the prep
    assert u.io_uring_submit(ring) == 1
    assert sys.getrefcount(ts) == before + 1  # its entry's, until the completion
    with pytest.raises(OSError):  # ETIME
        reap(ring, cqe)
    assert sys.getrefcount(ts) == before


def test_reprep_replaces_hold(ring, cqe, pair):
    a, _ = pair
    first, second = Buf(4), Buf(4)
    refs = weakref.ref(first), weakref.ref(second)
    sqe = recv(ring, a.fileno(), first)
    u.io_uring_prep_nop(sqe)  # holds nothing: `first` stays held until this request completes
    u.io_uring_prep_recv(sqe, a.fileno(), second)  # replaces it
    u.io_uring_prep_nop(sqe)
    del first, second
    gc.collect()
    assert refs[0]() is None and refs[1]() is not None
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert reap(ring, cqe) == (1, 0)
    assert refs[1]() is None


def test_template_holds_buffer(ring, cqe, pair):
    a, b = pair
    buf = Buf(5)
    ref = weakref.ref(buf)
    tmpl = u.Sqe()
    u.io_uring_prep_recv(tmpl, a.fileno(), buf)
    tmpl.user_data = 4
    del buf
    gc.collect()
    assert ref() is not None  # the template's, for its lifetime
    assert u.put_sqe(ring, tmpl)
    tref = weakref.ref(tmpl) if hasattr(tmpl, "__weakref__") else None
    del tmpl  # the copy in flight holds the template
    gc.collect()
    assert ref() is not None
    assert u.io_uring_submit(ring) == 1
    b.send(b"hello")
    assert reap(ring, cqe) == (4, 5)
    gc.collect()
    assert ref() is None
    assert tref is None or tref() is None


def test_skip_success_with_hold_refused(ring, cqe, pair):
    a, b = pair
    sqe = recv(ring, a.fileno(), bytearray(5), flags=u.IOSQE_CQE_SKIP_SUCCESS)
    with pytest.raises(ValueError):
        u.io_uring_submit(ring)
    assert u.io_uring_sq_ready(ring) == 1  # refused: nothing sent
    sqe.flags = 0
    assert u.io_uring_submit(ring) == 1
    b.send(b"hello")
    assert reap(ring, cqe) == (1, 5)


def test_skip_success_without_hold(ring, cqe):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.flags = u.IOSQE_CQE_SKIP_SUCCESS
    assert u.io_uring_submit(ring) == 1


@pytest.mark.parametrize("close", ["exit", "del"])
def test_close_with_request_in_flight(cqe, close):
    a, b = socket.socketpair()
    try:
        ring = u.Ring()
        u.io_uring_queue_init(8, ring)
        buf = Buf(5)
        ref = weakref.ref(buf)
        recv(ring, a.fileno(), buf)
        assert u.io_uring_submit(ring) == 1
        pending = Buf(5)  # prepared, never submitted
        pref = weakref.ref(pending)
        recv(ring, a.fileno(), pending, user_data=2)
        del buf, pending
        if close == "exit":
            u.io_uring_queue_exit(ring)  # cancels the recv, waits for it, then releases
        else:
            del ring
        gc.collect()
        assert ref() is None and pref() is None
        b.send(b"hello")  # no one reads it
    finally:
        a.close()
        b.close()


def test_accept_holds_sockaddr(ring, cqe):
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    try:
        addr = u.Sockaddr(socket.AF_INET, "0.0.0.0", 0)
        before = sys.getrefcount(addr)
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_accept(sqe, listener.fileno(), addr)
        sqe.user_data = 5
        assert u.io_uring_submit(ring) == 1
        assert sys.getrefcount(addr) == before + 1  # written at the completion
        client = socket.create_connection(listener.getsockname())
        user_data, fd = reap(ring, cqe)
        assert user_data == 5 and fd > 0
        os.close(fd)
        client.close()
        assert sys.getrefcount(addr) == before
    finally:
        listener.close()


def test_bytes_held_by_reference(ring, cqe, pair):
    a, b = pair
    data = bytes(bytearray(b"x" * 100 + b"y"))  # made at run time: not a (possibly immortal) constant
    before = sys.getrefcount(data)
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_send(sqe, b.fileno(), data)
    sqe.user_data = 6
    assert sys.getrefcount(data) == before + 1  # immutable: a reference keeps its memory, no view needed
    assert u.io_uring_submit(ring) == 1
    assert reap(ring, cqe) == (6, 101)
    assert sys.getrefcount(data) == before
    assert a.recv(200) == data


def test_template_reprep_with_copy_in_flight(ring, cqe, pair):
    a, b = pair
    first, second = Buf(5), Buf(5)
    refs = weakref.ref(first), weakref.ref(second)
    tmpl = u.Sqe()
    u.io_uring_prep_recv(tmpl, a.fileno(), first)
    tmpl.user_data = 1
    assert u.put_sqe(ring, tmpl)
    assert u.io_uring_submit(ring) == 1  # a copy receives into `first`
    u.io_uring_prep_recv(tmpl, a.fileno(), second)  # re-prep while it is in flight: `first` is retired, not freed
    tmpl.user_data = 2
    del first, second
    gc.collect()
    assert refs[0]() is not None and refs[1]() is not None
    b.send(b"hello")
    assert reap(ring, cqe) == (1, 5)
    assert refs[0]() is None  # the last copy of it completed: the retired hold is released
    assert refs[1]() is not None  # the template's current one
    assert u.put_sqe(ring, tmpl)
    assert u.io_uring_submit(ring) == 1
    b.send(b"world")
    assert reap(ring, cqe) == (2, 5)
    assert bytes(refs[1]()) == b"world"
    del tmpl
    gc.collect()
    assert refs[1]() is None


def test_template_copies_counted(ring, cqe, pair):
    # several copies in flight: the retired hold waits for the last
    a, b = pair
    first = Buf(2)
    ref = weakref.ref(first)
    tmpl = u.Sqe()
    u.io_uring_prep_recv(tmpl, a.fileno(), first)
    for i in range(3):
        tmpl.user_data = i
        assert u.put_sqe(ring, tmpl)
    assert u.io_uring_submit(ring) == 3
    u.io_uring_prep_nop(tmpl)  # holds nothing: `first` stays the template's
    u.io_uring_prep_recv(tmpl, a.fileno(), Buf(2))  # replaces it: retired
    del first
    for n in range(3):
        b.send(b"ab")
        reap(ring, cqe)
        gc.collect()
        assert (ref() is None) == (n == 2)


def test_template_one_thread(ring):
    import threading

    tmpl = u.Sqe()
    u.io_uring_prep_nop(tmpl)
    assert u.put_sqe(ring, tmpl)  # this thread's from now on
    errors = []

    def other():
        r = u.Ring()
        u.io_uring_queue_init(4, r)
        try:
            u.put_sqe(r, tmpl)
        except RuntimeError as e:
            errors.append(e)
        try:
            u.io_uring_prep_recv(tmpl, 0, bytearray(1))
        except RuntimeError as e:
            errors.append(e)
        u.io_uring_queue_exit(r)

    t = threading.Thread(target=other)
    t.start()
    t.join()
    assert len(errors) == 2
    assert u.io_uring_submit(ring) == 1


def test_template_other_thread_unchanged(ring):
    import threading

    tmpl = u.Sqe()
    u.io_uring_prep_nop(tmpl)
    tmpl.user_data = 9
    assert u.put_sqe(ring, tmpl)
    t = threading.Thread(target=lambda: pytest.raises(RuntimeError, u.io_uring_prep_recv, tmpl, 0, bytearray(1)))
    t.start()
    t.join()
    assert tmpl.opcode == u.io_uring_op.IORING_OP_NOP  # refused before the prep wrote anything
    assert u.io_uring_submit(ring) == 1


def test_owned_buffer_released_when_prep_fails(ring, tmp_dir):
    buf = bytearray(4)
    sqe = u.io_uring_get_sqe(ring)
    with pytest.raises(TypeError):  # a later argument: Setu releases the buffer, the prep never runs
        u.io_uring_prep_recv(sqe, 0, buf, "flags")
    with pytest.raises(TypeError):  # the prep's own conversion (`name`) before the hold took it
        u.io_uring_prep_fgetxattr(sqe, 0, 123, buf, 4)
    buf.extend(b"x")  # not locked: no view left behind
    other = u.Ring()
    u.io_uring_queue_init(2, other)
    dead = u.io_uring_get_sqe(other)
    u.io_uring_queue_exit(other)
    with pytest.raises(RuntimeError):  # the ring exited: refused in the hold, the buffer released
        u.io_uring_prep_recv(dead, 0, buf)
    buf.extend(b"y")
    assert len(buf) == 6
