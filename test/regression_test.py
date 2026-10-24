"""Regressions for bugs found after the Setu port (2026-10-19); most also affected the PyOZ build."""

import gc
import mmap
import os
import sys
import pytest
from liburing import *

# 1. Paths are read by the kernel at submit time, not when the `sqe` is prepared.


def test_temporary_path_survives_until_submit(tmp_dir, ring, cqe):
    (tmp_dir / "target.txt").write_text("hi")
    for make in (lambda: tmp_dir / "target.txt", lambda: str(tmp_dir) + "/target.txt"):
        for _ in range(50):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_open(sqe, make(), O_RDONLY)  # a temporary
            junk = [str(tmp_dir) + f"/other_name_{i:02}.zzz" for i in range(50)]  # reuses freed memory
            del junk
            gc.collect()
            assert io_uring_submit(ring) == 1
            assert io_uring_wait_cqe(ring, cqe) == 0
            os.close(cqe[0].res)
            io_uring_cqe_seen(ring, cqe[0])


def test_temporary_path_with_put_sqe(tmp_dir, ring, cqe):
    (tmp_dir / "target.txt").write_text("hi")
    for _ in range(50):
        sqe = Sqe()
        io_uring_prep_open(sqe, tmp_dir / "target.txt", O_RDONLY)  # a temporary
        junk = [str(tmp_dir) + f"/other_name_{i:02}.zzz" for i in range(50)]  # reuses freed memory
        assert put_sqe(ring, sqe)
        del sqe, junk
        _junk = [str(tmp_dir) + f"/other_name_{i:02}.yyy" for i in range(50)]
        assert io_uring_submit(ring) == 1
        assert io_uring_wait_cqe(ring, cqe) == 0
        os.close(cqe[0].res)
        io_uring_cqe_seen(ring, cqe[0])


# 2. Python input must raise, not abort the interpreter.


@pytest.mark.parametrize("second", [float("nan"), float("inf"), -float("inf"), -1.5])
def test_timespec_invalid(second):
    with pytest.raises(ValueError):
        timespec(second)


def test_timespec_out_of_range():
    with pytest.raises(OverflowError):
        timespec(1e30)


def test_trap_error_int_min():
    with pytest.raises(OverflowError):
        trap_error(-(2**31))


def test_buffer_longer_than_c_length():
    with mmap.mmap(-1, 2**32 + 1) as big, pytest.raises(OverflowError):  # anonymous: no memory is touched
        io_uring_prep_read(Sqe(), 0, big)


def test_cqe_index_past_ring(ring, cqe):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    with pytest.raises(IndexError):
        cqe[10**7]
    with pytest.raises(IndexError):
        cqe[-1]
    io_uring_cqe_seen(ring, cqe[0])


def test_cqe_index_wraps_around_the_queue():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(4, ring)  # 4 SQ entries, 8 CQ entries
    try:
        for start, n in ((100, 4), (200, 3), (300, 4)):  # the third batch wraps past CQ slot 7
            for i in range(n):
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_nop(sqe)
                sqe.user_data = start + i
            io_uring_submit(ring)
            io_uring_wait_cqe_nr(ring, cqe, n)
            assert [cqe[i].user_data for i in range(n)] == list(range(start, start + n))
            io_uring_cq_advance(ring, n)
    finally:
        io_uring_queue_exit(ring)


# 4. A ring that is not initialised (or has exited) raises instead of crashing.


def test_ring_not_initialized():
    ring, cqe = Ring(), Cqe()
    for call in (
        lambda: io_uring_get_sqe(ring),
        lambda: io_uring_submit(ring),
        lambda: io_uring_wait_cqe(ring, cqe),
        lambda: io_uring_cqe_iter_init(ring),
        lambda: CqeIter(ring, cqe),
        lambda: io_uring_cq_ready(ring),
    ):
        with pytest.raises(RuntimeError):
            call()


def test_entries_after_exit():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    sqe2 = io_uring_get_sqe(ring)
    io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        _ = entry.user_data
    with pytest.raises(RuntimeError):
        cqe[0]
    with pytest.raises(RuntimeError):
        sqe2.user_data = 1
    with pytest.raises(RuntimeError):
        io_uring_prep_nop(sqe2)


# 5. Same behaviour as the PyOZ build.


@pytest.mark.parametrize("cls", [Statx, Param, Timespec])
def test_no_argument_constructors(cls):
    cls()
    with pytest.raises(TypeError):
        cls(1)


def test_ring_constructor():
    Ring()
    Ring(auto_submit=True)  # its one argument
    with pytest.raises(TypeError):
        Ring(True, 1)
    with pytest.raises(TypeError):
        Ring(entries=8)


def test_negative_index():
    with pytest.raises(IndexError):
        Sqe()[-1]
    with pytest.raises(IndexError):
        FileIndex([1, 2])[-1]


# 6. `cqe[i]` reuses an entry object only when nothing else holds it.


def test_cqe_entries_held_are_not_reused():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    try:
        for i in range(6):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_nop(sqe)
            sqe.user_data = 10 + i
        io_uring_submit(ring)
        io_uring_wait_cqe_nr(ring, cqe, 6)
        held = [cqe[i] for i in range(6)]  # more than the reuse slots: all must stay distinct
        assert [e.user_data for e in held] == list(range(10, 16))
        assert len({id(e) for e in held}) == 6
        del held
        for i in range(6):  # nothing held: values still follow the index
            assert cqe[i].user_data == 10 + i
        io_uring_cq_advance(ring, 6)
    finally:
        io_uring_queue_exit(ring)


# 7. `user_data_at(i)` / `res_at(i)` read `cqe[i]` without an entry object.


def test_cqe_user_data_at_res_at():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(4, ring)  # 8 CQ entries: the batches wrap around the queue
    try:
        for start, n in ((100, 4), (200, 3), (300, 4)):
            for i in range(n):
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_nop(sqe)
                sqe.user_data = start + i
            io_uring_submit(ring)
            io_uring_wait_cqe_nr(ring, cqe, n)
            assert [cqe.user_data_at(i) for i in range(n)] == list(range(start, start + n))
            assert [cqe.res_at(i) for i in range(n)] == [cqe[i].res for i in range(n)]
            io_uring_cq_advance(ring, n)
    finally:
        io_uring_queue_exit(ring)


def test_cqe_at_errors(ring, cqe):
    with pytest.raises(IndexError):
        cqe.user_data_at(0)  # nothing completed yet
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, -1, bytearray(1), 0)  # bad fd: res = -EBADF
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    with pytest.raises(OSError):
        cqe.res_at(0)
    for bad in (10**7, -1):
        with pytest.raises(IndexError):
            cqe.user_data_at(bad)
        with pytest.raises(IndexError):
            cqe.res_at(bad)
    io_uring_cqe_seen(ring, cqe[0])


def test_cqe_at_after_exit():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        cqe.user_data_at(0)
    with pytest.raises(RuntimeError):
        cqe.res_at(0)


# 8. Timeouts and socket addresses are read by the kernel at submit time too.


def test_temporary_timespec_survives_until_submit(ring, cqe):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_timeout(sqe, timespec(30), 0)  # a temporary
    sqe.user_data = 1
    junk = [timespec(0) for _ in range(200)]  # reuses the freed memory with zeroes
    del junk
    gc.collect()
    assert io_uring_submit(ring) == 1
    with pytest.raises(OSError) as e:  # still pending after 0.2 s: the wait runs out, the timeout did not
        io_uring_wait_cqe_timeout(ring, cqe, timespec(0.2))
    assert e.value.errno == 62
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_timeout_remove(sqe, 1)
    io_uring_submit(ring)
    io_uring_wait_cqe_nr(ring, cqe, 2)
    io_uring_cq_advance(ring, 2)


def test_temporary_timespec_link_timeout_and_update(ring, cqe):
    r, w = os.pipe()
    buf = bytearray(1)  # held: the kernel writes into it after the submit (only paths / timespecs are kept)
    try:
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, r, buf)
        sqe.flags = IOSQE_IO_LINK
        sqe.user_data = 1
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_link_timeout(sqe, timespec(30), 0)  # a temporary
        sqe.user_data = 2
        junk = [timespec(0) for _ in range(200)]
        del junk
        gc.collect()
        assert io_uring_submit(ring) == 2
        with pytest.raises(OSError) as e:  # neither the read nor the 30 s timeout is done
            io_uring_wait_cqe_timeout(ring, cqe, timespec(0.2))
        assert e.value.errno == 62
        os.write(w, b"x")
        io_uring_wait_cqe_nr(ring, cqe, 2)
        io_uring_cq_advance(ring, 2)
        assert buf == b"x"
    finally:
        os.close(r)
        os.close(w)


# 9. `put_sqe` on a full queue (`False`, then a retry) holds nothing; a copy that went in holds its template.


def test_put_sqe_full_queue_keeps_paths_once(tmp_dir, cqe):
    ring = Ring()
    io_uring_queue_init(2, ring)
    try:
        path = str(tmp_dir) + "/target.txt"
        sqe = Sqe()
        io_uring_prep_open(sqe, path, O_RDONLY)  # the template holds `path`
        for _ in range(2):
            io_uring_prep_nop(io_uring_get_sqe(ring))  # queue full
        before = sys.getrefcount(sqe)
        for _ in range(5):
            assert not put_sqe(ring, sqe)
        assert sys.getrefcount(sqe) == before
        assert io_uring_submit_and_wait(ring, 2) == 2
        io_uring_peek_cqe(ring, cqe)
        io_uring_cq_advance(ring, 2)
        assert put_sqe(ring, sqe)
        assert sys.getrefcount(sqe) == before + 1  # the copy's, until its completion
        assert io_uring_submit_and_wait(ring, 1) == 1
        assert sys.getrefcount(sqe) == before + 1
        io_uring_wait_cqe(ring, cqe)
        io_uring_cqe_seen(ring, cqe[0])
        assert sys.getrefcount(sqe) == before
    finally:
        io_uring_queue_exit(ring)


# 10. Each loop over a `CqeBatch` has its own position: nested loops don't interfere.


def test_cqe_batch_nested_loops(ring):
    for i in range(2):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = i + 1
    assert io_uring_submit_and_wait(ring, 2) == 2
    batch = CqeBatch(4)
    assert io_uring_peek_batch_cqe(ring, batch) == 2
    assert [(a.user_data, b.user_data) for a in batch for b in batch] == [(1, 1), (1, 2), (2, 1), (2, 2)]
    it = iter(batch)
    assert iter(it) is it and next(it).user_data == 1
    assert [c.user_data for c in batch] == [1, 2] and next(it).user_data == 2
    with pytest.raises(StopIteration):
        next(it)
    with pytest.raises(TypeError):
        type(it)()
    io_uring_cq_advance(ring, 2)
