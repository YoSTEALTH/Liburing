"""Regressions for bugs found after the Setu port (2026-10-19); most also affected the PyOZ build."""

import gc
import mmap
import os
import pytest
import liburing


# 1. Paths are read by the kernel at submit time, not when the `sqe` is prepared.


def test_temporary_path_survives_until_submit(tmp_dir, ring, cqe):
    (tmp_dir / "target.txt").write_text("hi")
    for make in (lambda: tmp_dir / "target.txt", lambda: str(tmp_dir) + "/target.txt"):
        for _ in range(50):
            sqe = liburing.io_uring_get_sqe(ring)
            liburing.io_uring_prep_open(sqe, make(), liburing.O_RDONLY)  # a temporary
            junk = [str(tmp_dir) + f"/other_name_{i:02}.zzz" for i in range(50)]  # reuses freed memory
            del junk
            gc.collect()
            assert liburing.io_uring_submit(ring) == 1
            assert liburing.io_uring_wait_cqe(ring, cqe) == 0
            os.close(cqe[0].res)
            liburing.io_uring_cqe_seen(ring, cqe[0])


def test_temporary_path_with_put_sqe(tmp_dir, ring, cqe):
    (tmp_dir / "target.txt").write_text("hi")
    for _ in range(50):
        sqe = liburing.Sqe()
        liburing.io_uring_prep_open(sqe, tmp_dir / "target.txt", liburing.O_RDONLY)  # a temporary
        junk = [str(tmp_dir) + f"/other_name_{i:02}.zzz" for i in range(50)]  # reuses freed memory
        assert liburing.put_sqe(ring, sqe)
        del sqe, junk
        junk = [str(tmp_dir) + f"/other_name_{i:02}.yyy" for i in range(50)]
        assert liburing.io_uring_submit(ring) == 1
        assert liburing.io_uring_wait_cqe(ring, cqe) == 0
        os.close(cqe[0].res)
        liburing.io_uring_cqe_seen(ring, cqe[0])


# 2. Python input must raise, not abort the interpreter.


@pytest.mark.parametrize("second", [float("nan"), float("inf"), -float("inf"), -1.5])
def test_timespec_invalid(second):
    with pytest.raises(ValueError):
        liburing.timespec(second)


def test_timespec_out_of_range():
    with pytest.raises(OverflowError):
        liburing.timespec(1e30)


def test_trap_error_int_min():
    with pytest.raises(OverflowError):
        liburing.trap_error(-(2**31))


def test_buffer_longer_than_c_length():
    with mmap.mmap(-1, 2**32 + 1) as big:  # anonymous: no memory is touched
        with pytest.raises(OverflowError):
            liburing.io_uring_prep_read(liburing.Sqe(), 0, big)


def test_cqe_index_past_ring(ring, cqe):
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    with pytest.raises(IndexError):
        cqe[10**7]
    with pytest.raises(IndexError):
        cqe[-1]
    liburing.io_uring_cqe_seen(ring, cqe[0])


def test_cqe_index_wraps_around_the_queue():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    liburing.io_uring_queue_init(4, ring)  # 4 SQ entries, 8 CQ entries
    try:
        for start, n in ((100, 4), (200, 3), (300, 4)):  # the third batch wraps past CQ slot 7
            for i in range(n):
                sqe = liburing.io_uring_get_sqe(ring)
                liburing.io_uring_prep_nop(sqe)
                sqe.user_data = start + i
            liburing.io_uring_submit(ring)
            liburing.io_uring_wait_cqe_nr(ring, cqe, n)
            assert [cqe[i].user_data for i in range(n)] == list(range(start, start + n))
            liburing.io_uring_cq_advance(ring, n)
    finally:
        liburing.io_uring_queue_exit(ring)


# 4. A ring that is not initialised (or has exited) raises instead of crashing.


def test_ring_not_initialized():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    for call in (
        lambda: liburing.io_uring_get_sqe(ring),
        lambda: liburing.io_uring_submit(ring),
        lambda: liburing.io_uring_wait_cqe(ring, cqe),
        lambda: liburing.io_uring_cqe_iter_init(ring),
        lambda: liburing.CqeIter(ring, cqe),
        lambda: liburing.io_uring_cq_ready(ring),
    ):
        with pytest.raises(RuntimeError):
            call()


def test_entries_after_exit():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    liburing.io_uring_queue_init(8, ring)
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    entry = cqe[0]
    sqe2 = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        entry.user_data
    with pytest.raises(RuntimeError):
        cqe[0]
    with pytest.raises(RuntimeError):
        sqe2.user_data = 1
    with pytest.raises(RuntimeError):
        liburing.io_uring_prep_nop(sqe2)


# 5. Same behaviour as the PyOZ build.


@pytest.mark.parametrize("cls", [liburing.Ring, liburing.Statx, liburing.Param, liburing.Timespec])
def test_no_argument_constructors(cls):
    cls()
    with pytest.raises(TypeError):
        cls(1)


def test_negative_index():
    with pytest.raises(IndexError):
        liburing.Sqe()[-1]
    with pytest.raises(IndexError):
        liburing.FileIndex([1, 2])[-1]


# 6. `cqe[i]` reuses an entry object only when nothing else holds it.


def test_cqe_entries_held_are_not_reused():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    liburing.io_uring_queue_init(8, ring)
    try:
        for i in range(6):
            sqe = liburing.io_uring_get_sqe(ring)
            liburing.io_uring_prep_nop(sqe)
            sqe.user_data = 10 + i
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe_nr(ring, cqe, 6)
        held = [cqe[i] for i in range(6)]  # more than the reuse slots: all must stay distinct
        assert [e.user_data for e in held] == list(range(10, 16))
        assert len({id(e) for e in held}) == 6
        del held
        for i in range(6):  # nothing held: values still follow the index
            assert cqe[i].user_data == 10 + i
        liburing.io_uring_cq_advance(ring, 6)
    finally:
        liburing.io_uring_queue_exit(ring)


# 7. `user_data_at(i)` / `res_at(i)` read `cqe[i]` without an entry object.


def test_cqe_user_data_at_res_at():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    liburing.io_uring_queue_init(4, ring)  # 8 CQ entries: the batches wrap around the queue
    try:
        for start, n in ((100, 4), (200, 3), (300, 4)):
            for i in range(n):
                sqe = liburing.io_uring_get_sqe(ring)
                liburing.io_uring_prep_nop(sqe)
                sqe.user_data = start + i
            liburing.io_uring_submit(ring)
            liburing.io_uring_wait_cqe_nr(ring, cqe, n)
            assert [cqe.user_data_at(i) for i in range(n)] == list(range(start, start + n))
            assert [cqe.res_at(i) for i in range(n)] == [cqe[i].res for i in range(n)]
            liburing.io_uring_cq_advance(ring, n)
    finally:
        liburing.io_uring_queue_exit(ring)


def test_cqe_at_errors(ring, cqe):
    with pytest.raises(IndexError):
        cqe.user_data_at(0)  # nothing completed yet
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_read(sqe, -1, bytearray(1), 0)  # bad fd: res = -EBADF
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    with pytest.raises(OSError):
        cqe.res_at(0)
    for bad in (10**7, -1):
        with pytest.raises(IndexError):
            cqe.user_data_at(bad)
        with pytest.raises(IndexError):
            cqe.res_at(bad)
    liburing.io_uring_cqe_seen(ring, cqe[0])


def test_cqe_at_after_exit():
    ring, cqe = liburing.Ring(), liburing.Cqe()
    liburing.io_uring_queue_init(8, ring)
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    liburing.io_uring_queue_exit(ring)
    with pytest.raises(RuntimeError):
        cqe.user_data_at(0)
    with pytest.raises(RuntimeError):
        cqe.res_at(0)
