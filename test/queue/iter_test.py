import liburing


def test_iter_seen(ring, cqe):
    assert _run_for_iter(ring, cqe, True) is None
    assert _run_while_init_next(ring, cqe, True) is None


def test_iter_advance(ring, cqe):
    assert _run_for_iter(ring, cqe, False) is None
    assert _run_while_init_next(ring, cqe, False) is None


def _run_for_iter(ring, cqe, seen):
    loop = 1024
    for i in range(loop):
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.user_data = i

    assert liburing.io_uring_submit(ring) == loop

    # run 2 loop to make sure there is no overflow happening.
    for x in range(2):
        i = 0
        # note: second loop should not enter `for` loop
        for _ in liburing.CqeIter(ring, cqe, 1):
            entry = cqe[0]  # note: only index `0` data gets updated!!!
            assert entry.user_data == i
            assert not (i == loop + 1)  # catch overflow
            if seen:
                liburing.io_uring_cqe_seen(ring, entry)
            i += 1
        if not seen and i:
            liburing.io_uring_cq_advance(ring, i)
        if x:
            assert i == 0
        else:
            assert i == loop


def _run_while_init_next(ring, cqe, seen):
    loop = 1024
    for i in range(loop):
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_nop(sqe)
        sqe.user_data = i

    assert liburing.io_uring_submit(ring) == loop

    # run 2 loop to make sure there is no overflow happening.
    for x in range(2):
        i = 0
        # note: second loop should not enter `while` loop
        cqe_iter = liburing.io_uring_cqe_iter_init(ring)
        while liburing.io_uring_cqe_iter_next(cqe_iter, cqe):
            entry = cqe[0]  # note: only index `0` data gets updated!!!
            assert entry.user_data == i
            assert not (i == loop + 1)  # catch overflow
            if seen:
                liburing.io_uring_cqe_seen(ring, entry)
            i += 1
        if not seen and i:
            liburing.io_uring_cq_advance(ring, i)
        if x:
            assert i == 0
        else:
            assert i == loop
