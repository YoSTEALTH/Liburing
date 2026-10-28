"""Register structs: `BufReg`, `SyncCancelReg`, `RegWait`, `MemRegionReg`, `Restriction`, `Napi`, `ClockRegister`,
`ZcrxIfqReg`, `Bpf`: their fields and the `io_uring_register_*` functions that take them."""

import gc
import mmap
import struct
import time
import weakref
import pytest
from liburing import *


def locked(memory):
    """Is `memory` (an `mmap`) locked by a view (`close()` refuses)? Closes it if not."""
    try:
        memory.close()
    except BufferError:
        return True
    return False


def nop(ring, user_data):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    return sqe


# BufReg


def test_buf_reg_fields():
    reg = BufReg()
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
        BufReg(1)


def test_register_buf_ring(ring):
    memory = mmap.mmap(-1, 8 * 16)  # 8 entries of 16 bytes
    reg = BufReg()
    reg.ring = memory
    reg.ring_entries = 8
    reg.bgid = 3
    assert io_uring_register_buf_ring(ring, reg) == 0
    assert io_uring_buf_ring_head(ring, 3) == 0
    assert locked(memory)  # the kernel uses it until the unregister
    assert io_uring_unregister_buf_ring(ring, 3) == 0
    assert not locked(memory)


def test_register_buf_ring_holds_memory(ring):
    memory = mmap.mmap(-1, 4096)
    alive = weakref.ref(memory)
    reg = BufReg()
    reg.ring, reg.ring_entries, reg.bgid = memory, 8, 4
    assert io_uring_register_buf_ring(ring, reg) == 0
    del memory, reg
    gc.collect()
    assert alive() is not None  # the ring holds it, not only `reg`
    assert io_uring_unregister_buf_ring(ring, 4) == 0
    gc.collect()
    assert alive() is None


def test_register_buf_ring_released_at_exit():
    ring = Ring()
    io_uring_queue_init(4, ring)
    memory = mmap.mmap(-1, 4096)
    reg = BufReg()
    reg.ring, reg.ring_entries, reg.bgid = memory, 8, 1
    assert io_uring_register_buf_ring(ring, reg) == 0
    io_uring_queue_exit(ring)
    assert not locked(memory)


def test_register_buf_ring_memory_errors(ring):
    reg = BufReg()
    reg.ring, reg.ring_entries, reg.bgid = mmap.mmap(-1, 64), 8, 2
    with pytest.raises(ValueError, match="needs 128"):  # 8 entries of 16 bytes
        io_uring_register_buf_ring(ring, reg)
    assert not locked(reg.ring)
    reg.ring, reg.ring_entries, reg.flags = mmap.mmap(-1, 4096), 8, IOU_PBUF_RING_MMAP
    with pytest.raises(ValueError, match="IOU_PBUF_RING_MMAP"):
        io_uring_register_buf_ring(ring, reg)
    memory = mmap.mmap(-1, 4096)
    reg.ring, reg.flags = memoryview(memory)[16:], 0  # not page aligned: the kernel refuses
    with pytest.raises(OSError):
        io_uring_register_buf_ring(ring, reg)
    reg.ring = None
    assert not locked(memory)  # released


def test_register_buf_ring_bad_entries(ring):
    reg = BufReg()
    reg.ring_entries = 3  # not a power of two, and no memory
    with pytest.raises(OSError):
        io_uring_register_buf_ring(ring, reg)


# SyncCancelReg


def test_sync_cancel_reg_fields():
    reg = SyncCancelReg()
    assert (reg.addr, reg.fd, reg.flags, reg.opcode, reg.timeout) == (0, -1, 0, 0, None)
    reg.timeout = 1.5
    assert reg.timeout == 1.5
    reg.timeout = None
    assert reg.timeout is None
    for bad in (-1.0, float("nan"), 1e30):
        with pytest.raises(ValueError):
            reg.timeout = bad
    reg.addr, reg.fd, reg.flags, reg.opcode = 7, 3, IORING_ASYNC_CANCEL_FD, 4
    assert (reg.addr, reg.fd, reg.flags, reg.opcode) == (7, 3, IORING_ASYNC_CANCEL_FD, 4)


def test_register_sync_cancel(ring, cqe):
    reg = SyncCancelReg()
    reg.addr = 99
    with pytest.raises(FileNotFoundError):  # nothing with that user_data is pending
        io_uring_register_sync_cancel(ring, reg)
    reg.timeout = 0.01
    with pytest.raises(FileNotFoundError):
        io_uring_register_sync_cancel(ring, reg)


def test_register_sync_cancel_cancels(ring, cqe):
    import os

    r, w = os.pipe()
    try:
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, r, bytearray(1))
        sqe.user_data = 55
        assert io_uring_submit(ring) == 1
        reg = SyncCancelReg()
        reg.addr = 55
        reg.timeout = 1.0
        assert io_uring_register_sync_cancel(ring, reg) == 0
        assert io_uring_wait_cqe_timeout(ring, cqe, timespec(1)) == 0
        assert cqe[0].user_data == 55  # the cancelled read
        io_uring_cqe_seen(ring, cqe[0])
    finally:
        os.close(r)
        os.close(w)


# RegWait, MemRegionReg


def test_reg_wait_fields():
    wait = RegWait()
    assert (wait.timeout, wait.min_wait_usec, wait.flags) == (0.0, 0, 0)
    wait.timeout = 0.25
    wait.min_wait_usec = 10
    wait.flags = IORING_REG_WAIT_TS
    assert wait.timeout == 0.25
    assert len(wait.to_bytes()) == RegWait.SIZE == 64
    assert wait.to_bytes() != bytes(64)
    with pytest.raises(ValueError):
        wait.timeout = -1.0


def test_register_wait_reg_is_gone(ring):
    with pytest.raises(OSError):  # C liburing answers EINVAL for it
        io_uring_register_wait_reg(ring, RegWait(), 1)
    with pytest.raises(ValueError):
        io_uring_register_wait_reg(ring, RegWait(), 2)


def test_mem_region_reg_fields():
    reg = MemRegionReg()
    assert (reg.flags, reg.region, reg.region_size, reg.region_flags) == (0, None, 0, 0)
    memory = mmap.mmap(-1, 8192)
    reg.flags = 1
    reg.region = memory  # also the size and `IORING_MEM_REGION_TYPE_USER`
    assert (reg.flags, reg.region, reg.region_size) == (1, memory, 8192)
    assert reg.region_flags == IORING_MEM_REGION_TYPE_USER
    reg.region_size = 4096  # may be lowered
    assert reg.region_size == 4096
    reg.region = None  # the kernel allocates it
    assert (reg.region, reg.region_size, reg.region_flags) == (None, 0, 0)
    assert (reg.region_id, reg.region_mmap_offset) == (0, 0)
    reg.region_flags, reg.region_id, reg.region_mmap_offset = IORING_MEM_REGION_TYPE_USER, 3, 4096
    assert (reg.region_flags, reg.region_id, reg.region_mmap_offset) == (IORING_MEM_REGION_TYPE_USER, 3, 4096)
    with pytest.raises(TypeError):
        reg.region = b"read-only"


def test_submit_and_wait_reg(cqe):
    ring = Ring()
    io_uring_queue_init(8, ring, IORING_SETUP_R_DISABLED)  # the wait region is registered before enabling
    memory = mmap.mmap(-1, 4096)
    try:
        region = MemRegionReg()
        region.flags = IORING_MEM_REGION_REG_WAIT_ARG
        region.region = memory
        assert io_uring_register_region(ring, region) == 0
        del region
        assert locked(memory)  # until the exit: a region can not be unregistered
        assert io_uring_enable_rings(ring) == 0

        wait = RegWait()
        wait.timeout = 0.05
        wait.flags = IORING_REG_WAIT_TS
        memory[0 : RegWait.SIZE] = wait.to_bytes()
        with pytest.raises(OSError) as e:  # nothing to wait for: the 0.05 s run out
            io_uring_submit_and_wait_reg(ring, cqe, 1, 0)
        assert e.value.errno == 62

        nop(ring, 5)
        assert io_uring_submit_and_wait_reg(ring, cqe, 1, 0) >= 0  # the number of requests submitted
        assert cqe[0].user_data == 5
        io_uring_cqe_seen(ring, cqe[0])
    finally:
        io_uring_queue_exit(ring)
    assert not locked(memory)


def test_register_region_errors(ring):
    with pytest.raises(OSError):  # no memory given
        io_uring_register_region(ring, MemRegionReg())
    memory = mmap.mmap(-1, 4096)
    region = MemRegionReg()
    region.flags = IORING_MEM_REGION_REG_WAIT_ARG
    region.region = memory
    region.region_size = 8192
    with pytest.raises(ValueError, match="needs 8192"):
        io_uring_register_region(ring, region)
    region.region_size = 4096
    with pytest.raises(OSError):  # a wait-argument region only before the ring is enabled
        io_uring_register_region(ring, region)
    assert not locked(memory)  # refused: released


# Restriction


def test_restriction(cqe):
    ring = Ring()
    io_uring_queue_init(8, ring, IORING_SETUP_R_DISABLED)
    try:
        res = Restriction()
        assert len(res) == 0
        with pytest.raises(ValueError):
            io_uring_register_restrictions(ring, res)  # nothing allowed: refuse the empty list
        for i in range(6):  # grows past its first room
            res.add(IORING_RESTRICTION_SQE_OP, io_uring_op.IORING_OP_NOP)
        assert len(res) == 6
        assert io_uring_register_restrictions(ring, res) == 0
        assert io_uring_enable_rings(ring) == 0

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, 99)  # not allowed
        sqe.user_data = 1
        assert io_uring_submit(ring) == 1
        io_uring_wait_cqe(ring, cqe)
        assert cqe[0].user_data == 1
        with pytest.raises(PermissionError):
            _ = cqe[0].res
        io_uring_cqe_seen(ring, cqe[0])

        nop(ring, 2)  # allowed
        assert io_uring_submit(ring) == 1
        io_uring_wait_cqe(ring, cqe)
        assert (cqe[0].user_data, cqe[0].res) == (2, 0)
        io_uring_cqe_seen(ring, cqe[0])
    finally:
        io_uring_queue_exit(ring)


def test_restriction_register_op_and_flags():
    res = Restriction()
    res.add(IORING_RESTRICTION_REGISTER_OP, 0)
    res.add(IORING_RESTRICTION_SQE_FLAGS_ALLOWED, IOSQE_IO_LINK)
    res.add(IORING_RESTRICTION_SQE_FLAGS_REQUIRED, 0)
    assert len(res) == 3
    with pytest.raises(OverflowError):
        res.add(IORING_RESTRICTION_SQE_OP, 256)


# Napi, ClockRegister


def test_napi(ring):
    napi = Napi()
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (0, False)
    napi.busy_poll_to = 50
    napi.prefer_busy_poll = True
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (50, True)
    try:
        assert io_uring_register_napi(ring, napi) == 0
    except OSError as e:  # kernel without CONFIG_NET_RX_BUSY_POLL
        pytest.skip(f"napi not supported: {e}")
    old = Napi()
    assert io_uring_unregister_napi(ring, old) == 0
    assert (old.busy_poll_to, old.prefer_busy_poll) == (50, True)  # what was registered comes back


def test_clock_register(ring, cqe):
    reg = ClockRegister()
    assert reg.clockid == 0
    reg.clockid = time.CLOCK_BOOTTIME
    assert reg.clockid == time.CLOCK_BOOTTIME
    assert io_uring_register_clock(ring, reg) == 0
    nop(ring, 1)
    io_uring_submit(ring)
    assert io_uring_wait_cqe_timeout(ring, cqe, timespec(1)) == 0
    io_uring_cqe_seen(ring, cqe[0])
    reg.clockid = 9999
    with pytest.raises(OSError):
        io_uring_register_clock(ring, reg)


# ZcrxIfqReg, Bpf


def test_zcrx_ifq_reg_fields():
    reg = ZcrxIfqReg()
    reg.if_idx, reg.if_rxq, reg.rq_entries, reg.flags, reg.rx_buf_len = 2, 1, 4096, 1, 4096
    area, rq = mmap.mmap(-1, 8192), mmap.mmap(-1, 4096)
    reg.area, reg.area_flags, reg.area_dmabuf_fd = area, 1, 5
    reg.region = rq
    assert (reg.if_idx, reg.if_rxq, reg.rq_entries, reg.flags, reg.rx_buf_len) == (2, 1, 4096, 1, 4096)
    assert (reg.area, reg.area_len, reg.area_flags, reg.area_dmabuf_fd) == (area, 8192, 1, 5)
    assert (reg.region, reg.region_size, reg.region_flags) == (rq, 4096, IORING_MEM_REGION_TYPE_USER)
    reg.area_len, reg.region_size, reg.region_flags = 4096, 2048, 0  # may be lowered
    assert (reg.area_len, reg.region_size, reg.region_flags) == (4096, 2048, 0)
    reg.area, reg.region = None, None
    assert (reg.area, reg.area_len, reg.region, reg.region_size, reg.region_flags) == (None, 0, None, 0, 0)
    with pytest.raises(TypeError):
        reg.area = b"read-only"
    assert (reg.zcrx_id, reg.area_rq_area_token) == (0, 0)
    with pytest.raises(AttributeError):
        reg.zcrx_id = 1  # the kernel fills it in


def test_register_ifq_without_device(ring):
    reg = ZcrxIfqReg()
    reg.if_idx = 9999  # no such device (or no permission: zero-copy receive needs both)
    area, rq = mmap.mmap(-1, 4 * 4096), mmap.mmap(-1, 4096)
    reg.area, reg.region = area, rq
    with pytest.raises(OSError):
        io_uring_register_ifq(ring, reg)
    assert not locked(area)  # refused: both released
    assert not locked(rq)


def test_register_ifq_region_too_short(ring):
    reg = ZcrxIfqReg()
    area, rq = mmap.mmap(-1, 4 * 4096), mmap.mmap(-1, 4096)
    reg.area, reg.region = area, rq
    reg.region_size = 8192  # more than `rq` has: refused after `area` was locked
    with pytest.raises(ValueError, match="needs 8192"):
        io_uring_register_ifq(ring, reg)
    assert not locked(area)  # released again
    assert not locked(rq)


def test_bpf_fields_and_register(ring):
    bpf = Bpf()
    assert (bpf.cmd_type, bpf.cmd_flags, bpf.opcode, bpf.filter_len, bpf.filter) == (1, 0, 0, 0, None)
    assert (bpf.flags, bpf.pdu_size) == (0, 0)
    bpf.cmd_type, bpf.cmd_flags, bpf.flags, bpf.pdu_size = 2, 3, 4, 5
    assert (bpf.cmd_type, bpf.cmd_flags, bpf.flags, bpf.pdu_size) == (2, 3, 4, 5)
    bpf.cmd_type, bpf.cmd_flags, bpf.flags, bpf.pdu_size = 1, 0, 0, 0  # back to a filter, for the register below
    program = bytes(16)  # two instructions
    bpf.filter = program
    bpf.opcode = io_uring_op.IORING_OP_NOP
    assert bpf.filter_len == 2
    assert bpf.filter is program
    with pytest.raises(ValueError):
        bpf.filter = bytes(7)  # not whole instructions
    with pytest.raises(OSError):  # not a valid program (or not allowed for this task): the kernel refuses
        io_uring_register_bpf_filter(ring, bpf)


def test_register_bpf_filter_denies_nop(ring, cqe):
    # Kernel 7.0+ (`IORING_REGISTER_BPF_FILTER`): older kernels skip it (`UnsupportedError`, conftest.py).
    bpf = Bpf()
    bpf.opcode = io_uring_op.IORING_OP_NOP
    bpf.filter = struct.pack("HBBI", 0x06, 0, 0, 0)  # BPF_RET | BPF_K, 0: deny
    assert io_uring_register_bpf_filter(ring, bpf) == 0  # this ring only
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    io_uring_submit_and_wait(ring, 1)
    io_uring_wait_cqe(ring, cqe)
    with pytest.raises(PermissionError):  # EACCES: the filter denied it
        _ = cqe[0].res
    io_uring_cqe_seen(ring, cqe[0])


def test_register_bpf_filter_task_refuses_an_empty_filter():
    # only the refusal is tested: a valid filter would restrict this whole test process
    with pytest.raises(OSError):
        io_uring_register_bpf_filter_task(Bpf())


def test_Query():
    query = Query()
    assert query.op == IO_URING_QUERY_OPCODES
    assert query.result == 0
    assert set(query.data.values()) == {0}  # nothing registered yet
    assert io_uring_register_query(query) == 0
    assert query.result == 0
    assert query.data["nr_request_opcodes"] > 0
    assert query.data["nr_register_opcodes"] > 0
    assert query.data["sqe_flags"] & IOSQE_IO_LINK

    scq = Query(IO_URING_QUERY_SCQ)
    assert io_uring_register_query(scq) == 0
    assert scq.data["hdr_size"] > 0
    assert scq.data["hdr_alignment"] > 0

    zcrx = Query(IO_URING_QUERY_ZCRX)
    assert zcrx.op == IO_URING_QUERY_ZCRX
    assert "rq_hdr_size" in zcrx.data
    assert io_uring_register_query(zcrx) == 0
    assert zcrx.data["nr_ctrl_opcodes"] >= 0

    with pytest.raises(ValueError):
        Query(99)
    with pytest.raises(TypeError):
        Query(1, 2)


def test_ZcrxCtrl(ring):
    ctrl = ZcrxCtrl(3, ZCRX_CTRL_EXPORT)
    assert (ctrl.zcrx_id, ctrl.op, ctrl.zcrx_fd) == (3, ZCRX_CTRL_EXPORT, 0)
    with pytest.raises(ValueError):
        ZcrxCtrl(0, 99)
    with pytest.raises(OSError):  # no zcrx instance registered on this ring
        io_uring_register_zcrx_ctrl(ring, ctrl)
