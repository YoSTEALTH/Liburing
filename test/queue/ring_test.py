"""Ring-level functions: parameters, waiting with timeouts, eventfd, registration, buffer rings, ..."""

import errno
import gc
import mmap
import os
import subprocess
import sys
import weakref
import pytest
from liburing import *


def nop(ring, user_data, submit=True):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    return io_uring_submit(ring) if submit else sqe


# sqe_set_* / cqe_get_*


def test_sqe_set_flags_data(ring):
    sqe = io_uring_get_sqe(ring)
    io_uring_sqe_set_flags(sqe, IOSQE_IO_LINK)
    assert sqe.flags == IOSQE_IO_LINK
    io_uring_sqe_set_data64(sqe, 99)
    assert sqe.user_data == 99
    data = object()
    io_uring_sqe_set_data(sqe, data)
    assert sqe.user_data == id(data)  # as in C: the object's address
    io_uring_sqe_set_buf_group(sqe, 5)  # shares `buf_index` with the fixed buffer index


def test_cqe_get_data(ring, cqe):
    assert nop(ring, 7) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    assert io_uring_cqe_get_data64(cqe[0]) == 7
    assert io_uring_cqe_get_data(cqe[0]) is None  # an `int`, no object
    assert cqe.data_res(0) == (None, 0)
    io_uring_cqe_seen(ring, cqe[0])


def nop_data(ring, data):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    io_uring_sqe_set_data(sqe, data)
    return sqe


def test_sqe_set_data_object(ring, cqe):
    conn = {"fd": 5}
    before = sys.getrefcount(conn)
    nop_data(ring, conn)
    nop_data(ring, conn)
    assert sys.getrefcount(conn) == before + 2  # each request holds it
    assert io_uring_submit_and_wait(ring, 2) == 2
    assert io_uring_wait_cqe_nr(ring, cqe, 2) == 0
    assert io_uring_cqe_get_data(cqe[0]) is conn
    assert io_uring_cqe_get_data64(cqe[0]) == id(conn)
    assert cqe.data_res(1) == (conn, 0)
    io_uring_cq_advance(ring, 2)
    assert sys.getrefcount(conn) == before  # released with the completions


def test_sqe_set_data_replaced(ring, cqe):
    first, second = object(), object()
    before = sys.getrefcount(first)
    sqe = nop_data(ring, first)
    io_uring_sqe_set_data(sqe, second)  # the slot's earlier object is dropped
    assert sys.getrefcount(first) == before
    assert io_uring_submit_and_wait(ring, 1) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    assert io_uring_cqe_get_data(cqe[0]) is second
    io_uring_cqe_seen(ring, cqe[0])


def test_sqe_set_data_then_user_data(ring, cqe):
    data = object()
    before = sys.getrefcount(data)
    sqe = nop_data(ring, data)
    sqe.user_data = 5  # a later `user_data` wins
    assert io_uring_submit_and_wait(ring, 1) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    assert cqe[0].user_data == 5
    assert io_uring_cqe_get_data(cqe[0]) is None
    io_uring_cqe_seen(ring, cqe[0])
    assert sys.getrefcount(data) == before  # still released


def test_sqe_set_data_bound(ring, cqe):
    data = object()
    sqe = Sqe(ring)
    assert io_uring_prep_nop(sqe)
    io_uring_sqe_set_data(sqe, data)
    assert io_uring_submit_and_wait(ring, 1) == 1
    assert io_uring_wait_cqe(ring, cqe) == 0
    assert io_uring_cqe_get_data(cqe[0]) is data
    io_uring_cqe_seen(ring, cqe[0])


def test_sqe_set_data_template(ring, cqe):
    data = [object(), object()]
    before = [sys.getrefcount(d) for d in data]
    sqe = Sqe(2)
    for i in range(2):
        io_uring_prep_nop(sqe[i])
        io_uring_sqe_set_data(sqe[i], data[i])
    one = Sqe()
    io_uring_prep_nop(one)
    io_uring_sqe_set_data(one, data[0])
    assert put_sqe(ring, sqe) and put_sqe(ring, one)
    assert sys.getrefcount(data[0]) == before[0] + 2 + 2  # the templates' references, and one per copy
    del sqe, one  # the copies keep their own
    assert io_uring_submit_and_wait(ring, 3) == 3
    assert io_uring_wait_cqe_nr(ring, cqe, 3) == 0
    assert [cqe.data_res(i)[0] for i in range(3)] == [data[0], data[1], data[0]]
    io_uring_cq_advance(ring, 3)
    assert [sys.getrefcount(d) for d in data] == before


def test_sqe_set_data_skip_success_alone(ring):
    sqe = nop_data(ring, object())
    sqe.flags = IOSQE_CQE_SKIP_SUCCESS  # no completion would release it
    with pytest.raises(ValueError, match="holds a buffer or object"):
        io_uring_submit(ring)
    sqe.flags = 0
    assert io_uring_submit(ring) == 1


def test_sqe_set_data_not_submitted():
    data = object()
    before = sys.getrefcount(data)
    ring = Ring()
    io_uring_queue_init(8, ring)
    nop_data(ring, data)
    io_uring_queue_exit(ring)  # released with the ring
    assert sys.getrefcount(data) == before


def test_sqe_set_data_failed_prep(ring):
    data = object()
    before = sys.getrefcount(data)
    sqe = Sqe(ring)
    assert io_uring_prep_nop(sqe)
    io_uring_sqe_set_data(sqe, data)
    with pytest.raises(OverflowError):
        io_uring_prep_read(sqe, -1, bytearray(1), -2)  # the next slot: handed back
    assert sys.getrefcount(data) == before + 1  # its own slot keeps it
    assert io_uring_submit(ring) == 1


class Box:
    """Weak-referenceable, unlike `Sqe` and `Ring`: tells when a cycle through one was collected."""


def test_sqe_set_data_cycles():
    template = Box()
    template.sqe = Sqe()
    io_uring_prep_nop(template.sqe)
    io_uring_sqe_set_data(template.sqe, template)  # a template holding itself
    pending, in_flight = Box(), Box()
    pending.ring = in_flight.ring = Ring()
    io_uring_queue_init(8, pending.ring)
    nop_data(pending.ring, in_flight)
    assert io_uring_submit(pending.ring) == 1
    nop_data(pending.ring, pending)  # a ring holding itself: in flight, and pending
    refs = [weakref.ref(b) for b in (template, pending, in_flight)]
    del template, pending, in_flight
    gc.collect()
    assert [r() for r in refs] == [None, None, None]


def test_prep_cancel_object(ring, cqe):
    r, w = os.pipe()
    try:
        conn = object()
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, r, bytearray(1))
        io_uring_sqe_set_data(sqe, conn)
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_cancel(sqe, conn)
        sqe.user_data = 9
        assert io_uring_submit_and_wait(ring, 2) == 2
        assert io_uring_wait_cqe_nr(ring, cqe, 2) == 0
        results = {cqe.user_data_at(i): cqe.data_res(i) for i in range(2)}
        assert results[9] == (None, 0)  # the cancel found it
        assert results[id(conn)] == (conn, -errno.ECANCELED)
        io_uring_cq_advance(ring, 2)
    finally:
        os.close(r)
        os.close(w)


# queue state


def test_sq_space_left(ring):
    left = io_uring_sq_space_left(ring)
    assert left == 1024
    io_uring_get_sqe(ring)
    assert io_uring_sq_space_left(ring) == left - 1


def test_cq_overflow_events(ring, cqe):
    assert io_uring_cq_has_overflow(ring) is False
    assert io_uring_sqring_wait(ring) == 0  # room in the queue: returns at once
    nop(ring, 1, submit=False)
    assert io_uring_submit_and_get_events(ring) == 1
    assert io_uring_get_events(ring) == 0
    assert io_uring_cq_ready(ring) == 1
    io_uring_cq_advance(ring, 1)


def test_set_iowait(ring):
    assert io_uring_set_iowait(ring, True) == 0
    assert io_uring_set_iowait(ring, False) == 0


# waiting with a timeout


def test_wait_cqe_timeout(ring, cqe):
    assert nop(ring, 3) == 1
    assert io_uring_wait_cqe_timeout(ring, cqe, timespec(1)) == 0
    assert cqe[0].user_data == 3
    io_uring_cqe_seen(ring, cqe[0])
    with pytest.raises(OSError) as e:  # nothing left: ETIME
        io_uring_wait_cqe_timeout(ring, cqe, timespec(0.01))
    assert e.value.errno == 62


def test_wait_cqes_min_timeout(ring, cqe):
    nop(ring, 1)
    nop(ring, 2)
    assert io_uring_wait_cqes_min_timeout(ring, cqe, 2, timespec(1), 1000) >= 0
    assert io_uring_cq_ready(ring) == 2
    io_uring_cq_advance(ring, 2)
    with pytest.raises(OSError) as e:
        io_uring_wait_cqes_min_timeout(ring, cqe, 1, timespec(0.01), 1000)
    assert e.value.errno == 62


def test_submit_and_wait_min_timeout(ring, cqe):
    nop(ring, 1, submit=False)
    assert io_uring_submit_and_wait_min_timeout(ring, cqe, 1, timespec(1), 1000) >= 0
    assert cqe[0].user_data == 1
    io_uring_cqe_seen(ring, cqe[0])
    with pytest.raises(OSError):
        io_uring_submit_and_wait_min_timeout(ring, cqe, 1, timespec(0.01), 1000)


# eventfd


def test_eventfd(ring, cqe):
    efd = os.eventfd(0)
    try:
        assert io_uring_register_eventfd(ring, efd) == 0
        assert io_uring_cq_eventfd_enabled(ring) is True
        nop(ring, 1)
        io_uring_wait_cqe(ring, cqe)
        assert os.eventfd_read(efd) >= 1
        io_uring_cqe_seen(ring, cqe[0])
        assert io_uring_cq_eventfd_toggle(ring, False) == 0
        assert io_uring_cq_eventfd_enabled(ring) is False
        assert io_uring_unregister_eventfd(ring) == 0
        assert io_uring_register_eventfd_async(ring, efd) == 0
        assert io_uring_unregister_eventfd(ring) == 0
    finally:
        os.close(efd)


# registration


def test_personality(ring):
    pid = io_uring_register_personality(ring)
    assert pid > 0
    assert io_uring_unregister_personality(ring, pid) == 0
    with pytest.raises(OSError):
        io_uring_unregister_personality(ring, pid)


def test_register_ring_fd(ring, cqe):
    assert io_uring_register_ring_fd(ring) == 1
    nop(ring, 1)  # still works through the registered fd
    assert io_uring_wait_cqe(ring, cqe) == 0
    io_uring_cqe_seen(ring, cqe[0])
    assert io_uring_unregister_ring_fd(ring) == 1


def test_file_alloc_range_and_sparse(ring):
    with pytest.raises(OSError):  # no table yet
        io_uring_register_file_alloc_range(ring, 0, 4)
    assert io_uring_register_files_sparse(ring, 4) == 0
    assert io_uring_register_file_alloc_range(ring, 0, 4) == 0
    assert io_uring_unregister_files(ring) == 0


def test_register_files_tags(ring):
    with pytest.raises(OSError):  # a table is already registered: EBUSY
        assert io_uring_register_files_sparse(ring, 2) == 0
        io_uring_register_files_tags(ring, FileIndex([-1, -1]), [0, 0])
    assert io_uring_unregister_files(ring) == 0


def test_register_files_tags_list(ring):
    r, w = os.pipe()  # a tag needs a real file: `-1` (sparse) can only have tag `0`
    try:
        assert io_uring_register_files_tags(ring, FileIndex([r, w]), [7, 8]) == 0
        assert io_uring_register_files_update_tag(ring, FileIndex([w]), [9], 1) == 1
        with pytest.raises(ValueError):  # one tag for each file
            io_uring_register_files_update_tag(ring, FileIndex([r, w]), [1])
        assert io_uring_unregister_files(ring) == 0
    finally:
        os.close(r)
        os.close(w)


def test_register_buffers(ring):
    iov = [bytearray(4096)]
    assert io_uring_register_buffers_sparse(ring, 4) == 0
    assert io_uring_unregister_buffers(ring) == 0
    assert io_uring_register_buffers(ring, iov) == 0
    assert io_uring_unregister_buffers(ring) == 0
    assert io_uring_register_buffers(ring, iov, [5]) == 0  # with tags
    assert io_uring_register_buffers_update_tag(ring, iov, [6]) == 1
    with pytest.raises(ValueError):  # one tag for each buffer
        io_uring_register_buffers(ring, iov, [1, 2])
    with pytest.raises(ValueError):
        io_uring_register_buffers_update_tag(ring, iov, [])
    assert io_uring_unregister_buffers(ring) == 0


def test_clone_buffers(ring):
    dst = Ring()
    io_uring_queue_init(8, dst)
    try:
        assert io_uring_register_buffers(ring, [bytearray(4096)]) == 0
        assert io_uring_clone_buffers(dst, ring) == 0
        assert io_uring_unregister_buffers(dst) == 0
        assert io_uring_unregister_buffers(ring) == 0
    finally:
        io_uring_queue_exit(dst)


def test_ring_dontfork_and_enable(ring):
    assert io_uring_ring_dontfork(ring) == 0
    with pytest.raises(OSError):  # already enabled: EBADFD
        io_uring_enable_rings(ring)


def test_enable_rings_disabled_start():
    ring = Ring()
    io_uring_queue_init(8, ring, IORING_SETUP_R_DISABLED)
    try:
        assert io_uring_enable_rings(ring) == 0
    finally:
        io_uring_queue_exit(ring)


def test_opcode_supported():
    ring = Ring()
    io_uring_queue_init(8, ring)
    try:
        probe = io_uring_get_probe_ring(ring)
        assert io_uring_opcode_supported(probe, io_uring_op.IORING_OP_NOP) is True
        assert io_uring_opcode_supported(probe, 200) is False
    finally:
        io_uring_queue_exit(ring)


# Param / init variants


def test_param():
    p = Param()
    assert p.sq_entries == p.cq_entries == p.flags == p.features == 0
    p.sq_entries = 4
    p.cq_entries = 8
    assert (p.sq_entries, p.cq_entries) == (4, 8)
    p.sq_thread_idle = 5
    p.sq_thread_cpu = 1
    p.wq_fd = 0
    assert (p.sq_thread_idle, p.sq_thread_cpu, p.wq_fd) == (5, 1, 0)


def test_queue_init_params():
    ring, p = Ring(), Param()
    assert io_uring_queue_init_params(8, ring, p) == 0
    try:
        assert p.sq_entries == 8
        assert p.cq_entries == 16
        assert p.features != 0
        with pytest.raises(RuntimeError):  # already initialized
            io_uring_queue_init_params(8, ring, Param())
    finally:
        io_uring_queue_exit(ring)


def test_queue_init_params_flags():
    ring, p = Ring(), Param()
    p.flags = IORING_SETUP_CQSIZE
    p.cq_entries = 64
    assert io_uring_queue_init_params(8, ring, p) == 0
    try:
        assert p.cq_entries == 64
    finally:
        io_uring_queue_exit(ring)


def test_io_uring_setup_enter():
    p = Param()
    fd = io_uring_setup(4, p)
    try:
        assert fd > 0
        assert p.sq_entries == 4
    finally:
        os.close(fd)


def test_resize_rings():
    ring, p = Ring(), Param()
    io_uring_queue_init(8, ring, IORING_SETUP_DEFER_TASKRUN | IORING_SETUP_SINGLE_ISSUER)
    try:
        p.flags = IORING_SETUP_CQSIZE
        p.sq_entries = 32
        p.cq_entries = 64
        assert io_uring_resize_rings(ring, p) == 0
        assert p.sq_entries == 32
        assert p.cq_entries == 64
        assert io_uring_sq_space_left(ring) == 32
    finally:
        io_uring_queue_exit(ring)


def test_close_ring_fd_needs_registered_fd(ring):
    with pytest.raises(OSError):
        io_uring_close_ring_fd(ring)


def test_close_ring_fd_keeps_ring():
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    try:
        assert io_uring_register_ring_fd(ring) == 1
        assert io_uring_close_ring_fd(ring) == 1
        assert ring.ring_fd == -1
        assert nop(ring, 7) == 1  # still usable through the registered fd
        io_uring_wait_cqe(ring, cqe)
        assert cqe[0].user_data == 7
        io_uring_cqe_seen(ring, cqe[0])
    finally:
        io_uring_queue_exit(ring)  # exits it too: its mappings go
    assert ring.ring_fd == -1  # no fd once exited
    with pytest.raises(RuntimeError):
        io_uring_get_sqe(ring)


# buffer ring


def test_buf_ring(ring):
    assert io_uring_buf_ring_mask(8) == 7
    br = io_uring_setup_buf_ring(ring, 8, 1, 0)
    try:
        assert io_uring_buf_ring_available(ring, br, 1) == 0
        bufs = [bytearray(16) for _ in range(4)]
        for bid, buf in enumerate(bufs):
            io_uring_buf_ring_add(br, buf, bid, io_uring_buf_ring_mask(8), bid)
        io_uring_buf_ring_advance(br, 4)
        assert io_uring_buf_ring_available(ring, br, 1) == 4
    finally:
        assert io_uring_free_buf_ring(ring, br, 8, 1) == 0


def test_buf_ring_init_cq_advance(ring):
    br = io_uring_setup_buf_ring(ring, 4, 2, 0)
    try:
        io_uring_buf_ring_init(br)
        io_uring_buf_ring_cq_advance(ring, br, 0)
    finally:
        io_uring_free_buf_ring(ring, br, 4, 2)


def test_setup_buf_ring_error(ring):
    with pytest.raises(OSError):  # entries must be a power of two
        io_uring_setup_buf_ring(ring, 3, 1, 0)


# sizes, shifts and low-level helpers


def test_cqe_nr(ring, cqe):
    nop(ring, 1)
    io_uring_wait_cqe(ring, cqe)
    assert io_uring_cqe_nr(cqe[0]) == 1
    io_uring_cqe_seen(ring, cqe[0])


def test_memory_and_mlock_size():
    assert io_uring_memory_size(8, 0) > 0
    assert io_uring_memory_size(4096, 0) > io_uring_memory_size(8, 0)
    assert io_uring_mlock_size(8, 0) >= 0  # 0 on kernels that no longer count rings against RLIMIT_MEMLOCK
    p = Param()
    assert io_uring_memory_size_params(8, p) > 0
    assert io_uring_mlock_size_params(8, p) >= 0
    with pytest.raises(OSError):  # 0 entries
        io_uring_memory_size(0, 0)


def test_prep_rw_removed():
    assert 'io_uring_prep_rw' not in globals()  # took any address: the kernel read / wrote memory nothing held


def test_iowq_aff(ring):
    assert io_uring_register_iowq_aff(ring, bytes([1])) == 0  # cpu 0
    assert io_uring_unregister_iowq_aff(ring) == 0
    assert io_uring_register_iowq_aff(ring, bytes([3])) == 0  # cpus 0 and 1
    assert io_uring_unregister_iowq_aff(ring) == 0


def test_iowq_max_workers(ring):
    old = io_uring_register_iowq_max_workers(ring, 0, 0)  # read the limits
    assert len(old) == 2 and old[0] > 0 and old[1] > 0
    assert io_uring_register_iowq_max_workers(ring, 2, 3) == old
    assert io_uring_register_iowq_max_workers(ring, 0, 0) == (2, 3)
    assert io_uring_register_iowq_max_workers(ring, *old) == (2, 3)


# the rest of the ring functions


def test_buf_ring_head_and_unregister(ring):
    br = io_uring_setup_buf_ring(ring, 8, 1, 0)
    assert io_uring_buf_ring_head(ring, 1) == 0
    with pytest.raises(FileNotFoundError):  # no ring for group 9
        io_uring_buf_ring_head(ring, 9)
    assert io_uring_unregister_buf_ring(ring, 1) == 0
    with pytest.raises(FileNotFoundError):
        io_uring_unregister_buf_ring(ring, 1)
    del br


def test_queue_init_mem():
    ring = Ring()
    size = io_uring_queue_init_mem(8, ring, Param())  # liburing allocates the memory
    try:
        assert size > 0  # the bytes of the memory it used
        assert ring.ring_fd > 0
        with pytest.raises(RuntimeError):
            io_uring_queue_init_mem(8, ring, Param())
    finally:
        io_uring_queue_exit(ring)


def test_queue_init_mem_buffer():
    ring, buf = Ring(), mmap.mmap(-1, 2 * 1024 * 1024)
    size = io_uring_queue_init_mem(8, ring, Param(), buf)
    try:
        assert 0 < size <= len(buf)
        with pytest.raises(BufferError):
            buf.close()  # the ring holds it until `io_uring_queue_exit`
    finally:
        io_uring_queue_exit(ring)
    buf.close()

    with pytest.raises(TypeError):
        io_uring_queue_init_mem(8, Ring(), Param(), b"read only")
    with pytest.raises(OSError):  # too small for the rings: ENOMEM
        io_uring_queue_init_mem(8, ring, Param(), mmap.mmap(-1, 4096))
    assert ring.ring_fd == -1


def test_queue_mmap():
    p, ring = Param(), Ring()
    fd = io_uring_setup(8, p)
    assert io_uring_queue_mmap(fd, ring, p) == 0
    try:
        assert ring.ring_fd == fd
        assert io_uring_sq_space_left(ring) == 8
    finally:
        io_uring_queue_exit(ring)  # closes the fd


def test_queue_mmap_set_up_ring(ring):
    p = Param()
    fd = io_uring_setup(8, p)
    try:
        with pytest.raises(RuntimeError):  # liburing would clear `ring`: lost, with its mappings
            io_uring_queue_mmap(fd, ring, p)
    finally:
        os.close(fd)
    assert nop(ring, 1) == 1  # untouched


def test_ring_fd_0():
    code = """if 1:
        import os
        from liburing import *
        os.close(0)  # stdin closed: the ring gets fd 0
        ring, cqe = Ring(), Cqe()
        io_uring_queue_init(8, ring)
        assert ring.ring_fd == 0
        io_uring_prep_nop(io_uring_get_sqe(ring))
        assert io_uring_submit_and_wait(ring, 1) == 1
        io_uring_queue_exit(ring)
        assert not any("io_uring" in line for line in open("/proc/self/maps"))
        print("ok")
    """
    env = {**os.environ, "PYTHONPATH": os.pathsep.join(sys.path)}
    out = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True, timeout=60, check=False)
    assert (out.returncode, out.stdout, out.stderr) == (0, "ok\n", "")


def test_clone_buffers_offset(ring):
    dst = Ring()
    io_uring_queue_init(8, dst)
    try:
        assert io_uring_register_buffers(ring, [bytearray(4096)]) == 0
        assert io_uring_clone_buffers_offset(dst, ring, 0, 0, 1) == 0
        assert io_uring_unregister_buffers(dst) == 0
        assert io_uring_unregister_buffers(ring) == 0
    finally:
        io_uring_queue_exit(dst)


def test_register_files_update_tag(ring):
    assert io_uring_register_files_sparse(ring, 4) == 0
    assert io_uring_register_files_update_tag(ring, FileIndex([-1]), [0]) == 1
    assert io_uring_unregister_files(ring) == 0


def test_enter2(ring, cqe):
    nop(ring, 1)
    assert io_uring_enter2(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, 0) == 0
    assert io_uring_cq_ready(ring) == 1
    io_uring_cq_advance(ring, 1)


def test_enter(ring, cqe):
    assert io_uring_enter(ring.ring_fd, 0, 0, 0, None) == 0  # nothing to submit, nothing to wait for
    nop(ring, 1)
    assert io_uring_enter(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, None) == 0  # waits (the GIL released)
    assert io_uring_cq_ready(ring) == 1
    io_uring_cq_advance(ring, 1)
    nop(ring, 2)
    assert io_uring_enter(ring.ring_fd, 0, 1, IORING_ENTER_GETEVENTS, SigsetT()) == 0  # with a signal mask
    assert io_uring_peek_cqe(ring, cqe) == 0
    assert cqe[0].user_data == 2
    io_uring_cqe_seen(ring, cqe[0])
    with pytest.raises(OSError):  # not a ring
        io_uring_enter(0, 0, 1, IORING_ENTER_GETEVENTS, None)


def test_register_raw(ring):
    assert io_uring_register(ring.ring_fd, 9, 0, None) >= 0  # IORING_REGISTER_PERSONALITY
    with pytest.raises(OSError):  # unknown opcode
        io_uring_register(ring.ring_fd, 9999, 0, None)


def test_get_sqe128():
    ring = Ring()
    io_uring_queue_init(8, ring, IORING_SETUP_SQE128)
    try:
        sqe = io_uring_get_sqe128(ring)
        io_uring_prep_nop128(sqe)
        assert sqe.opcode == io_uring_op.IORING_OP_NOP128
    finally:
        io_uring_queue_exit(ring)


def test_get_sqe128_full_queue():
    ring = Ring()
    io_uring_queue_init(2, ring, IORING_SETUP_SQE128)
    try:
        assert io_uring_get_sqe128(ring) is not None
        assert io_uring_get_sqe128(ring) is not None
        assert io_uring_get_sqe128(ring) is None  # full, and `auto_submit` is off
    finally:
        io_uring_queue_exit(ring)


def test_get_sqe128_uninitialized_ring():
    with pytest.raises(RuntimeError):
        io_uring_get_sqe128(Ring())


def test_register_sync_msg():
    ring = Ring()
    io_uring_queue_init(8, ring)
    try:
        sqe = Sqe()
        io_uring_prep_msg_ring(sqe, ring.ring_fd, 5, 77)
        assert io_uring_register_sync_msg(sqe) == 0
        cqe = Cqe()
        assert io_uring_wait_cqe_timeout(ring, cqe, timespec(1)) == 0
        assert (cqe[0].user_data, cqe[0].res) == (77, 5)
        io_uring_cqe_seen(ring, cqe[0])
    finally:
        io_uring_queue_exit(ring)


def test_ring_collected_without_exit():
    import gc
    import os

    before = len(os.listdir("/proc/self/fd"))
    for _ in range(20):
        ring = Ring()
        io_uring_queue_init(8, ring)
        del ring
    gc.collect()
    assert len(os.listdir("/proc/self/fd")) == before
