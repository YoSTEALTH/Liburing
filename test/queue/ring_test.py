"""Ring-level functions: parameters, waiting with timeouts, eventfd, registration, buffer rings, ..."""

import os
import pytest
import liburing as L


def nop(ring, user_data, submit=True):
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    return L.io_uring_submit(ring) if submit else sqe


# sqe_set_* / cqe_get_*


def test_sqe_set_flags_data(ring):
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_sqe_set_flags(sqe, L.IOSQE_IO_LINK)
    assert sqe.flags == L.IOSQE_IO_LINK
    L.io_uring_sqe_set_data64(sqe, 99)
    assert sqe.user_data == 99
    L.io_uring_sqe_set_data(sqe, 98)
    assert sqe.user_data == 98
    L.io_uring_sqe_set_buf_group(sqe, 5)  # shares `buf_index` with the fixed buffer index


def test_cqe_get_data(ring, cqe):
    assert nop(ring, 7) == 1
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    assert L.io_uring_cqe_get_data64(cqe[0]) == 7
    assert L.io_uring_cqe_get_data(cqe[0]) == 7
    L.io_uring_cqe_seen(ring, cqe[0])


# queue state


def test_sq_space_and_shift(ring):
    left = L.io_uring_sq_space_left(ring)
    assert left == 1024
    L.io_uring_get_sqe(ring)
    assert L.io_uring_sq_space_left(ring) == left - 1
    assert L.io_uring_sqe_shift(ring) == 0
    assert L.io_uring_sqe_shift_from_flags(0) == 0
    assert L.io_uring_sqe_shift_from_flags(L.IORING_SETUP_SQE128) == 1
    assert L.io_uring_load_sq_head(ring) == 0


def test_cq_overflow_events(ring, cqe):
    assert L.io_uring_cq_has_overflow(ring) is False
    assert L.io_uring_sqring_wait(ring) == 0  # room in the queue: returns at once
    nop(ring, 1, submit=False)
    assert L.io_uring_submit_and_get_events(ring) == 1
    assert L.io_uring_get_events(ring) == 0
    assert L.io_uring_cq_ready(ring) == 1
    L.io_uring_cq_advance(ring, 1)


def test_set_iowait(ring):
    assert L.io_uring_set_iowait(ring, True) == 0
    assert L.io_uring_set_iowait(ring, False) == 0


# waiting with a timeout


def test_wait_cqe_timeout(ring, cqe):
    assert nop(ring, 3) == 1
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(1)) == 0
    assert cqe[0].user_data == 3
    L.io_uring_cqe_seen(ring, cqe[0])
    with pytest.raises(OSError) as e:  # nothing left: ETIME
        L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(0.01))
    assert e.value.errno == 62


def test_wait_cqes_min_timeout(ring, cqe):
    nop(ring, 1)
    nop(ring, 2)
    assert L.io_uring_wait_cqes_min_timeout(ring, cqe, 2, L.timespec(1), 1000) >= 0
    assert L.io_uring_cq_ready(ring) == 2
    L.io_uring_cq_advance(ring, 2)
    with pytest.raises(OSError) as e:
        L.io_uring_wait_cqes_min_timeout(ring, cqe, 1, L.timespec(0.01), 1000)
    assert e.value.errno == 62


def test_submit_and_wait_min_timeout(ring, cqe):
    nop(ring, 1, submit=False)
    assert L.io_uring_submit_and_wait_min_timeout(ring, cqe, 1, L.timespec(1), 1000) >= 0
    assert cqe[0].user_data == 1
    L.io_uring_cqe_seen(ring, cqe[0])
    with pytest.raises(OSError):
        L.io_uring_submit_and_wait_min_timeout(ring, cqe, 1, L.timespec(0.01), 1000)


# eventfd


def test_eventfd(ring, cqe):
    efd = os.eventfd(0)
    try:
        assert L.io_uring_register_eventfd(ring, efd) == 0
        assert L.io_uring_cq_eventfd_enabled(ring) is True
        nop(ring, 1)
        L.io_uring_wait_cqe(ring, cqe)
        assert os.eventfd_read(efd) >= 1
        L.io_uring_cqe_seen(ring, cqe[0])
        assert L.io_uring_cq_eventfd_toggle(ring, False) == 0
        assert L.io_uring_cq_eventfd_enabled(ring) is False
        assert L.io_uring_unregister_eventfd(ring) == 0
        assert L.io_uring_register_eventfd_async(ring, efd) == 0
        assert L.io_uring_unregister_eventfd(ring) == 0
    finally:
        os.close(efd)


# registration


def test_personality(ring):
    pid = L.io_uring_register_personality(ring)
    assert pid > 0
    assert L.io_uring_unregister_personality(ring, pid) == 0
    with pytest.raises(OSError):
        L.io_uring_unregister_personality(ring, pid)


def test_register_ring_fd(ring, cqe):
    assert L.io_uring_register_ring_fd(ring) == 1
    nop(ring, 1)  # still works through the registered fd
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    L.io_uring_cqe_seen(ring, cqe[0])
    assert L.io_uring_unregister_ring_fd(ring) == 1


def test_file_alloc_range_and_sparse(ring):
    with pytest.raises(OSError):  # no table yet
        L.io_uring_register_file_alloc_range(ring, 0, 4)
    assert L.io_uring_register_files_sparse(ring, 4) == 0
    assert L.io_uring_register_file_alloc_range(ring, 0, 4) == 0
    assert L.io_uring_unregister_files(ring) == 0


def test_register_files_tags(ring):
    with pytest.raises(OSError):  # a table is already registered: EBUSY
        assert L.io_uring_register_files_sparse(ring, 2) == 0
        L.io_uring_register_files_tags(ring, L.FileIndex([-1, -1]), 0)
    assert L.io_uring_unregister_files(ring) == 0


def test_register_buffers(ring):
    iov = L.Iovec([bytearray(4096)])
    assert L.io_uring_register_buffers_sparse(ring, 4) == 0
    assert L.io_uring_unregister_buffers(ring) == 0
    assert L.io_uring_register_buffers(ring, iov) == 0
    assert L.io_uring_unregister_buffers(ring) == 0
    assert L.io_uring_register_buffers(ring, iov, 0) == 0  # with tags
    assert L.io_uring_register_buffers_update_tag(ring, iov, 0) == 1
    assert L.io_uring_unregister_buffers(ring) == 0


def test_clone_buffers(ring):
    dst = L.Ring()
    L.io_uring_queue_init(8, dst)
    try:
        assert L.io_uring_register_buffers(ring, L.Iovec([bytearray(4096)])) == 0
        assert L.io_uring_clone_buffers(dst, ring) == 0
        assert L.io_uring_unregister_buffers(dst) == 0
        assert L.io_uring_unregister_buffers(ring) == 0
    finally:
        L.io_uring_queue_exit(dst)


def test_ring_dontfork_and_enable(ring):
    assert L.io_uring_ring_dontfork(ring) == 0
    with pytest.raises(OSError):  # already enabled: EBADFD
        L.io_uring_enable_rings(ring)


def test_enable_rings_disabled_start():
    ring = L.Ring()
    L.io_uring_queue_init(8, ring, L.IORING_SETUP_R_DISABLED)
    try:
        assert L.io_uring_enable_rings(ring) == 0
    finally:
        L.io_uring_queue_exit(ring)


def test_opcode_supported():
    ring = L.Ring()
    L.io_uring_queue_init(8, ring)
    try:
        probe = L.io_uring_get_probe_ring(ring)
        assert L.io_uring_opcode_supported(probe, L.io_uring_op.IORING_OP_NOP) is True
        assert L.io_uring_opcode_supported(probe, 200) is False
    finally:
        L.io_uring_queue_exit(ring)


# Param / init variants


def test_param():
    p = L.Param()
    assert p.sq_entries == p.cq_entries == p.flags == p.features == 0
    p.sq_entries = 4
    p.cq_entries = 8
    assert (p.sq_entries, p.cq_entries) == (4, 8)
    p.sq_thread_idle = 5
    p.sq_thread_cpu = 1
    p.wq_fd = 0
    assert (p.sq_thread_idle, p.sq_thread_cpu, p.wq_fd) == (5, 1, 0)


def test_queue_init_params():
    ring, p = L.Ring(), L.Param()
    assert L.io_uring_queue_init_params(8, ring, p) == 0
    try:
        assert p.sq_entries == 8
        assert p.cq_entries == 16
        assert p.features != 0
        with pytest.raises(RuntimeError):  # already initialized
            L.io_uring_queue_init_params(8, ring, L.Param())
    finally:
        L.io_uring_queue_exit(ring)


def test_queue_init_params_flags():
    ring, p = L.Ring(), L.Param()
    p.flags = L.IORING_SETUP_CQSIZE
    p.cq_entries = 64
    assert L.io_uring_queue_init_params(8, ring, p) == 0
    try:
        assert p.cq_entries == 64
    finally:
        L.io_uring_queue_exit(ring)


def test_io_uring_setup_enter():
    p = L.Param()
    fd = L.io_uring_setup(4, p)
    try:
        assert fd > 0
        assert p.sq_entries == 4
    finally:
        os.close(fd)


def test_resize_rings():
    ring, p = L.Ring(), L.Param()
    L.io_uring_queue_init(8, ring, L.IORING_SETUP_DEFER_TASKRUN | L.IORING_SETUP_SINGLE_ISSUER)
    try:
        p.flags = L.IORING_SETUP_CQSIZE
        p.sq_entries = 32
        p.cq_entries = 64
        assert L.io_uring_resize_rings(ring, p) == 0
        assert p.sq_entries == 32
        assert p.cq_entries == 64
        assert L.io_uring_sq_space_left(ring) == 32
    finally:
        L.io_uring_queue_exit(ring)


def test_close_ring_fd_needs_registered_fd(ring):
    with pytest.raises(OSError):
        L.io_uring_close_ring_fd(ring)


# buffer ring


def test_buf_ring(ring):
    assert L.io_uring_buf_ring_mask(8) == 7
    br = L.io_uring_setup_buf_ring(ring, 8, 1, 0)
    try:
        assert L.io_uring_buf_ring_available(ring, br, 1) == 0
        bufs = [bytearray(16) for _ in range(4)]
        for bid, buf in enumerate(bufs):
            L.io_uring_buf_ring_add(br, buf, bid, L.io_uring_buf_ring_mask(8), bid)
        L.io_uring_buf_ring_advance(br, 4)
        assert L.io_uring_buf_ring_available(ring, br, 1) == 4
    finally:
        assert L.io_uring_free_buf_ring(ring, br, 8, 1) == 0


def test_buf_ring_init_cq_advance(ring):
    br = L.io_uring_setup_buf_ring(ring, 4, 2, 0)
    try:
        L.io_uring_buf_ring_init(br)
        L.io_uring_buf_ring_cq_advance(ring, br, 0)
    finally:
        L.io_uring_free_buf_ring(ring, br, 4, 2)


def test_setup_buf_ring_error(ring):
    with pytest.raises(OSError):  # entries must be a power of two
        L.io_uring_setup_buf_ring(ring, 3, 1, 0)


# sizes, shifts and low-level helpers


def test_cqe_nr_and_shift(ring, cqe):
    nop(ring, 1)
    L.io_uring_wait_cqe(ring, cqe)
    assert L.io_uring_cqe_nr(cqe[0]) == 1
    L.io_uring_cqe_seen(ring, cqe[0])
    assert L.io_uring_cqe_shift(ring) == 0
    assert L.io_uring_cqe_shift_from_flags(0) == 0
    assert L.io_uring_cqe_shift_from_flags(L.IORING_SETUP_CQE32) == 1


def test_memory_and_mlock_size():
    assert L.io_uring_memory_size(8, 0) > 0
    assert L.io_uring_memory_size(4096, 0) > L.io_uring_memory_size(8, 0)
    assert L.io_uring_mlock_size(8, 0) >= 0  # 0 on kernels that no longer count rings against RLIMIT_MEMLOCK
    p = L.Param()
    assert L.io_uring_memory_size_params(8, p) > 0
    assert L.io_uring_mlock_size_params(8, p) >= 0
    with pytest.raises(OSError):  # 0 entries
        L.io_uring_memory_size(0, 0)


def test_prep_rw():
    sqe = L.Sqe()
    L.io_uring_prep_rw(sqe, L.io_uring_op.IORING_OP_NOP, 5, None, 7, 9)
    assert sqe.opcode == L.io_uring_op.IORING_OP_NOP
    assert (sqe.fd, sqe.len) == (5, 7)


def test_prep_rw_runs(ring, cqe):
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_rw(sqe, L.io_uring_op.IORING_OP_NOP, 0, None, 0, 0)
    sqe.user_data = 3
    assert L.io_uring_submit(ring) == 1
    assert L.io_uring_wait_cqe(ring, cqe) == 0
    assert (cqe[0].user_data, cqe[0].res) == (3, 0)
    L.io_uring_cqe_seen(ring, cqe[0])


def test_iowq_aff(ring):
    assert L.io_uring_register_iowq_aff(ring, bytes([1])) == 0  # cpu 0
    assert L.io_uring_unregister_iowq_aff(ring) == 0
    assert L.io_uring_register_iowq_aff(ring, bytes([3])) == 0  # cpus 0 and 1
    assert L.io_uring_unregister_iowq_aff(ring) == 0


def test_iowq_max_workers(ring):
    old = L.io_uring_register_iowq_max_workers(ring, 0, 0)  # read the limits
    assert len(old) == 2 and old[0] > 0 and old[1] > 0
    assert L.io_uring_register_iowq_max_workers(ring, 2, 3) == old
    assert L.io_uring_register_iowq_max_workers(ring, 0, 0) == (2, 3)
    assert L.io_uring_register_iowq_max_workers(ring, *old) == (2, 3)
