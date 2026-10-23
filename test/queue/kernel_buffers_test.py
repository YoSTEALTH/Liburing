"""Buffers the kernel keeps past one request: a buffer ring's buffers (held by the ring's `BufRing` until it is
freed or the ring exits) and provided buffers (held by the ring until its exit)."""

import gc
import mmap
import os
import weakref

import pytest

import liburing as u


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


def test_buf_ring_holds_buffers(ring):
    br = u.io_uring_setup_buf_ring(ring, 4, 7, 0)
    mask = u.io_uring_buf_ring_mask(4)
    first, second = Buf(16), Buf(16)
    refs = weakref.ref(first), weakref.ref(second)
    u.io_uring_buf_ring_add(br, first, 0, mask, 0)
    u.io_uring_buf_ring_advance(br, 1)
    with pytest.raises(BufferError):  # locked: the kernel may fill it
        first.extend(b"x")
    with pytest.raises(TypeError):  # the kernel writes into it
        u.io_uring_buf_ring_add(br, b"read-only", 1, mask, 0)
    del first, br  # the ring still holds the `BufRing`, which holds the buffer
    gc.collect()
    assert refs[0]() is not None
    u.io_uring_unregister_buf_ring(ring, 7)
    gc.collect()
    assert refs[0]() is None  # released with the buffer ring


def test_buf_ring_readd_replaces(ring):
    br = u.io_uring_setup_buf_ring(ring, 4, 8, 0)
    mask = u.io_uring_buf_ring_mask(4)
    first, second = Buf(16), Buf(16)
    refs = weakref.ref(first), weakref.ref(second)
    u.io_uring_buf_ring_add(br, first, 3, mask, 0)
    u.io_uring_buf_ring_add(br, second, 3, mask, 0)  # the same id: replaces `first`
    del first, second
    gc.collect()
    assert refs[0]() is None and refs[1]() is not None
    assert u.io_uring_free_buf_ring(ring, br, 4, 8) == 0
    del br
    gc.collect()
    assert refs[1]() is None


def test_buf_ring_released_at_exit():
    ring = u.Ring()
    u.io_uring_queue_init(4, ring)
    br = u.io_uring_setup_buf_ring(ring, 2, 1, 0)
    buf = Buf(8)
    ref = weakref.ref(buf)
    u.io_uring_buf_ring_add(br, buf, 0, u.io_uring_buf_ring_mask(2), 0)
    del buf, br
    gc.collect()
    assert ref() is not None
    u.io_uring_queue_exit(ring)
    gc.collect()
    assert ref() is None


def test_provided_buffers_held_until_exit(cqe):
    ring = u.Ring()
    u.io_uring_queue_init(4, ring)
    area = Buf(64)
    ref = weakref.ref(area)
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_provide_buffers(sqe, area, 4, 1, 0)
    with pytest.raises(BufferError):
        area.extend(b"x")
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_provide_buffers(sqe, memoryview(area)[16:32], 1, 1, 1)  # a part again: nothing more held
    assert u.io_uring_submit_and_wait(ring, 2) == 2
    u.io_uring_peek_cqe(ring, cqe)
    u.io_uring_cq_advance(ring, 2)
    del area
    gc.collect()
    assert ref() is not None
    u.io_uring_queue_exit(ring)
    gc.collect()
    assert ref() is None


def test_provide_buffers_needs_ring_sqe():
    with pytest.raises(TypeError):
        u.io_uring_prep_provide_buffers(u.Sqe(), bytearray(16), 1, 1, 0)


# `io_uring_clone_buffers`: the kernel shares a ring's registered buffers with another ring, so each ring holds
# them until its own unregister / exit.


def new_ring():
    ring = u.Ring()
    u.io_uring_queue_init(4, ring)
    return ring


def released(ref):
    gc.collect()
    return ref() is None


@pytest.mark.parametrize('first', ['src', 'dst'])
def test_clone_holds_until_both_unregister(first):
    src, dst = new_ring(), new_ring()
    try:
        buf = Buf(4096)
        ref = weakref.ref(buf)
        assert u.io_uring_register_buffers(src, [buf]) == 0
        assert u.io_uring_clone_buffers(dst, src) == 0
        rings = (src, dst) if first == 'src' else (dst, src)
        assert u.io_uring_unregister_buffers(rings[0]) == 0
        with pytest.raises(BufferError):  # the other ring still uses it
            buf.extend(b'x')
        del buf
        assert not released(ref)
        assert u.io_uring_unregister_buffers(rings[1]) == 0
        assert released(ref)
    finally:
        u.io_uring_queue_exit(src)
        u.io_uring_queue_exit(dst)


def test_clone_held_until_exit_and_gc():
    src, dst = new_ring(), new_ring()
    buf = Buf(4096)
    ref = weakref.ref(buf)
    u.io_uring_register_buffers(src, [buf])
    u.io_uring_clone_buffers(dst, src)
    del buf
    u.io_uring_queue_exit(src)
    assert not released(ref)
    del dst  # collected without `io_uring_queue_exit`: `__del__` releases its share
    assert released(ref)


def small_pages():
    """A page of its own, never in a transparent huge page: a partial clone of one of two buffers that share a
    huge page, then the source's unregister, then the destination's, unaccounts that huge page twice (kernels
    7.2.11 and 7.3.0: the user's locked memory count goes 512 pages below 0, and small registrations fail with
    `ENOMEM` until a reboot)."""
    m = mmap.mmap(-1, mmap.PAGESIZE)
    m.madvise(mmap.MADV_NOHUGEPAGE)
    return m


def test_clone_offset_holds_all(tmp_dir):
    src, dst = new_ring(), new_ring()
    try:
        a, b = small_pages(), small_pages()
        u.io_uring_register_buffers(src, [a, b])
        assert u.io_uring_clone_buffers_offset(dst, src, 0, 1, 1) == 0  # only `b`: `dst` holds both
        u.io_uring_unregister_buffers(src)
        for m in (a, b):
            with pytest.raises(BufferError):  # held by `dst`
                m.close()
        # `b` is `dst`'s buffer 0: a fixed read through `dst` lands in it
        path = tmp_dir / 'clone'
        path.write_bytes(b'cloned!!')
        fd = os.open(path, os.O_RDONLY)
        try:
            sqe = u.io_uring_get_sqe(dst)
            u.io_uring_prep_read_fixed(sqe, fd, memoryview(b)[:8], 0)
            cqe = u.Cqe()
            assert u.io_uring_submit_and_wait(dst, 1) == 1
            u.io_uring_peek_cqe(dst, cqe)
            assert cqe[0].res == 8
            u.io_uring_cqe_seen(dst, cqe[0])
        finally:
            os.close(fd)
        assert b[:8] == b'cloned!!'
        u.io_uring_unregister_buffers(dst)
        a.close()  # released
        b.close()
    finally:
        u.io_uring_queue_exit(src)
        u.io_uring_queue_exit(dst)


def test_clone_of_clone():
    a, b, c = new_ring(), new_ring(), new_ring()
    try:
        buf = Buf(4096)
        ref = weakref.ref(buf)
        u.io_uring_register_buffers(a, [buf])
        u.io_uring_clone_buffers(b, a)
        u.io_uring_clone_buffers(c, b)
        del buf
        u.io_uring_unregister_buffers(a)
        u.io_uring_unregister_buffers(b)
        assert not released(ref)
        u.io_uring_unregister_buffers(c)
        assert released(ref)
    finally:
        for ring in (a, b, c):
            u.io_uring_queue_exit(ring)


def test_failed_clone_holds_nothing():
    src, dst = new_ring(), new_ring()
    try:
        buf, other = Buf(4096), Buf(4096)
        ref = weakref.ref(buf)
        u.io_uring_register_buffers(src, [buf])
        u.io_uring_register_buffers(dst, [other])
        with pytest.raises(OSError):  # `dst` has buffers: needs `IORING_REGISTER_DST_REPLACE`
            u.io_uring_clone_buffers(dst, src)
        del buf
        u.io_uring_unregister_buffers(src)
        assert released(ref)
    finally:
        u.io_uring_queue_exit(src)
        u.io_uring_queue_exit(dst)
