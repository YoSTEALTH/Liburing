from liburing import io_uring_put_sqe, io_uring, io_uring_cqe, io_uring_submit, \
                     io_uring_sqe, io_uring_queue_init, io_uring_queue_exit, \
                     io_uring_wait_cqes, io_uring_cq_advance


def test_io_uring_put_sqe():
    assert _loop(1, 2) is False  # entries < sqe
    assert _loop(2, 2) is True
    assert _loop(8, 2) is True
    assert _loop(1, 0) is True  # sqe = 0, its ok to submit 0 entries
    assert _loop(1024, 1024) is True


def _loop(entries, num):
    ring = io_uring()
    cqe = io_uring_cqe()
    try:
        assert io_uring_queue_init(entries, ring) == 0
        sqe = io_uring_sqe(num)
        for i in range(num):
            sqe[i].user_data = i
        if io_uring_put_sqe(ring, sqe):
            io_uring_submit(ring)
        else:
            return False
        if num:
            assert io_uring_wait_cqes(ring, cqe, num) == 0
            for i in range(num):
                assert cqe[i].user_data == i
            io_uring_cq_advance(ring, num)
        return True
    finally:
        io_uring_queue_exit(ring)
