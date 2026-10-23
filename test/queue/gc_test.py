"""Garbage collection: a cycle through what a `Ring` or an `Sqe` template holds (a buffer that refers back to it) is
collected, and the ring exits first, so no request in flight is left writing into a freed buffer."""

import gc
import os
import weakref

import pytest

import liburing as u


class Buf(bytearray):
    """A `bytearray` that can refer back to the ring (an attribute) and a `weakref` can watch."""


def new_ring():
    ring = u.Ring()
    u.io_uring_queue_init(8, ring)
    return ring


def collected(ref):
    gc.collect()
    return ref() is None


@pytest.fixture
def pipe():
    r, w = os.pipe()
    yield r, w
    os.close(r)
    os.close(w)


def test_cycle_with_read_in_flight(pipe):
    r, w = pipe

    def make():
        ring, buf = new_ring(), Buf(8)
        buf.ring = ring  # ring -> its table's hold -> buf -> ring
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_read(sqe, r, buf)  # waits for data: in flight
        assert u.io_uring_submit(ring) == 1
        return weakref.ref(buf)

    assert collected(make())
    os.write(w, b"later")
    assert os.read(r, 8) == b"later"  # the read was cancelled when the ring exited: nothing took the data


def test_cycle_with_pending_prep():
    def make():
        ring, buf = new_ring(), Buf(8)
        buf.ring = ring  # held by the SQ slot's pending hold (prepped, not submitted)
        u.io_uring_prep_read(u.io_uring_get_sqe(ring), -1, buf)
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_registered_buffer():
    def make():
        ring, buf = new_ring(), Buf(4096)
        buf.ring = ring
        assert u.io_uring_register_buffers(ring, [buf]) == 0
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_provided_buffers(cqe):
    def make():
        ring, area = new_ring(), Buf(2 * 64)
        area.ring = ring
        u.io_uring_prep_provide_buffers(u.io_uring_get_sqe(ring), area, 64, 2, 1)
        assert u.io_uring_submit_and_wait(ring, 1) == 1
        return weakref.ref(area)

    assert collected(make())


def test_cycle_through_template():
    def make():
        tmpl, buf = u.Sqe(), Buf(8)
        buf.tmpl = tmpl  # tmpl -> its entry's hold -> buf -> tmpl
        u.io_uring_prep_read(tmpl, -1, buf)
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_template_copy_in_flight(pipe):
    r, w = pipe

    def make():
        ring, tmpl, buf = new_ring(), u.Sqe(), Buf(8)
        buf.refs = (ring, tmpl)  # ring -> the copy's hold -> tmpl -> buf -> ring
        u.io_uring_prep_read(tmpl, r, buf)
        assert u.put_sqe(ring, tmpl)
        assert u.io_uring_submit(ring) == 1  # in flight: the template keeps its hold until the ring drains
        return weakref.ref(buf)

    assert collected(make())
    os.write(w, b"later")
    assert os.read(r, 8) == b"later"


def test_shared_registration_not_visited_twice():
    # `io_uring_clone_buffers`: both rings hold the same `Vec`, so neither visits it (the GC must not count its
    # references twice); the cycle through it stays (a leak, not a crash) until a ring lets go of it
    src, dst = new_ring(), new_ring()
    buf = Buf(4096)
    buf.ring = src
    ref = weakref.ref(buf)
    assert u.io_uring_register_buffers(src, [buf]) == 0
    assert u.io_uring_clone_buffers(dst, src) == 0
    del buf
    gc.collect()
    assert ref() is not None
    u.io_uring_queue_exit(dst)  # `src` alone holds it again: visited, the cycle can go
    del src
    assert collected(ref)


def test_cycle_through_msghdr():
    def make():
        buf = Buf(8)
        msg = u.Msghdr(iov=[buf])
        buf.msg = msg  # msg -> its `Vec`'s view -> buf -> msg
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_through_msghdr_control():
    def make():
        control = Buf(32)
        msg = u.Msghdr(control=control)
        control.msg = msg
        return weakref.ref(control)

    assert collected(make())


def test_cycle_through_buf_ring():
    def make():
        ring, buf = new_ring(), Buf(64)
        br = u.io_uring_setup_buf_ring(ring, 4, 1, 0)
        u.io_uring_buf_ring_add(br, buf, 0, u.io_uring_buf_ring_mask(4))
        u.io_uring_buf_ring_advance(br, 1)
        buf.ring = ring  # ring -> its `BufRing` -> buf's view -> buf -> ring
        return weakref.ref(buf)

    assert collected(make())
