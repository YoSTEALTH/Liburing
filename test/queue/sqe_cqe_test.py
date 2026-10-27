import pytest
from liburing import *


def test_Sqe():
    with pytest.raises(RuntimeError):
        sqe = Sqe(0)

    sqe = Sqe()
    assert sqe.fd == 0
    assert sqe.len == 0
    assert sqe.user_data == 0
    assert (sqe.ioprio, sqe.personality) == (0, 0)
    assert len(sqe) == 1
    assert bool(sqe) is True
    io_uring_prep_multishot_accept(sqe, 7)
    assert sqe.ioprio == IORING_ACCEPT_MULTISHOT  # accept and network preps put their own flags there

    sqe = Sqe(2)
    assert len(sqe) == 2
    assert bool(sqe[1])
    sqe.user_data = 123
    assert sqe.user_data == 123
    assert sqe[0].user_data == 123
    assert sqe[0].user_data is sqe.user_data
    assert sqe[1].user_data == 0
    sqe[1].user_data = 321
    assert sqe[1].user_data == 321
    assert sqe.user_data == 123  # check again to make sure wires aren't crossed.

    with pytest.raises(IndexError):
        assert sqe[2]

    with pytest.raises(OverflowError):
        Sqe(-3)


def test_Cqe(ring, cqe):
    with pytest.raises(IndexError):
        cqe[0]
    with pytest.raises(IndexError):
        cqe[1]
    with pytest.raises(AttributeError):
        _ = cqe.user_data
    assert not cqe

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 1

    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 2

    assert io_uring_submit(ring) == 2
    assert io_uring_wait_cqe_nr(ring, cqe, 2) == 0
    assert io_uring_cq_ready(ring) == 2

    assert bool(cqe)
    entry = cqe[0]
    assert entry.user_data == 1
    assert io_uring_cqe_seen(ring, entry) is None

    assert bool(cqe[1])
    entry = cqe[1]
    assert entry.user_data == 2
    assert io_uring_cqe_seen(ring, entry) is None


@pytest.mark.parametrize(
    "flags, wide",
    [
        (0, False),
        (IORING_SETUP_CQE32, True),
        (IORING_SETUP_CQE_MIXED, False),
    ],
)
def test_big_cqe(flags, wide):
    ring, cqe = Ring(), Cqe()
    try:
        io_uring_queue_init(4, ring, flags)
    except OSError:
        pytest.skip("kernel lacks this setup flag")
    try:
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = 5
        assert io_uring_submit_and_wait(ring, 1) == 1
        io_uring_peek_cqe(ring, cqe)
        entry = cqe[0]
        assert entry.user_data == 5
        # a NOP's 32-byte completion carries zeros (16-byte ones on a mixed ring: none)
        assert entry.big_cqe == (bytes(16) if wide else None)
        io_uring_cqe_seen(ring, entry)
    finally:
        io_uring_queue_exit(ring)


def test_cqe_takes_no_size():
    with pytest.raises(TypeError):  # batches: `CqeBatch(no)`
        Cqe(4)
