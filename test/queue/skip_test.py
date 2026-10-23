"""`IOSQE_CQE_SKIP_SUCCESS` (no completion on success) with the in-flight table: in a link chain the chain's
end releases what the skipped requests hold; a chain may not end on one; alone, one may hold nothing."""

import errno
import gc
import os
import weakref

import pytest

import liburing as u

SKIP = u.IOSQE_CQE_SKIP_SUCCESS


class Buf(bytearray):
    """A `bytearray` a `weakref` can watch."""


def nop(ring, user_data, flags=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    sqe.flags = flags
    return sqe


def write(ring, fd, data, user_data, flags=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_write(sqe, fd, data)
    sqe.user_data = user_data
    sqe.flags = flags
    return sqe


def reap_all(ring, cqe):
    """`(user_data, res or -errno)` of every ready completion, consumed one by one."""
    out = []
    while u.io_uring_cq_ready(ring):
        assert u.io_uring_peek_cqe(ring, cqe) == 0
        entry = cqe[0]
        try:
            res = entry.res
        except OSError as e:
            res = -e.errno
        out.append((entry.user_data, res))
        u.io_uring_cqe_seen(ring, entry)
    return out


@pytest.fixture
def pipe():
    r, w = os.pipe()
    yield r, w
    os.close(r)
    os.close(w)


@pytest.mark.parametrize("link", [u.IOSQE_IO_LINK, u.IOSQE_IO_HARDLINK])
def test_chain_end_releases_skipped(ring, cqe, pipe, link):
    _, w = pipe
    bufs = [Buf(b"a"), Buf(b"bc")]
    refs = [weakref.ref(b) for b in bufs]
    write(ring, w, bufs[0], 1, SKIP | link)
    write(ring, w, bufs[1], 2, SKIP | link)
    nop(ring, 3)  # the chain's end
    del bufs
    assert u.io_uring_submit_and_wait(ring, 1) == 3
    gc.collect()
    assert reap_all(ring, cqe) == [(3, 0)]  # only the end posts
    gc.collect()
    assert [r() for r in refs] == [None, None]  # released with the end's completion


def test_skipped_failure_silences_rest(ring, cqe, pipe):
    # a skipped `IOSQE_IO_LINK` request that fails posts; the kernel cancels the rest without completions
    _, w = pipe
    bufs = [Buf(b"x"), Buf(b"y"), Buf(b"z")]
    refs = [weakref.ref(b) for b in bufs]
    write(ring, -1, bufs[0], 7, SKIP | u.IOSQE_IO_LINK)  # fails: EBADF
    write(ring, w, bufs[1], 8, u.IOSQE_IO_LINK)  # cancelled, silent
    write(ring, w, bufs[2], 9)  # the end: cancelled, silent
    del bufs
    assert u.io_uring_submit_and_wait(ring, 1) == 3
    # in a chain the skipped request has an entry: its failure reports the user's value, not `0`
    assert reap_all(ring, cqe) == [(7, -errno.EBADF)]
    gc.collect()
    assert [r() for r in refs] == [None, None, None]  # the whole chain released (the rest never ran)
    for i in range(20):  # freed entries are handed out right again
        nop(ring, 100 + i)
    assert u.io_uring_submit_and_wait(ring, 20) == 20
    assert sorted(data for data, _ in reap_all(ring, cqe)) == list(range(100, 120))


def test_failure_cancels_rest_loudly(ring, cqe, pipe):
    # a request without the flag that fails: the rest post `-ECANCELED`, skipped ones too
    _, w = pipe
    bufs = [Buf(b"x"), Buf(b"y")]
    refs = [weakref.ref(b) for b in bufs]
    write(ring, -1, bufs[0], 1, u.IOSQE_IO_LINK)
    write(ring, w, bufs[1], 2, SKIP | u.IOSQE_IO_LINK)
    nop(ring, 3)
    del bufs
    assert u.io_uring_submit_and_wait(ring, 3) == 3
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    n = u.io_uring_cq_ready(ring)
    assert [(cqe.user_data_at(i)) for i in range(n)] == [1, 2, 3]
    u.io_uring_cq_advance(ring, n)
    gc.collect()
    assert [r() for r in refs] == [None, None]
    for i in range(20):
        nop(ring, 100 + i)
    assert u.io_uring_submit_and_wait(ring, 20) == 20
    assert sorted(data for data, _ in reap_all(ring, cqe)) == list(range(100, 120))


def test_skipped_hardlink_failure_continues(ring, cqe, pipe):
    _, w = pipe
    buf = Buf(b"y")
    ref = weakref.ref(buf)
    write(ring, -1, Buf(b"x"), 1, SKIP | u.IOSQE_IO_HARDLINK)  # fails, the chain goes on
    write(ring, w, buf, 2)
    del buf
    assert u.io_uring_submit_and_wait(ring, 2) == 2
    assert reap_all(ring, cqe) == [(1, -errno.EBADF), (2, 1)]
    gc.collect()
    assert ref() is None


def test_chain_end_may_not_skip(ring, cqe):
    nop(ring, 1, u.IOSQE_IO_LINK)
    sqe = nop(ring, 2, SKIP)  # the end: its completion would release the chain
    with pytest.raises(ValueError):
        u.io_uring_submit(ring)
    assert u.io_uring_sq_ready(ring) == 2  # nothing sent
    sqe.flags = 0
    assert u.io_uring_submit_and_wait(ring, 2) == 2
    assert reap_all(ring, cqe) == [(1, 0), (2, 0)]


def test_submit_ends_chain(ring, cqe):
    nop(ring, 1)
    sqe = nop(ring, 2, SKIP | u.IOSQE_IO_LINK)  # the last SQE of the submit ends its chain
    with pytest.raises(ValueError):
        u.io_uring_submit(ring)
    sqe.flags = u.IOSQE_IO_LINK  # a linked last one without the flag: fine, it is the end
    assert u.io_uring_submit_and_wait(ring, 2) == 2
    assert sorted(reap_all(ring, cqe)) == [(1, 0), (2, 0)]


def test_skip_alone_without_hold_reports_zero(ring, cqe):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_close(sqe, -1)  # fails: EBADF, holds nothing
    sqe.user_data = 5
    sqe.flags = SKIP
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert reap_all(ring, cqe) == [(0, -errno.EBADF)]  # alone: no entry, the user's value is gone


def test_skip_without_hold_in_chain(ring, cqe):
    nop(ring, 1, SKIP | u.IOSQE_IO_LINK)
    nop(ring, 2, SKIP | u.IOSQE_IO_LINK)
    nop(ring, 3)
    assert u.io_uring_submit_and_wait(ring, 1) == 3
    assert reap_all(ring, cqe) == [(3, 0)]


def test_cancelled_skipped_member(ring, cqe):
    # `-ECANCELED` from a skipped member: the rest may post or not; holds are released either way, and a
    # completion that still comes names a buried entry, not a new request
    import socket

    a, b = socket.socketpair()
    try:
        bufs = [Buf(4), Buf(b"end")]
        refs = [weakref.ref(x) for x in bufs]
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_recv(sqe, a.fileno(), bufs[0])  # waits: nothing sent
        sqe.user_data = 1
        sqe.flags = SKIP | u.IOSQE_IO_LINK
        write(ring, b.fileno(), bufs[1], 2)  # the end
        del bufs
        assert u.io_uring_submit(ring) == 2
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_cancel64(sqe, 1)
        sqe.user_data = 3
        assert u.io_uring_submit(ring) == 1
        got = []
        for _ in range(4):  # whatever posts within a short wait
            try:
                u.io_uring_wait_cqe_timeout(ring, cqe, u.timespec(0.2))
            except OSError:
                break
            got += reap_all(ring, cqe)
        assert (1, -errno.ECANCELED) in got and (3, 0) in got
        gc.collect()
        assert [r() for r in refs] == [None, None]
        for i in range(20):
            nop(ring, 100 + i)
        assert u.io_uring_submit_and_wait(ring, 20) == 20
        assert sorted(data for data, _ in reap_all(ring, cqe)) == list(range(100, 120))
    finally:
        a.close()
        b.close()
