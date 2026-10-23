"""Messages (`io_uring_prep_msg_ring*`) with the in-flight table: sent with bit 63 set, so the target reports the
sender's `data` and never takes a message for one of its own requests."""

import errno
import threading

import pytest

import liburing as u


def send(ring, target, data, length=0, user_data=0):
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_msg_ring(sqe, target.ring_fd, length, data)
    sqe.user_data = user_data
    return sqe


def test_data_range(ring, cqe):
    sqe = u.io_uring_get_sqe(ring)
    with pytest.raises(ValueError):
        u.io_uring_prep_msg_ring(sqe, ring.ring_fd, 0, 2**63)
    u.io_uring_prep_msg_ring(sqe, ring.ring_fd, 3, 2**63 - 1)
    sqe.user_data = 2**64 - 1  # the sender's own request: all 64 bits, as any request
    assert u.io_uring_submit_and_wait(ring, 2) == 1
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    got = sorted((cqe[i].user_data, cqe[i].res) for i in range(u.io_uring_cq_ready(ring)))
    u.io_uring_cq_advance(ring, 2)
    assert got == [(2**63 - 1, 3), (2**64 - 1, 0)]  # the message, the sender's completion


def test_message_never_taken_for_a_request(ring, cqe):
    # messages whose `data` equals the index of a request in flight: read as messages, and consuming them
    # leaves those requests' entries alone
    for i in range(16):
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_timeout(sqe, u.timespec(30), 0)
        sqe.user_data = 1000 + i
    assert u.io_uring_submit(ring) == 16
    for data in range(32):
        send(ring, ring, data, data, user_data=500)
    assert u.io_uring_submit_and_wait(ring, 64) == 32
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    n = u.io_uring_cq_ready(ring)
    got = sorted((cqe.user_data_at(i), cqe.res_at(i)) for i in range(n))
    u.io_uring_cq_advance(ring, n)
    assert got == sorted([(d, d) for d in range(32)] + [(500, 0)] * 32)
    for i in range(16):  # the timeouts still have their own user_data
        sqe = u.io_uring_get_sqe(ring)
        u.io_uring_prep_timeout_remove(sqe, 1000 + i)
        sqe.user_data = 2000 + i
    assert u.io_uring_submit_and_wait(ring, 32) == 16
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    n = u.io_uring_cq_ready(ring)
    got = sorted(cqe.user_data_at(i) for i in range(n))
    u.io_uring_cq_advance(ring, n)
    assert got == list(range(1000, 1016)) + list(range(2000, 2016))


def test_template_message(ring, cqe):
    tmpl = u.Sqe()
    u.io_uring_prep_msg_ring(tmpl, ring.ring_fd, 1, 42)
    tmpl.user_data = 7
    for _ in range(2):  # the tag is in the SQE: every copy is a message
        assert u.put_sqe(ring, tmpl)
    assert u.io_uring_submit_and_wait(ring, 4) == 2
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    got = sorted((cqe[i].user_data, cqe[i].res) for i in range(4))
    u.io_uring_cq_advance(ring, 4)
    assert got == [(7, 0), (7, 0), (42, 1), (42, 1)]


def test_message_between_threads(cqe):
    ready, done = threading.Event(), threading.Event()
    box = {}

    def receiver():
        r = u.Ring()
        u.io_uring_queue_init(8, r)
        box["ring"] = r
        c = u.Cqe()
        ready.set()
        got = []
        for _ in range(3):
            assert u.io_uring_wait_cqe_timeout(r, c, u.timespec(2)) == 0
            got.append((c[0].user_data, c[0].res))
            u.io_uring_cqe_seen(r, c[0])
        box["got"] = got
        done.wait(2)
        u.io_uring_queue_exit(r)

    t = threading.Thread(target=receiver)
    t.start()
    try:
        assert ready.wait(2)
        target = box["ring"]
        ring = u.Ring()
        u.io_uring_queue_init(8, ring)
        try:
            for i in range(3):
                send(ring, target, 2**62 + i, i, user_data=i)
            assert u.io_uring_submit_and_wait(ring, 3) == 3
            u.io_uring_peek_cqe(ring, cqe)
            u.io_uring_cq_advance(ring, 3)
        finally:
            u.io_uring_queue_exit(ring)
    finally:
        done.set()
        t.join()
    assert sorted(box["got"]) == [(2**62 + i, i) for i in range(3)]


def test_cqe_skip_message(ring, cqe):
    # `IORING_MSG_RING_CQE_SKIP`: no completion on the target; the sender's still comes
    sqe = u.io_uring_get_sqe(ring)
    u.io_uring_prep_msg_ring(sqe, ring.ring_fd, 0, 5, u.IORING_MSG_RING_CQE_SKIP)
    sqe.user_data = 9
    assert u.io_uring_submit_and_wait(ring, 1) == 1
    assert u.io_uring_peek_cqe(ring, cqe) == 0
    assert u.io_uring_cq_ready(ring) == 1
    entry = cqe[0]
    try:
        assert (entry.user_data, entry.res) == (9, 0)
    except OSError as e:  # older kernels refuse the flag
        assert e.errno == errno.EINVAL
    u.io_uring_cqe_seen(ring, entry)


@pytest.mark.requires_op("IORING_OP_FUTEX_WAIT", "IORING_OP_FUTEX_WAKE")
def test_futex_messages_example(capsys):
    # `example/futex_messages.py`: the futex way to pass rich messages between threads' rings
    import pathlib
    import runpy

    path = pathlib.Path(__file__).parents[2] / "example" / "futex_messages.py"
    runpy.run_path(str(path), run_name="__main__")
    lines = capsys.readouterr().out.splitlines()
    assert lines == [str({"id": i, "text": f"message {i}"}) for i in range(5)]
