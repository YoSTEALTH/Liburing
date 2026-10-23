"""Vectored I/O takes lists of buffers (`Iovec` is gone): checked, held (locked) until the completion."""

import gc
import os
import weakref

import pytest

import liburing as u


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


def test_list_checks(ring):
    sqe = u.io_uring_get_sqe(ring)
    with pytest.raises(ValueError):
        u.io_uring_prep_readv(sqe, 0, [])
    with pytest.raises(ValueError):
        u.io_uring_prep_writev(sqe, 0, [b"x"] * (u.IOV_MAX + 1))
    with pytest.raises(TypeError):  # the kernel writes into them: `bytes` refused
        u.io_uring_prep_readv(sqe, 0, [bytearray(1), b"x"])
    with pytest.raises(TypeError):
        u.io_uring_prep_writev(sqe, 0, [b"x", 1])
    with pytest.raises(TypeError):
        u.io_uring_register_buffers(ring, [b"x"])


def test_buffers_held_until_completion(ring, cqe, tmp_dir):
    fd = os.open(tmp_dir / "v.bin", os.O_RDWR | os.O_CREAT, 0o600)
    try:
        os.write(fd, b"hello world")
        bufs = [Buf(5), Buf(6)]
        refs = [weakref.ref(b) for b in bufs]
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_readv(sqe, fd, bufs, 0)
        sqe.user_data = 1
        with pytest.raises(BufferError):  # locked from the prep on
            bufs[0].extend(b"x")
        first = bufs[0]
        del bufs  # only the request holds them (and `first`)
        assert u.io_uring_submit_and_wait(ring, 1) == 1
        gc.collect()
        assert refs[1]() is not None
        u.io_uring_wait_cqe(ring, cqe)
        assert (cqe[0].user_data, cqe[0].res) == (1, 11)
        u.io_uring_cqe_seen(ring, cqe[0])
        gc.collect()
        assert refs[1]() is None
        assert first == b"hello"
        first.extend(b"!")  # released
    finally:
        os.close(fd)


def test_registered_buffers_held(ring):
    buf = Buf(4096)
    ref = weakref.ref(buf)
    assert u.io_uring_register_buffers(ring, [buf]) == 0
    with pytest.raises(BufferError):  # the kernel pinned it
        buf.extend(b"x")
    del buf
    gc.collect()
    assert ref() is not None
    assert u.io_uring_unregister_buffers(ring) == 0
    gc.collect()
    assert ref() is None


def test_msghdr_holds_and_checks_writable(ring, cqe):
    data, control = Buf(b"hi"), Buf(16)
    refs = weakref.ref(data), weakref.ref(control)
    msg = u.Msghdr(iov=[data], control=control)
    with pytest.raises(BufferError):
        data.extend(b"x")
    with pytest.raises(BufferError):
        control.extend(b"x")
    del data, control
    gc.collect()
    assert refs[0]() is not None and refs[1]() is not None
    del msg
    gc.collect()
    assert refs[0]() is None and refs[1]() is None
    sqe = u.io_uring_get_sqe(ring)
    with pytest.raises(TypeError):  # a receive would write into a `bytes`
        u.io_uring_prep_recvmsg(sqe, 0, u.Msghdr(iov=[b"read-only"]))
    u.io_uring_prep_sendmsg(sqe, 0, u.Msghdr(iov=[b"fine to send"]))
