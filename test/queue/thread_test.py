"""One ring per thread: a `Ring` belongs to the thread that initialized it, and its waits let other threads run."""

import gc
import threading
import time
import pytest
from liburing import *

OTHER_THREAD = "belongs to the thread that initialized it"


def in_thread(fn):
    """`fn()` run by a new thread: what it returned or raised."""
    out = {}

    def run():
        try:
            out['value'] = fn()
        except BaseException as e:  # noqa: BLE001  (re-raised in the caller)
            out['error'] = e

    t = threading.Thread(target=run)
    t.start()
    t.join()
    if 'error' in out:
        raise out['error']
    return out['value']


def test_other_thread_raises(ring):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 7
    cqe = Cqe()
    assert io_uring_submit_and_wait(ring, 1) == 1
    assert io_uring_peek_cqe(ring, cqe) == 0
    entry = cqe[0]
    batch = CqeBatch(4)
    assert io_uring_peek_batch_cqe(ring, batch) == 1

    for use in (
        lambda: io_uring_get_sqe(ring),
        lambda: io_uring_submit(ring),
        lambda: io_uring_submit_and_wait(ring, 1),
        lambda: io_uring_wait_cqe(ring, Cqe()),
        lambda: io_uring_cq_ready(ring),
        lambda: io_uring_cq_advance(ring, 1),
        lambda: io_uring_queue_exit(ring),
        lambda: sqe.user_data,
        lambda: entry.user_data,
        lambda: cqe[0],
        lambda: cqe.res_at(0),
        lambda: batch[0],
    ):
        with pytest.raises(RuntimeError, match=OTHER_THREAD):
            in_thread(use)

    # the owner is not affected
    assert entry.user_data == 7 and cqe.user_data_at(0) == 7 and batch[0].user_data == 7
    io_uring_cq_advance(ring, 1)


def test_owner_is_who_initialized():
    ring = Ring()  # made here, initialized and used by another thread

    def use():
        io_uring_queue_init(8, ring)
        io_uring_prep_nop(io_uring_get_sqe(ring))
        return io_uring_submit_and_wait(ring, 1)

    assert in_thread(use) == 1
    with pytest.raises(RuntimeError, match=OTHER_THREAD):
        io_uring_cq_ready(ring)
    in_thread(lambda: io_uring_queue_exit(ring))

    io_uring_queue_init(8, ring)  # exited: anyone can initialize it again, and owns it
    assert io_uring_cq_ready(ring) == 0
    io_uring_queue_exit(ring)


def waiting(seconds, wait):
    """A thread with its own ring, sleeping in the kernel for `seconds` in `wait(ring)`; started and
    inside the wait (give or take a moment) when this returns."""
    started = threading.Event()

    def run():
        ring = Ring()
        io_uring_queue_init(8, ring)
        try:
            io_uring_prep_timeout(io_uring_get_sqe(ring), timespec(seconds), 0, 0)
            started.set()
            wait(ring)
        finally:
            io_uring_queue_exit(ring)

    t = threading.Thread(target=run)
    t.start()
    started.wait()
    time.sleep(0.05)  # into the wait
    return t


@pytest.mark.parametrize(
    'wait',
    [
        lambda ring: io_uring_submit_and_wait(ring, 1),
        lambda ring: (io_uring_submit(ring), io_uring_wait_cqe(ring, Cqe())),
        lambda ring: (io_uring_submit(ring), io_uring_wait_cqe_nr(ring, Cqe(), 1)),
        lambda ring: (io_uring_submit(ring), io_uring_wait_cqes(ring, Cqe(), 1)),
        lambda ring: io_uring_submit_and_wait_timeout(ring, Cqe(), 1, timespec(5)),
    ],
    ids=['submit_and_wait', 'wait_cqe', 'wait_cqe_nr', 'wait_cqes', 'submit_and_wait_timeout'],
)
def test_wait_lets_other_threads_run(wait):
    t = waiting(1, wait)
    try:
        start = time.monotonic()
        time.sleep(0.01)  # needs the GIL back (3.14 / 3.15)
        gc.collect()  # stops every thread (3.14t / 3.15t)
        assert time.monotonic() - start < 0.5  # not held up until the wait ends (1 s)
    finally:
        t.join()


def test_ring_per_thread():
    def run():
        ring, cqe = Ring(), Cqe()
        io_uring_queue_init(32, ring)
        try:
            done = 0
            for i in range(200):
                for j in range(8):
                    sqe = io_uring_get_sqe(ring)
                    io_uring_prep_nop(sqe)
                    sqe.user_data = i * 8 + j
                io_uring_submit_and_wait(ring, 8)
                ready = io_uring_cq_ready(ring)
                io_uring_peek_cqe(ring, cqe)
                assert sorted(cqe.user_data_at(k) for k in range(ready)) == list(range(i * 8, i * 8 + 8))
                io_uring_cq_advance(ring, ready)
                done += ready
            return done
        finally:
            io_uring_queue_exit(ring)

    results = []
    threads = [threading.Thread(target=lambda: results.append(run())) for _ in range(8)]
    for t in threads:
        t.start()
    for _ in range(5):
        gc.collect()
    for t in threads:
        t.join()
    assert results == [1600] * 8


NOT_OWNER = "belongs to the thread of its first"


def own_ring(fn):
    """`fn(ring)` in a new thread with a ring of its own: what it returned or raised."""

    def run():
        ring = Ring()
        io_uring_queue_init(4, ring)
        try:
            return fn(ring)
        finally:
            io_uring_queue_exit(ring)

    return in_thread(run)


def test_cqe_belongs_to_its_first_thread(ring):
    cqe = Cqe()
    io_uring_prep_nop(io_uring_get_sqe(ring))
    assert io_uring_submit_and_wait(ring, 1) == 1
    assert io_uring_peek_cqe(ring, cqe) == 0  # this thread's from now on
    for fill in (
        lambda r: io_uring_peek_cqe(r, cqe),
        lambda r: io_uring_wait_cqe_timeout(r, cqe, timespec(0.01)),
        lambda r: io_uring_cqe_iter_next(io_uring_cqe_iter_init(r), cqe),
    ):
        with pytest.raises(RuntimeError, match=NOT_OWNER):
            own_ring(fill)
    assert cqe.user_data_at(0) == 0  # untouched: still this ring's completion
    io_uring_cq_advance(ring, 1)


def test_refused_cqe_submits_nothing():
    cqe = Cqe()
    assert in_thread(lambda: cqe) is cqe  # nothing claims it there
    ring = Ring()
    io_uring_queue_init(4, ring)
    try:
        io_uring_peek_cqe(ring, cqe)  # claimed here (`EAGAIN`: none ready)
    except BlockingIOError:
        pass
    finally:
        io_uring_queue_exit(ring)

    def other(r):
        io_uring_prep_nop(io_uring_get_sqe(r))
        with pytest.raises(RuntimeError, match=NOT_OWNER):
            io_uring_submit_and_wait_timeout(r, cqe, 1, timespec(1))
        return io_uring_sq_ready(r)  # refused before the submit

    assert own_ring(other) == 1


def test_cqe_batch_belongs_to_its_first_thread(ring):
    batch = CqeBatch(4)
    assert io_uring_peek_batch_cqe(ring, batch) == 0
    with pytest.raises(RuntimeError, match=NOT_OWNER):
        own_ring(lambda r: io_uring_peek_batch_cqe(r, batch))


def test_first_use_in_another_thread():
    cqe, batch, tmpl = Cqe(), CqeBatch(2), Sqe()

    def use(r):  # made here, first used there: that thread's
        io_uring_prep_nop(tmpl)
        assert put_sqe(r, tmpl)
        assert io_uring_submit_and_wait(r, 1) == 1
        assert io_uring_peek_batch_cqe(r, batch) == 1
        assert io_uring_peek_cqe(r, cqe) == 0
        io_uring_cq_advance(r, 1)

    own_ring(use)
    ring = Ring()
    io_uring_queue_init(4, ring)
    try:
        with pytest.raises(RuntimeError, match=NOT_OWNER):
            io_uring_peek_cqe(ring, cqe)
        with pytest.raises(RuntimeError, match=NOT_OWNER):
            io_uring_peek_batch_cqe(ring, batch)
        with pytest.raises(RuntimeError, match=NOT_OWNER):
            io_uring_prep_nop(tmpl)
    finally:
        io_uring_queue_exit(ring)


def test_template_belongs_to_its_first_prep():
    tmpl = Sqe()
    io_uring_prep_nop(tmpl)  # this thread's, before any `put_sqe`
    with pytest.raises(RuntimeError, match=NOT_OWNER):
        in_thread(lambda: io_uring_prep_recv(tmpl, 0, bytearray(1)))
    with pytest.raises(RuntimeError, match=NOT_OWNER):
        own_ring(lambda r: put_sqe(r, tmpl))


def test_shared_structs_under_threads():
    # free-threaded: gets, sets and registers of one object's fields from several threads at once (critical
    # sections), no crash and no reference lost; with the GIL a plain run
    import mmap

    bpf, res, reg, region, ifq = Bpf(), Restriction(), BufReg(), MemRegionReg(), ZcrxIfqReg()
    programs = [bytes(8 * i) for i in range(1, 5)]
    memory = [mmap.mmap(-1, 4096) for _ in range(4)]

    def hammer(n):
        for i in range(3000):
            bpf.filter = programs[(i + n) % 4]
            assert bpf.filter in programs
            reg.ring = memory[(i + n) % 4]
            region.region = memory[i % 4]
            ifq.area, ifq.region = memory[n % 4], None
            assert reg.ring in memory and region.region in memory and ifq.area in memory
            if i % 300 == 0:
                res.add(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_NOP)

    threads = [threading.Thread(target=hammer, args=(n,)) for n in range(4)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert len(res) == 40
    bpf = reg = region = ifq = None  # their last references (`hammer` closes over the names)
    gc.collect()
    for m in memory:
        m.close()  # no view left behind
