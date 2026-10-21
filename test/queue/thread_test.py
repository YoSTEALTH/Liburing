"""One ring per thread: a `Ring` belongs to the thread that initialized it, and its waits let other threads run."""

import gc
import threading
import time
import pytest
import liburing as L

OTHER_THREAD = "belongs to the thread that initialized it"


def in_thread(fn):
    """`fn()` run by a new thread: what it returned or raised."""
    out = {}

    def run():
        try:
            out['value'] = fn()
        except BaseException as e:
            out['error'] = e

    t = threading.Thread(target=run)
    t.start()
    t.join()
    if 'error' in out:
        raise out['error']
    return out['value']


def test_other_thread_raises(ring):
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_nop(sqe)
    sqe.user_data = 7
    cqe = L.Cqe()
    assert L.io_uring_submit_and_wait(ring, 1) == 1
    assert L.io_uring_peek_cqe(ring, cqe) == 0
    entry = cqe[0]
    batch = L.CqeBatch(4)
    assert L.io_uring_peek_batch_cqe(ring, batch) == 1

    for use in (
        lambda: L.io_uring_get_sqe(ring),
        lambda: L.io_uring_submit(ring),
        lambda: L.io_uring_submit_and_wait(ring, 1),
        lambda: L.io_uring_wait_cqe(ring, L.Cqe()),
        lambda: L.io_uring_cq_ready(ring),
        lambda: L.io_uring_cq_advance(ring, 1),
        lambda: L.io_uring_queue_exit(ring),
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
    L.io_uring_cq_advance(ring, 1)


def test_owner_is_who_initialized():
    ring = L.Ring()  # made here, initialized and used by another thread
    def use():
        L.io_uring_queue_init(8, ring)
        L.io_uring_prep_nop(L.io_uring_get_sqe(ring))
        return L.io_uring_submit_and_wait(ring, 1)
    assert in_thread(use) == 1
    with pytest.raises(RuntimeError, match=OTHER_THREAD):
        L.io_uring_cq_ready(ring)
    in_thread(lambda: L.io_uring_queue_exit(ring))

    L.io_uring_queue_init(8, ring)  # exited: anyone can initialize it again, and owns it
    assert L.io_uring_cq_ready(ring) == 0
    L.io_uring_queue_exit(ring)


def waiting(seconds, wait):
    """A thread with its own ring, sleeping in the kernel for `seconds` in `wait(ring)`; started and
    inside the wait (give or take a moment) when this returns."""
    started = threading.Event()

    def run():
        ring = L.Ring()
        L.io_uring_queue_init(8, ring)
        try:
            L.io_uring_prep_timeout(L.io_uring_get_sqe(ring), L.timespec(seconds), 0, 0)
            started.set()
            wait(ring)
        finally:
            L.io_uring_queue_exit(ring)

    t = threading.Thread(target=run)
    t.start()
    started.wait()
    time.sleep(0.05)  # into the wait
    return t


@pytest.mark.parametrize('wait', [
    lambda ring: L.io_uring_submit_and_wait(ring, 1),
    lambda ring: (L.io_uring_submit(ring), L.io_uring_wait_cqe(ring, L.Cqe())),
    lambda ring: (L.io_uring_submit(ring), L.io_uring_wait_cqe_nr(ring, L.Cqe(), 1)),
    lambda ring: (L.io_uring_submit(ring), L.io_uring_wait_cqes(ring, L.Cqe(), 1)),
    lambda ring: L.io_uring_submit_and_wait_timeout(ring, L.Cqe(), 1, L.timespec(5)),
], ids=['submit_and_wait', 'wait_cqe', 'wait_cqe_nr', 'wait_cqes', 'submit_and_wait_timeout'])
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
        ring, cqe = L.Ring(), L.Cqe()
        L.io_uring_queue_init(32, ring)
        try:
            done = 0
            for i in range(200):
                for j in range(8):
                    sqe = L.io_uring_get_sqe(ring)
                    L.io_uring_prep_nop(sqe)
                    sqe.user_data = i * 8 + j
                L.io_uring_submit_and_wait(ring, 8)
                ready = L.io_uring_cq_ready(ring)
                L.io_uring_peek_cqe(ring, cqe)
                assert sorted(cqe.user_data_at(k) for k in range(ready)) == list(range(i * 8, i * 8 + 8))
                L.io_uring_cq_advance(ring, ready)
                done += ready
            return done
        finally:
            L.io_uring_queue_exit(ring)

    results = []
    threads = [threading.Thread(target=lambda: results.append(run())) for _ in range(8)]
    for t in threads:
        t.start()
    for _ in range(5):
        gc.collect()
    for t in threads:
        t.join()
    assert results == [1600] * 8
