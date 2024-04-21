import liburing


def test_io_uring_for_each_cqe(ring, cqe):
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 1

    liburing.io_uring_submit_and_wait_timeout(ring, cqe, 1)
    assert liburing.io_uring_for_each_cqe(ring, cqe) == 1
    assert cqe.res == 0
    assert cqe.user_data == 1
    liburing.io_uring_cq_advance(ring, 1)

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 2
    sqe.flags = liburing.IOSQE_IO_LINK

    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    sqe.user_data = 3

    liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2)
    assert liburing.io_uring_for_each_cqe(ring, cqe) == 3
    assert cqe.res == 0
    assert cqe.user_data == 2
    assert cqe[0].user_data == 2

    assert cqe[1].res == 0
    assert cqe[1].user_data == 3

    liburing.io_uring_cq_advance(ring, 2)


def test_io_uring_cqe_shift():
    ring = liburing.io_uring()
    liburing.io_uring_queue_init(1, ring)
    assert liburing._io_uring_cqe_shift(ring) == 0
    liburing.io_uring_queue_exit(ring)

    ring = liburing.io_uring()
    liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_CQE32)
    assert liburing._io_uring_cqe_shift(ring) == 1
    liburing.io_uring_queue_exit(ring)


def test_io_uring_cqe_index():
    ring = liburing.io_uring()
    liburing.io_uring_queue_init(1, ring, 0)
    assert liburing._io_uring_cqe_index(ring, 0, 0) == 0
    assert liburing._io_uring_cqe_index(ring, 1, 1) == 1
    liburing.io_uring_queue_exit(ring)

    ring = liburing.io_uring()
    liburing.io_uring_queue_init(1, ring, liburing.IORING_SETUP_CQE32)
    assert liburing._io_uring_cqe_index(ring, 0, 0) == 0
    assert liburing._io_uring_cqe_index(ring, 1, 1) == 2
    liburing.io_uring_queue_exit(ring)
