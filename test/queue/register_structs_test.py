"""Register structs: `BufReg`, `SyncCancelReg`, `RegWait`, `MemRegionReg`, `Restriction`, `Napi`, `ClockRegister`,
`ZcrxIfqReg`, `Bpf`: their fields and the `io_uring_register_*` functions that take them."""

import gc
import mmap
import struct
import time
import weakref

import pytest

import liburing as u


def locked(memory):
    """Is `memory` (an `mmap`) locked by a view (`close()` refuses)? Closes it if not."""
    try:
        memory.close()
    except BufferError:
        return True
    return False


def nop(ring, user_data):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    return sqe


# BufReg


def test_buf_reg_fields():
    reg = u.BufReg()
    assert (reg.ring, reg.ring_entries, reg.bgid, reg.flags, reg.min_left) == (None, 0, 0, 0, 0)
    memory = mmap.mmap(-1, 4096)
    reg.ring, reg.ring_entries, reg.bgid, reg.flags, reg.min_left = memory, 8, 3, 0, 2
    assert (reg.ring, reg.ring_entries, reg.bgid, reg.flags, reg.min_left) == (memory, 8, 3, 0, 2)
    reg.ring = None
    assert reg.ring is None
    with pytest.raises(TypeError):
        reg.ring = b"read-only"
    with pytest.raises(TypeError):
        reg.ring = 4096  # an address: not any more
    with pytest.raises(OverflowError):
        reg.bgid = 2**16
    with pytest.raises(TypeError):
        u.BufReg(1)


def test_register_buf_ring(ring):
    memory = mmap.mmap(-1, 8 * 16)  # 8 entries of 16 bytes
    reg = u.BufReg()
    reg.ring = memory
    reg.ring_entries = 8
    reg.bgid = 3
    assert u.io_uring_register_buf_ring(ring, reg) == 0
    assert u.io_uring_buf_ring_head(ring, 3) == 0
    assert locked(memory)  # the kernel uses it until the unregister
    assert u.io_uring_unregister_buf_ring(ring, 3) == 0
    assert not locked(memory)


def test_register_buf_ring_holds_memory(ring):
    memory = mmap.mmap(-1, 4096)
    alive = weakref.ref(memory)
    reg = u.BufReg()
    reg.ring, reg.ring_entries, reg.bgid = memory, 8, 4
    assert u.io_uring_register_buf_ring(ring, reg) == 0
    del memory, reg
    gc.collect()
    assert alive() is not None  # the ring holds it, not only `reg`
    assert u.io_uring_unregister_buf_ring(ring, 4) == 0
    gc.collect()
    assert alive() is None


def test_register_buf_ring_released_at_exit():
    ring = u.Ring()
    u.io_uring_queue_init(4, ring)
    memory = mmap.mmap(-1, 4096)
    reg = u.BufReg()
    reg.ring, reg.ring_entries, reg.bgid = memory, 8, 1
    assert u.io_uring_register_buf_ring(ring, reg) == 0
    u.io_uring_queue_exit(ring)
    assert not locked(memory)


def test_register_buf_ring_memory_errors(ring):
    reg = u.BufReg()
    reg.ring, reg.ring_entries, reg.bgid = mmap.mmap(-1, 64), 8, 2
    with pytest.raises(ValueError, match="needs 128"):  # 8 entries of 16 bytes
        u.io_uring_register_buf_ring(ring, reg)
    assert not locked(reg.ring)
    reg.ring, reg.ring_entries, reg.flags = mmap.mmap(-1, 4096), 8, u.IOU_PBUF_RING_MMAP
    with pytest.raises(ValueError, match="IOU_PBUF_RING_MMAP"):
        u.io_uring_register_buf_ring(ring, reg)
    memory = mmap.mmap(-1, 4096)
    reg.ring, reg.flags = memoryview(memory)[16:], 0  # not page aligned: the kernel refuses
    with pytest.raises(OSError):
        u.io_uring_register_buf_ring(ring, reg)
    reg.ring = None
    assert not locked(memory)  # released


def test_register_buf_ring_bad_entries(ring):
    reg = u.BufReg()
    reg.ring_entries = 3  # not a power of two, and no memory
    with pytest.raises(OSError):
        u.io_uring_register_buf_ring(ring, reg)


# SyncCancelReg


def test_sync_cancel_reg_fields():
    reg = u.SyncCancelReg()
    assert (reg.addr, reg.fd, reg.flags, reg.opcode, reg.timeout) == (0, -1, 0, 0, None)
    reg.timeout = 1.5
    assert reg.timeout == 1.5
    reg.timeout = None
    assert reg.timeout is None
    for bad in (-1.0, float("nan"), 1e30):
        with pytest.raises(ValueError):
            reg.timeout = bad
    reg.addr, reg.fd, reg.flags, reg.opcode = 7, 3, u.IORING_ASYNC_CANCEL_FD, 4
    assert (reg.addr, reg.fd, reg.flags, reg.opcode) == (7, 3, u.IORING_ASYNC_CANCEL_FD, 4)


def test_register_sync_cancel(ring, cqe):
    reg = u.SyncCancelReg()
    reg.addr = 99
    with pytest.raises(FileNotFoundError):  # nothing with that user_data is pending
        u.io_uring_register_sync_cancel(ring, reg)
    reg.timeout = 0.01
    with pytest.raises(FileNotFoundError):
        u.io_uring_register_sync_cancel(ring, reg)


def test_register_sync_cancel_cancels(ring, cqe):
    import os

    r, w = os.pipe()
    try:
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_read(sqe, r, bytearray(1))
        sqe.user_data = 55
        assert u.io_uring_submit(ring) == 1
        reg = u.SyncCancelReg()
        reg.addr = 55
        reg.timeout = 1.0
        assert u.io_uring_register_sync_cancel(ring, reg) == 0
        assert u.io_uring_wait_cqe_timeout(ring, cqe, u.timespec(1)) == 0
        assert cqe[0].user_data == 55  # the cancelled read
        u.io_uring_cqe_seen(ring, cqe[0])
    finally:
        os.close(r)
        os.close(w)


# RegWait, MemRegionReg


def test_reg_wait_fields():
    wait = u.RegWait()
    assert (wait.timeout, wait.min_wait_usec, wait.flags) == (0.0, 0, 0)
    wait.timeout = 0.25
    wait.min_wait_usec = 10
    wait.flags = u.IORING_REG_WAIT_TS
    assert wait.timeout == 0.25
    assert len(wait.to_bytes()) == u.RegWait.SIZE == 64
    assert wait.to_bytes() != bytes(64)
    with pytest.raises(ValueError):
        wait.timeout = -1.0


def test_register_wait_reg_is_gone(ring):
    with pytest.raises(OSError):  # C liburing answers EINVAL for it
        u.io_uring_register_wait_reg(ring, u.RegWait(), 1)
    with pytest.raises(ValueError):
        u.io_uring_register_wait_reg(ring, u.RegWait(), 2)


def test_mem_region_reg_fields():
    reg = u.MemRegionReg()
    assert (reg.flags, reg.region, reg.region_size, reg.region_flags) == (0, None, 0, 0)
    memory = mmap.mmap(-1, 8192)
    reg.flags = 1
    reg.region = memory  # also the size and `IORING_MEM_REGION_TYPE_USER`
    assert (reg.flags, reg.region, reg.region_size) == (1, memory, 8192)
    assert reg.region_flags == u.IORING_MEM_REGION_TYPE_USER
    reg.region_size = 4096  # may be lowered
    assert reg.region_size == 4096
    reg.region = None  # the kernel allocates it
    assert (reg.region, reg.region_size, reg.region_flags) == (None, 0, 0)
    assert (reg.region_id, reg.region_mmap_offset) == (0, 0)
    with pytest.raises(TypeError):
        reg.region = b"read-only"


def test_submit_and_wait_reg(cqe):
    ring = u.Ring()
    u.io_uring_queue_init(8, ring, u.IORING_SETUP_R_DISABLED)  # the wait region is registered before enabling
    memory = mmap.mmap(-1, 4096)
    try:
        region = u.MemRegionReg()
        region.flags = u.IORING_MEM_REGION_REG_WAIT_ARG
        region.region = memory
        assert u.io_uring_register_region(ring, region) == 0
        del region
        assert locked(memory)  # until the exit: a region can not be unregistered
        assert u.io_uring_enable_rings(ring) == 0

        wait = u.RegWait()
        wait.timeout = 0.05
        wait.flags = u.IORING_REG_WAIT_TS
        memory[0 : u.RegWait.SIZE] = wait.to_bytes()
        with pytest.raises(OSError) as e:  # nothing to wait for: the 0.05 s run out
            u.io_uring_submit_and_wait_reg(ring, cqe, 1, 0)
        assert e.value.errno == 62

        nop(ring, 5)
        assert u.io_uring_submit_and_wait_reg(ring, cqe, 1, 0) >= 0  # the number of requests submitted
        assert cqe[0].user_data == 5
        u.io_uring_cqe_seen(ring, cqe[0])
    finally:
        u.io_uring_queue_exit(ring)
    assert not locked(memory)


def test_register_region_errors(ring):
    with pytest.raises(OSError):  # no memory given
        u.io_uring_register_region(ring, u.MemRegionReg())
    memory = mmap.mmap(-1, 4096)
    region = u.MemRegionReg()
    region.flags = u.IORING_MEM_REGION_REG_WAIT_ARG
    region.region = memory
    region.region_size = 8192
    with pytest.raises(ValueError, match="needs 8192"):
        u.io_uring_register_region(ring, region)
    region.region_size = 4096
    with pytest.raises(OSError):  # a wait-argument region only before the ring is enabled
        u.io_uring_register_region(ring, region)
    assert not locked(memory)  # refused: released


# Restriction


def test_restriction(cqe):
    ring = u.Ring()
    u.io_uring_queue_init(8, ring, u.IORING_SETUP_R_DISABLED)
    try:
        res = u.Restriction()
        assert len(res) == 0
        with pytest.raises(ValueError):
            u.io_uring_register_restrictions(ring, res)  # nothing allowed: refuse the empty list
        for i in range(6):  # grows past its first room
            res.add(u.IORING_RESTRICTION_SQE_OP, u.io_uring_op.IORING_OP_NOP)
        assert len(res) == 6
        assert u.io_uring_register_restrictions(ring, res) == 0
        assert u.io_uring_enable_rings(ring) == 0

        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_close(sqe, 99)  # not allowed
        sqe.user_data = 1
        assert u.io_uring_submit(ring) == 1
        u.io_uring_wait_cqe(ring, cqe)
        assert cqe[0].user_data == 1
        with pytest.raises(PermissionError):
            _ = cqe[0].res
        u.io_uring_cqe_seen(ring, cqe[0])

        nop(ring, 2)  # allowed
        assert u.io_uring_submit(ring) == 1
        u.io_uring_wait_cqe(ring, cqe)
        assert (cqe[0].user_data, cqe[0].res) == (2, 0)
        u.io_uring_cqe_seen(ring, cqe[0])
    finally:
        u.io_uring_queue_exit(ring)


def test_restriction_register_op_and_flags():
    res = u.Restriction()
    res.add(u.IORING_RESTRICTION_REGISTER_OP, 0)
    res.add(u.IORING_RESTRICTION_SQE_FLAGS_ALLOWED, u.IOSQE_IO_LINK)
    res.add(u.IORING_RESTRICTION_SQE_FLAGS_REQUIRED, 0)
    assert len(res) == 3
    with pytest.raises(OverflowError):
        res.add(u.IORING_RESTRICTION_SQE_OP, 256)


# Napi, ClockRegister


def test_napi(ring):
    napi = u.Napi()
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (0, False)
    napi.busy_poll_to = 50
    napi.prefer_busy_poll = True
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (50, True)
    try:
        assert u.io_uring_register_napi(ring, napi) == 0
    except OSError as e:  # kernel without CONFIG_NET_RX_BUSY_POLL
        pytest.skip(f"napi not supported: {e}")
    old = u.Napi()
    assert u.io_uring_unregister_napi(ring, old) == 0
    assert (old.busy_poll_to, old.prefer_busy_poll) == (50, True)  # what was registered comes back


def test_clock_register(ring, cqe):
    reg = u.ClockRegister()
    assert reg.clockid == 0
    reg.clockid = time.CLOCK_BOOTTIME
    assert reg.clockid == time.CLOCK_BOOTTIME
    assert u.io_uring_register_clock(ring, reg) == 0
    nop(ring, 1)
    u.io_uring_submit(ring)
    assert u.io_uring_wait_cqe_timeout(ring, cqe, u.timespec(1)) == 0
    u.io_uring_cqe_seen(ring, cqe[0])
    reg.clockid = 9999
    with pytest.raises(OSError):
        u.io_uring_register_clock(ring, reg)


# ZcrxIfqReg, Bpf


def test_zcrx_ifq_reg_fields():
    reg = u.ZcrxIfqReg()
    reg.if_idx, reg.if_rxq, reg.rq_entries, reg.flags, reg.rx_buf_len = 2, 1, 4096, 0, 0
    area, rq = mmap.mmap(-1, 8192), mmap.mmap(-1, 4096)
    reg.area, reg.area_flags, reg.area_dmabuf_fd = area, 0, 0
    reg.region = rq
    assert (reg.if_idx, reg.if_rxq, reg.rq_entries) == (2, 1, 4096)
    assert (reg.area, reg.area_len) == (area, 8192)
    assert (reg.region, reg.region_size, reg.region_flags) == (rq, 4096, u.IORING_MEM_REGION_TYPE_USER)
    reg.area, reg.region = None, None
    assert (reg.area, reg.area_len, reg.region, reg.region_size, reg.region_flags) == (None, 0, None, 0, 0)
    with pytest.raises(TypeError):
        reg.area = b"read-only"
    assert (reg.zcrx_id, reg.area_rq_area_token) == (0, 0)
    with pytest.raises(AttributeError):
        reg.zcrx_id = 1  # the kernel fills it in


def test_register_ifq_without_device(ring):
    reg = u.ZcrxIfqReg()
    reg.if_idx = 9999  # no such device (or no permission: zero-copy receive needs both)
    area, rq = mmap.mmap(-1, 4 * 4096), mmap.mmap(-1, 4096)
    reg.area, reg.region = area, rq
    with pytest.raises(OSError):
        u.io_uring_register_ifq(ring, reg)
    assert not locked(area)  # refused: both released
    assert not locked(rq)


def test_bpf_fields_and_register(ring):
    bpf = u.Bpf()
    assert (bpf.cmd_type, bpf.cmd_flags, bpf.opcode, bpf.filter_len, bpf.filter) == (1, 0, 0, 0, None)
    program = bytes(16)  # two instructions
    bpf.filter = program
    bpf.opcode = u.io_uring_op.IORING_OP_NOP
    assert bpf.filter_len == 2
    assert bpf.filter is program
    with pytest.raises(ValueError):
        bpf.filter = bytes(7)  # not whole instructions
    with pytest.raises(OSError):  # not a valid program (or not allowed for this task): the kernel refuses
        u.io_uring_register_bpf_filter(ring, bpf)



def test_register_bpf_filter_denies_nop(ring, cqe):
    # Kernel 7.0+ (`IORING_REGISTER_BPF_FILTER`): older kernels skip it (`UnsupportedError`, conftest.py).
    bpf = u.Bpf()
    bpf.opcode = u.io_uring_op.IORING_OP_NOP
    bpf.filter = struct.pack("HBBI", 0x06, 0, 0, 0)  # BPF_RET | BPF_K, 0: deny
    assert u.io_uring_register_bpf_filter(ring, bpf) == 0  # this ring only
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_nop(sqe)
    u.io_uring_submit_and_wait(ring, 1)
    u.io_uring_wait_cqe(ring, cqe)
    with pytest.raises(PermissionError):  # EACCES: the filter denied it
        _ = cqe[0].res
    u.io_uring_cqe_seen(ring, cqe[0])

def test_register_bpf_filter_task_refuses_an_empty_filter():
    # only the refusal is tested: a valid filter would restrict this whole test process
    with pytest.raises(OSError):
        u.io_uring_register_bpf_filter_task(u.Bpf())


def test_Query():
    query = u.Query()
    assert query.op == u.IO_URING_QUERY_OPCODES
    assert query.result == 0
    assert set(query.data.values()) == {0}  # nothing registered yet
    assert u.io_uring_register_query(query) == 0
    assert query.result == 0
    assert query.data["nr_request_opcodes"] > 0
    assert query.data["nr_register_opcodes"] > 0
    assert query.data["sqe_flags"] & u.IOSQE_IO_LINK

    scq = u.Query(u.IO_URING_QUERY_SCQ)
    assert u.io_uring_register_query(scq) == 0
    assert scq.data["hdr_size"] > 0
    assert scq.data["hdr_alignment"] > 0

    zcrx = u.Query(u.IO_URING_QUERY_ZCRX)
    assert zcrx.op == u.IO_URING_QUERY_ZCRX
    assert "rq_hdr_size" in zcrx.data
    assert u.io_uring_register_query(zcrx) == 0
    assert zcrx.data["nr_ctrl_opcodes"] >= 0

    with pytest.raises(ValueError):
        u.Query(99)
    with pytest.raises(TypeError):
        u.Query(1, 2)


def test_ZcrxCtrl(ring):
    ctrl = u.ZcrxCtrl(3, u.ZCRX_CTRL_EXPORT)
    assert (ctrl.zcrx_id, ctrl.op, ctrl.zcrx_fd) == (3, u.ZCRX_CTRL_EXPORT, 0)
    with pytest.raises(ValueError):
        u.ZcrxCtrl(0, 99)
    with pytest.raises(OSError):  # no zcrx instance registered on this ring
        u.io_uring_register_zcrx_ctrl(ring, ctrl)
