from liburing import *


def test_iter_seen(ring, cqe):
    assert _run_for_iter(ring, cqe, True) is None
    assert _run_while_init_next(ring, cqe, True) is None


def test_iter_advance(ring, cqe):
    assert _run_for_iter(ring, cqe, False) is None
    assert _run_while_init_next(ring, cqe, False) is None


def _run_for_iter(ring, cqe, seen):
    loop = 1024
    for i in range(loop):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = i

    assert io_uring_submit(ring) == loop

    # run 2 loop to make sure there is no overflow happening.
    for x in range(2):
        i = 0
        # note: second loop should not enter `for` loop
        for _ in CqeIter(ring, cqe, 1):
            entry = cqe[0]  # note: only index `0` data gets updated!!!
            assert entry.user_data == i
            assert i != loop + 1  # catch overflow
            if seen:
                io_uring_cqe_seen(ring, entry)
            i += 1
        if not seen and i:
            io_uring_cq_advance(ring, i)
        if x:
            assert i == 0
        else:
            assert i == loop


def _run_while_init_next(ring, cqe, seen):
    loop = 1024
    for i in range(loop):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = i

    assert io_uring_submit(ring) == loop

    # run 2 loop to make sure there is no overflow happening.
    for x in range(2):
        i = 0
        # note: second loop should not enter `while` loop
        cqe_iter = io_uring_cqe_iter_init(ring)
        while io_uring_cqe_iter_next(cqe_iter, cqe):
            entry = cqe[0]  # note: only index `0` data gets updated!!!
            assert entry.user_data == i
            assert i != loop + 1  # catch overflow
            if seen:
                io_uring_cqe_seen(ring, entry)
            i += 1
        if not seen and i:
            io_uring_cq_advance(ring, i)
        if x:
            assert i == 0
        else:
            assert i == loop


def test_iter_linked(ring, cqe):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 1
    assert io_uring_submit_and_wait_timeout(ring, cqe, 1) == 1
    assert [cqe[0].user_data for _ in CqeIter(ring, cqe, 1)] == [1]
    assert cqe[0].res == 0
    io_uring_cq_advance(ring, 1)

    # linked nops complete in order
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 2
    sqe.flags = IOSQE_IO_LINK
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    sqe.user_data = 3
    assert io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

    seen = []
    for _ in CqeIter(ring, cqe, 1):
        assert cqe[0].res == 0
        seen.append(cqe[0].user_data)
    assert seen == [2, 3]
    io_uring_cq_advance(ring, 2)
