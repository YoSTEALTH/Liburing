"""The ring's table of in-flight requests: the kernel sees an entry's index as `user_data`, Python sees the
user's value (any 64 bits), and requests naming another one (cancel, timeout / poll remove) are translated."""

import errno
import os

import liburing as u


def nop(ring, user_data, flags=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_nop(sqe)
    sqe.user_data = user_data
    sqe.flags = flags
    return sqe


def timeout(ring, user_data, seconds=30, count=0, flags=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_timeout(sqe, u.timespec(seconds), count, flags)
    sqe.user_data = user_data
    return sqe


def reap(ring, cqe, n=1):
    """`(user_data, res or -errno)` of the next `n` completions, consumed with `io_uring_cqe_seen`."""
    out = []
    for _ in range(n):
        assert u.io_uring_wait_cqe(ring, cqe) == 0
        entry = cqe[0]
        try:
            res = entry.res
        except OSError as e:
            res = -e.errno
        out.append((entry.user_data, res))
        u.io_uring_cqe_seen(ring, entry)
    return out


def test_user_data_all_64_bits(ring, cqe):
    values = [0, 1, 2, 2**63, 2**64 - 1, 0]
    for v in values:
        nop(ring, v)
    assert u.io_uring_submit_and_wait(ring, len(values)) == len(values)
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    assert [cqe.user_data_at(i) for i in range(len(values))] == values
    assert [cqe[i].user_data for i in range(len(values))] == values
    assert u.io_uring_cqe_get_data64(cqe[4]) == 2**64 - 1
    batch = u.CqeBatch(8)
    assert u.io_uring_peek_batch_cqe(ring, batch) == len(values)
    assert [c.user_data for c in batch] == values
    u.io_uring_cq_advance(ring, len(values))


def test_kernel_sees_index(ring, cqe):
    sqe = nop(ring, 2**64 - 1)
    assert sqe.user_data == 2**64 - 1  # the user's value until the submit
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert 2 <= sqe.user_data < 2**32  # then the slot holds the entry's index (0 and 1 are reserved)
    assert reap(ring, cqe) == [(2**64 - 1, 0)]


def test_entries_reused(ring, cqe):
    # many rounds, each value read back right: freed entries are handed out again
    for r in range(200):
        for i in range(8):
            nop(ring, r * 8 + i)
        assert u.io_uring_submit_and_wait(ring, 8) == 8
        assert u.io_uring_peek_cqe(ring, cqe) == 0
        assert sorted(cqe.user_data_at(i) for i in range(8)) == list(range(r * 8, r * 8 + 8))
        u.io_uring_cq_advance(ring, 8)


def test_template_user_data(ring, cqe):
    tmpl = u.Sqe()
    u.io_uring_prep_nop(tmpl)
    tmpl.user_data = 42
    for _ in range(3):
        assert u.put_sqe(ring, tmpl)
    assert u.io_uring_submit_and_wait(ring, 3) == 3
    assert tmpl.user_data == 42  # copied in: the template keeps the user's value
    assert reap(ring, cqe, 3) == [(42, 0)] * 3


def test_cancel_in_same_submit(ring, cqe):
    timeout(ring, 5)
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_cancel64(sqe, 5)
    sqe.user_data = 6
    assert u.io_uring_submit(ring) == 2
    assert sorted(reap(ring, cqe, 2)) == [(5, -errno.ECANCELED), (6, 0)]


def test_cancel_same_user_data_as_target(ring, cqe):
    # the cancel's own entry (same user value) is not its target
    timeout(ring, 7)
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_cancel64(sqe, 7)
    sqe.user_data = 7
    assert u.io_uring_submit(ring) == 2
    assert sorted(reap(ring, cqe, 2)) == [(7, -errno.ECANCELED), (7, 0)]


def test_cancel_no_match(ring, cqe):
    nop(ring, 1)
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert reap(ring, cqe) == [(1, 0)]  # completed and consumed: its entry is gone
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_cancel64(sqe, 1)
    sqe.user_data = 2
    assert u.io_uring_submit(ring) == 1
    assert reap(ring, cqe) == [(2, -errno.ENOENT)]


def test_duplicate_user_data(ring, cqe):
    timeout(ring, 8)
    timeout(ring, 8)
    assert u.io_uring_submit(ring) == 2
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_timeout_remove(sqe, 8)
    sqe.user_data = 9
    assert u.io_uring_submit(ring) == 1
    assert sorted(reap(ring, cqe, 2)) == [(8, -errno.ECANCELED), (9, 0)]  # one of the two
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_timeout_remove(sqe, 8)
    sqe.user_data = 9
    assert u.io_uring_submit(ring) == 1
    assert sorted(reap(ring, cqe, 2)) == [(8, -errno.ECANCELED), (9, 0)]  # then the other


def test_sync_cancel_translated(ring, cqe):
    timeout(ring, 2**64 - 2)
    assert u.io_uring_submit(ring) == 1
    reg = u.SyncCancelReg()
    reg.addr = 2**64 - 2
    assert u.io_uring_register_sync_cancel(ring, reg) == 0
    assert reg.addr == 2**64 - 2  # the user's value, not the entry's index
    assert reap(ring, cqe) == [(2**64 - 2, -errno.ECANCELED)]


def test_multishot_keeps_entry(ring, cqe):
    timeout(ring, 77, seconds=0.001, count=3, flags=u.IORING_TIMEOUT_MULTISHOT)
    assert u.io_uring_submit(ring) == 1
    # each completion but the last has `IORING_CQE_F_MORE`: the entry stays until the last
    assert reap(ring, cqe, 3) == [(77, -errno.ETIME)] * 3
    nop(ring, 78)  # may take the freed entry
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert reap(ring, cqe) == [(78, 0)]


def test_skip_success(ring, cqe):
    nop(ring, 5, u.IOSQE_CQE_SKIP_SUCCESS)  # no completion, no entry
    nop(ring, 6)
    assert u.io_uring_submit_and_wait(ring, 1) == 2
    assert reap(ring, cqe) == [(6, 0)]
    assert u.io_uring_cq_ready(ring) == 0


def test_poll_update_user_data_same_submit(ring, cqe):
    r, w = os.pipe()
    try:
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_poll_add(sqe, r, 1)  # POLLIN
        sqe.user_data = 20
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_poll_update(sqe, 20, 21, 0, u.IORING_POLL_UPDATE_USER_DATA)
        sqe.user_data = 22
        assert u.io_uring_submit(ring) == 2
        assert reap(ring, cqe) == [(22, 0)]
        os.write(w, b"x")
        assert reap(ring, cqe) == [(21, 1)]  # the poll, under its new user_data
    finally:
        os.close(r)
        os.close(w)


def test_exit_and_init_again(cqe):
    ring = u.Ring()
    for _ in range(2):
        u.io_uring_queue_init(8, ring)
        timeout(ring, 3)  # in flight at the exit
        nop(ring, 4)
        assert u.io_uring_submit_and_wait(ring, 1) == 2
        assert reap(ring, cqe) == [(4, 0)]
        u.io_uring_queue_exit(ring)



def test_cancel_all_by_user_data_is_first_match(ring, cqe):
    import socket

    a, b = socket.socketpair()
    try:
        for _ in range(2):  # two requests with one user_data
            sqe = u.io_uring_get_sqe(ring)
            u.io_uring_prep_recv(sqe, a.fileno(), bytearray(4))
            sqe.user_data = 5
        assert u.io_uring_submit(ring) == 2
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_cancel64(sqe, 5, u.IORING_ASYNC_CANCEL_ALL)
        sqe.user_data = 6
        assert u.io_uring_submit(ring) == 1
        got = sorted(reap(ring, cqe, 2))
        assert got == [(5, -errno.ECANCELED), (6, 1)]  # the first one only (documented)
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_cancel_fd(sqe, a.fileno(), u.IORING_ASYNC_CANCEL_ALL)  # a group: by file
        sqe.user_data = 7
        assert u.io_uring_submit(ring) == 1
        assert sorted(reap(ring, cqe, 2)) == [(5, -errno.ECANCELED), (7, 1)]
    finally:
        a.close()
        b.close()
