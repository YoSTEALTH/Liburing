"""Register structs: `BufReg`, `SyncCancelReg`, `RegWait`, `MemRegionReg`, `Restriction`, `Napi`, `ClockRegister`,
`ZcrxIfqReg`, `Bpf`: their fields and the `io_uring_register_*` functions that take them."""

import ctypes
import mmap
import time
import pytest
import liburing as L


def address(buf):
    return ctypes.addressof(ctypes.c_char.from_buffer(buf))


def nop(ring, user_data):
    sqe = L.io_uring_get_sqe(ring)
    L.io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    return sqe


# BufReg


def test_buf_reg_fields():
    reg = L.BufReg()
    assert (reg.ring_addr, reg.ring_entries, reg.bgid, reg.flags, reg.min_left) == (0, 0, 0, 0, 0)
    reg.ring_addr, reg.ring_entries, reg.bgid, reg.flags, reg.min_left = 1, 8, 3, 0, 2
    assert (reg.ring_addr, reg.ring_entries, reg.bgid, reg.flags, reg.min_left) == (1, 8, 3, 0, 2)
    with pytest.raises(OverflowError):
        reg.bgid = 2**16
    with pytest.raises(TypeError):
        L.BufReg(1)


def test_register_buf_ring(ring):
    memory = mmap.mmap(-1, 8 * 16)  # 8 entries of 16 bytes
    reg = L.BufReg()
    reg.ring_addr = address(memory)
    reg.ring_entries = 8
    reg.bgid = 3
    assert L.io_uring_register_buf_ring(ring, reg) == 0
    assert L.io_uring_buf_ring_head(ring, 3) == 0
    assert L.io_uring_unregister_buf_ring(ring, 3) == 0


def test_register_buf_ring_bad_entries(ring):
    reg = L.BufReg()
    reg.ring_entries = 3  # not a power of two, and no memory
    with pytest.raises(OSError):
        L.io_uring_register_buf_ring(ring, reg)


# SyncCancelReg


def test_sync_cancel_reg_fields():
    reg = L.SyncCancelReg()
    assert (reg.addr, reg.fd, reg.flags, reg.opcode, reg.timeout) == (0, -1, 0, 0, None)
    reg.timeout = 1.5
    assert reg.timeout == 1.5
    reg.timeout = None
    assert reg.timeout is None
    for bad in (-1.0, float("nan"), 1e30):
        with pytest.raises(ValueError):
            reg.timeout = bad
    reg.addr, reg.fd, reg.flags, reg.opcode = 7, 3, L.IORING_ASYNC_CANCEL_FD, 4
    assert (reg.addr, reg.fd, reg.flags, reg.opcode) == (7, 3, L.IORING_ASYNC_CANCEL_FD, 4)


def test_register_sync_cancel(ring, cqe):
    reg = L.SyncCancelReg()
    reg.addr = 99
    with pytest.raises(FileNotFoundError):  # nothing with that user_data is pending
        L.io_uring_register_sync_cancel(ring, reg)
    reg.timeout = 0.01
    with pytest.raises(FileNotFoundError):
        L.io_uring_register_sync_cancel(ring, reg)


def test_register_sync_cancel_cancels(ring, cqe):
    import os

    r, w = os.pipe()
    try:
        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_read(sqe, r, bytearray(1))
        sqe.user_data = 55
        assert L.io_uring_submit(ring) == 1
        reg = L.SyncCancelReg()
        reg.addr = 55
        reg.timeout = 1.0
        assert L.io_uring_register_sync_cancel(ring, reg) == 0
        assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(1)) == 0
        assert cqe[0].user_data == 55  # the cancelled read
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        os.close(r)
        os.close(w)


# RegWait, MemRegionReg


def test_reg_wait_fields():
    wait = L.RegWait()
    assert (wait.timeout, wait.min_wait_usec, wait.flags) == (0.0, 0, 0)
    wait.timeout = 0.25
    wait.min_wait_usec = 10
    wait.flags = L.IORING_REG_WAIT_TS
    assert wait.timeout == 0.25
    assert len(wait.to_bytes()) == L.RegWait.SIZE == 64
    assert wait.to_bytes() != bytes(64)
    with pytest.raises(ValueError):
        wait.timeout = -1.0


def test_register_wait_reg_is_gone(ring):
    with pytest.raises(OSError):  # C liburing answers EINVAL for it
        L.io_uring_register_wait_reg(ring, L.RegWait(), 1)
    with pytest.raises(ValueError):
        L.io_uring_register_wait_reg(ring, L.RegWait(), 2)


def test_mem_region_reg_fields():
    reg = L.MemRegionReg()
    assert (reg.flags, reg.region_user_addr, reg.region_size, reg.region_flags) == (0, 0, 0, 0)
    reg.flags = 1
    reg.region_user_addr = 4096
    reg.region_size = 8192
    reg.region_flags = 1
    assert (reg.flags, reg.region_user_addr, reg.region_size, reg.region_flags) == (1, 4096, 8192, 1)
    assert (reg.region_id, reg.region_mmap_offset) == (0, 0)


def test_submit_and_wait_reg(cqe):
    ring = L.Ring()
    L.io_uring_queue_init(8, ring, L.IORING_SETUP_R_DISABLED)  # the wait region is registered before enabling
    memory = mmap.mmap(-1, 4096)
    try:
        region = L.MemRegionReg()
        region.flags = L.IORING_MEM_REGION_REG_WAIT_ARG
        region.region_user_addr = address(memory)
        region.region_size = len(memory)
        region.region_flags = L.IORING_MEM_REGION_TYPE_USER
        assert L.io_uring_register_region(ring, region) == 0
        assert L.io_uring_enable_rings(ring) == 0

        wait = L.RegWait()
        wait.timeout = 0.05
        wait.flags = L.IORING_REG_WAIT_TS
        memory[0 : L.RegWait.SIZE] = wait.to_bytes()
        with pytest.raises(OSError) as e:  # nothing to wait for: the 0.05 s run out
            L.io_uring_submit_and_wait_reg(ring, cqe, 1, 0)
        assert e.value.errno == 62

        nop(ring, 5)
        assert L.io_uring_submit_and_wait_reg(ring, cqe, 1, 0) >= 0  # the number of requests submitted
        assert cqe[0].user_data == 5
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        L.io_uring_queue_exit(ring)


def test_register_region_errors(ring):
    with pytest.raises(OSError):  # no memory given
        L.io_uring_register_region(ring, L.MemRegionReg())


# Restriction


def test_restriction(cqe):
    ring = L.Ring()
    L.io_uring_queue_init(8, ring, L.IORING_SETUP_R_DISABLED)
    try:
        res = L.Restriction()
        assert len(res) == 0
        with pytest.raises(ValueError):
            L.io_uring_register_restrictions(ring, res)  # nothing allowed: refuse the empty list
        for i in range(6):  # grows past its first room
            res.add(L.IORING_RESTRICTION_SQE_OP, L.io_uring_op.IORING_OP_NOP)
        assert len(res) == 6
        assert L.io_uring_register_restrictions(ring, res) == 0
        assert L.io_uring_enable_rings(ring) == 0

        sqe = L.io_uring_get_sqe(ring)
        L.io_uring_prep_close(sqe, 99)  # not allowed
        sqe.user_data = 1
        assert L.io_uring_submit(ring) == 1
        L.io_uring_wait_cqe(ring, cqe)
        assert cqe[0].user_data == 1
        with pytest.raises(PermissionError):
            cqe[0].res
        L.io_uring_cqe_seen(ring, cqe[0])

        nop(ring, 2)  # allowed
        assert L.io_uring_submit(ring) == 1
        L.io_uring_wait_cqe(ring, cqe)
        assert (cqe[0].user_data, cqe[0].res) == (2, 0)
        L.io_uring_cqe_seen(ring, cqe[0])
    finally:
        L.io_uring_queue_exit(ring)


def test_restriction_register_op_and_flags():
    res = L.Restriction()
    res.add(L.IORING_RESTRICTION_REGISTER_OP, 0)
    res.add(L.IORING_RESTRICTION_SQE_FLAGS_ALLOWED, L.IOSQE_IO_LINK)
    res.add(L.IORING_RESTRICTION_SQE_FLAGS_REQUIRED, 0)
    assert len(res) == 3
    with pytest.raises(OverflowError):
        res.add(L.IORING_RESTRICTION_SQE_OP, 256)


# Napi, ClockRegister


def test_napi(ring):
    napi = L.Napi()
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (0, False)
    napi.busy_poll_to = 50
    napi.prefer_busy_poll = True
    assert (napi.busy_poll_to, napi.prefer_busy_poll) == (50, True)
    try:
        assert L.io_uring_register_napi(ring, napi) == 0
    except OSError as e:  # kernel without CONFIG_NET_RX_BUSY_POLL
        pytest.skip(f"napi not supported: {e}")
    old = L.Napi()
    assert L.io_uring_unregister_napi(ring, old) == 0
    assert (old.busy_poll_to, old.prefer_busy_poll) == (50, True)  # what was registered comes back


def test_clock_register(ring, cqe):
    reg = L.ClockRegister()
    assert reg.clockid == 0
    reg.clockid = time.CLOCK_BOOTTIME
    assert reg.clockid == time.CLOCK_BOOTTIME
    assert L.io_uring_register_clock(ring, reg) == 0
    nop(ring, 1)
    L.io_uring_submit(ring)
    assert L.io_uring_wait_cqe_timeout(ring, cqe, L.timespec(1)) == 0
    L.io_uring_cqe_seen(ring, cqe[0])
    reg.clockid = 9999
    with pytest.raises(OSError):
        L.io_uring_register_clock(ring, reg)


# ZcrxIfqReg, Bpf


def test_zcrx_ifq_reg_fields():
    reg = L.ZcrxIfqReg()
    reg.if_idx, reg.if_rxq, reg.rq_entries, reg.flags, reg.rx_buf_len = 2, 1, 4096, 0, 0
    reg.area_addr, reg.area_len, reg.area_flags, reg.area_dmabuf_fd = 4096, 8192, 0, 0
    reg.region_user_addr, reg.region_size, reg.region_flags = 4096, 4096, 1
    assert (reg.if_idx, reg.if_rxq, reg.rq_entries) == (2, 1, 4096)
    assert (reg.area_addr, reg.area_len) == (4096, 8192)
    assert (reg.zcrx_id, reg.area_rq_area_token) == (0, 0)
    with pytest.raises(AttributeError):
        reg.zcrx_id = 1  # the kernel fills it in


def test_register_ifq_without_device(ring):
    reg = L.ZcrxIfqReg()
    reg.if_idx = 9999  # no such device (or no permission: zero-copy receive needs both)
    with pytest.raises(OSError):
        L.io_uring_register_ifq(ring, reg)


def test_bpf_fields_and_register(ring):
    bpf = L.Bpf()
    assert (bpf.cmd_type, bpf.cmd_flags, bpf.opcode, bpf.filter_len, bpf.filter) == (1, 0, 0, 0, None)
    program = bytes(16)  # two instructions
    bpf.filter = program
    bpf.opcode = L.io_uring_op.IORING_OP_NOP
    assert bpf.filter_len == 2
    assert bpf.filter is program
    with pytest.raises(ValueError):
        bpf.filter = bytes(7)  # not whole instructions
    with pytest.raises(OSError):  # not a valid program (or not allowed for this task): the kernel refuses
        L.io_uring_register_bpf_filter(ring, bpf)


def test_register_bpf_filter_task_refuses_an_empty_filter():
    # only the refusal is tested: a valid filter would restrict this whole test process
    with pytest.raises(OSError):
        L.io_uring_register_bpf_filter_task(L.Bpf())


def test_Query():
    query = L.Query()
    assert query.op == L.IO_URING_QUERY_OPCODES
    assert query.result == 0
    assert set(query.data.values()) == {0}  # nothing registered yet
    assert L.io_uring_register_query(query) == 0
    assert query.result == 0
    assert query.data["nr_request_opcodes"] > 0
    assert query.data["nr_register_opcodes"] > 0
    assert query.data["sqe_flags"] & L.IOSQE_IO_LINK

    scq = L.Query(L.IO_URING_QUERY_SCQ)
    assert L.io_uring_register_query(scq) == 0
    assert scq.data["hdr_size"] > 0
    assert scq.data["hdr_alignment"] > 0

    zcrx = L.Query(L.IO_URING_QUERY_ZCRX)
    assert zcrx.op == L.IO_URING_QUERY_ZCRX
    assert "rq_hdr_size" in zcrx.data
    assert L.io_uring_register_query(zcrx) == 0
    assert zcrx.data["nr_ctrl_opcodes"] >= 0

    with pytest.raises(ValueError):
        L.Query(99)
    with pytest.raises(TypeError):
        L.Query(1, 2)


def test_ZcrxCtrl(ring):
    ctrl = L.ZcrxCtrl(3, L.ZCRX_CTRL_EXPORT)
    assert (ctrl.zcrx_id, ctrl.op, ctrl.zcrx_fd) == (3, L.ZCRX_CTRL_EXPORT, 0)
    with pytest.raises(ValueError):
        L.ZcrxCtrl(0, 99)
    with pytest.raises(OSError):  # no zcrx instance registered on this ring
        L.io_uring_register_zcrx_ctrl(ring, ctrl)
