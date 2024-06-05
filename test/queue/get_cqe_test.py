import pytest
import liburing


def test_for_each(ring, cqe):
    loop = 300
    for i in range(loop):
        sqe = liburing.io_uring_get_sqe(ring)
        sqe.user_data = i+1

    assert (counter := liburing.io_uring_submit(ring)) == loop
    liburing.io_uring_wait_cqe_nr(ring, cqe, counter)  # wait for all to be ready

    # >>> difference START 
    cq_ready = 0
    for i in range(liburing.io_uring_for_each_cqe(ring, cqe)):
        assert cqe[i].user_data == i+1
        cq_ready += 1
    # <<< difference END

    assert cq_ready == loop
    liburing.io_uring_cq_advance(ring, cq_ready)  # free seen entries


@pytest.mark.skip('BUG')
def test_peek_batch(ring, cqe):
    loop = 300
    for i in range(loop):
        sqe = liburing.io_uring_get_sqe(ring)
        sqe.user_data = i+1

    assert (counter := liburing.io_uring_submit(ring)) == loop
    liburing.io_uring_wait_cqe_nr(ring, cqe, counter)  # wait for all to be ready

    # >>> difference START
    cq_ready = liburing.io_uring_peek_batch_cqe(ring, cqe, counter)
    for i in range(cq_ready):
        assert cqe[i].user_data == i+1
    # <<< difference END

    assert cq_ready == loop
    liburing.io_uring_cq_advance(ring, cq_ready)  # free seen entries
