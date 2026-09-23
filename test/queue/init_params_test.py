import pytest
import liburing


def test_param_filled_by_kernel():
    ring = liburing.Ring()
    param = liburing.Param()
    assert liburing.io_uring_queue_init_params(8, ring, param) == 0
    try:
        assert param.sq_entries == 8
        assert param.cq_entries == 16  # kernel defaults `cq` to 2x `sq`
        assert param.features == ring.features
        assert param.flags == ring.flags  # liburing adds `IORING_SETUP_NO_SQARRAY`
        assert param.features & liburing.IORING_FEAT_SINGLE_MMAP
    finally:
        liburing.io_uring_queue_exit(ring)


@pytest.mark.parametrize('flags', (liburing.IORING_SETUP_IOPOLL,
                                   liburing.IORING_SETUP_SQPOLL,
                                   liburing.IORING_SETUP_COOP_TASKRUN,
                                   liburing.IORING_SETUP_SUBMIT_ALL,
                                   liburing.IORING_SETUP_SINGLE_ISSUER,
                                   liburing.IORING_SETUP_DEFER_TASKRUN
                                   | liburing.IORING_SETUP_SINGLE_ISSUER))
def test_setup_flags(flags):
    ring = liburing.Ring()
    param = liburing.Param()
    param.flags = flags
    assert liburing.io_uring_queue_init_params(8, ring, param) == 0
    try:
        # liburing would add extra flags,
        # so `param.flags == flags` fails.
        assert param.flags & flags == flags
        assert param.sq_entries == 8
    finally:
        liburing.io_uring_queue_exit(ring)


def test_setup_clamp():
    over_max = 32768 + 1
    ring = liburing.Ring()
    with pytest.raises(OSError):  # OSError: [Errno 22] Invalid argument
        liburing.io_uring_queue_init_params(over_max, ring, liburing.Param())

    ring = liburing.Ring()
    param = liburing.Param()
    param.flags = liburing.IORING_SETUP_CLAMP
    assert liburing.io_uring_queue_init_params(over_max, ring, param) == 0
    try:
        assert param.sq_entries == 32768
        assert param.cq_entries == 65536
    finally:
        liburing.io_uring_queue_exit(ring)


