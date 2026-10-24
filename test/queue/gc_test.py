"""Garbage collection: a cycle through what a `Ring` or an `Sqe` template holds (a buffer that refers back to it) is
collected, and the ring exits first, so no request in flight is left writing into a freed buffer."""

import gc
import os
import weakref
import pytest
from liburing import *


class Buf(bytearray):
    """A `bytearray` that can refer back to the ring (an attribute) and a `weakref` can watch."""


def new_ring():
    ring = Ring()
    io_uring_queue_init(8, ring)
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
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, r, buf)  # waits for data: in flight
        assert io_uring_submit(ring) == 1
        return weakref.ref(buf)

    assert collected(make())
    os.write(w, b"later")
    assert os.read(r, 8) == b"later"  # the read was cancelled when the ring exited: nothing took the data


def test_cycle_with_pending_prep():
    def make():
        ring, buf = new_ring(), Buf(8)
        buf.ring = ring  # held by the SQ slot's pending hold (prepped, not submitted)
        io_uring_prep_read(io_uring_get_sqe(ring), -1, buf)
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_registered_buffer():
    def make():
        ring, buf = new_ring(), Buf(4096)
        buf.ring = ring
        assert io_uring_register_buffers(ring, [buf]) == 0
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_provided_buffers(cqe):
    def make():
        ring, area = new_ring(), Buf(2 * 64)
        area.ring = ring
        io_uring_prep_provide_buffers(io_uring_get_sqe(ring), area, 64, 2, 1)
        assert io_uring_submit_and_wait(ring, 1) == 1
        return weakref.ref(area)

    assert collected(make())


def test_cycle_through_template():
    def make():
        tmpl, buf = Sqe(), Buf(8)
        buf.tmpl = tmpl  # tmpl -> its entry's hold -> buf -> tmpl
        io_uring_prep_read(tmpl, -1, buf)
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_with_template_copy_in_flight(pipe):
    r, w = pipe

    def make():
        ring, tmpl, buf = new_ring(), Sqe(), Buf(8)
        buf.refs = (ring, tmpl)  # ring -> the copy's hold -> tmpl -> buf -> ring
        io_uring_prep_read(tmpl, r, buf)
        assert put_sqe(ring, tmpl)
        assert io_uring_submit(ring) == 1  # in flight: the template keeps its hold until the ring drains
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
    assert io_uring_register_buffers(src, [buf]) == 0
    assert io_uring_clone_buffers(dst, src) == 0
    del buf
    gc.collect()
    assert ref() is not None
    io_uring_queue_exit(dst)  # `src` alone holds it again: visited, the cycle can go
    del src
    assert collected(ref)


def test_cycle_through_msghdr():
    def make():
        buf = Buf(8)
        msg = Msghdr(iov=[buf])
        buf.msg = msg  # msg -> its `Vec`'s view -> buf -> msg
        return weakref.ref(buf)

    assert collected(make())


def test_cycle_through_msghdr_control():
    def make():
        control = Buf(32)
        msg = Msghdr(control=control)
        control.msg = msg
        return weakref.ref(control)

    assert collected(make())


def test_cycle_through_buf_ring():
    def make():
        ring, buf = new_ring(), Buf(64)
        br = io_uring_setup_buf_ring(ring, 4, 1, 0)
        io_uring_buf_ring_add(br, buf, 0, io_uring_buf_ring_mask(4))
        io_uring_buf_ring_advance(br, 1)
        buf.ring = ring  # ring -> its `BufRing` -> buf's view -> buf -> ring
        return weakref.ref(buf)

    assert collected(make())
