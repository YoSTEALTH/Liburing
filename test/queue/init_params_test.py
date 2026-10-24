import pytest
from liburing import *


def test_param_filled_by_kernel():
    ring = Ring()
    param = Param()
    assert io_uring_queue_init_params(8, ring, param) == 0
    try:
        assert param.sq_entries == 8
        assert param.cq_entries == 16  # kernel defaults `cq` to 2x `sq`
        assert param.features == ring.features
        assert param.flags == ring.flags  # liburing adds `IORING_SETUP_NO_SQARRAY`
        assert param.features & IORING_FEAT_SINGLE_MMAP
    finally:
        io_uring_queue_exit(ring)


@pytest.mark.parametrize(
    'flags',
    (
        IORING_SETUP_IOPOLL,
        IORING_SETUP_SQPOLL,
        IORING_SETUP_COOP_TASKRUN,
        IORING_SETUP_SUBMIT_ALL,
        IORING_SETUP_SINGLE_ISSUER,
        IORING_SETUP_DEFER_TASKRUN | IORING_SETUP_SINGLE_ISSUER,
    ),
)
def test_setup_flags(flags):
    ring = Ring()
    param = Param()
    param.flags = flags
    assert io_uring_queue_init_params(8, ring, param) == 0
    try:
        # liburing would add extra flags,
        # so `param.flags == flags` fails.
        assert param.flags & flags == flags
        assert param.sq_entries == 8
    finally:
        io_uring_queue_exit(ring)


def test_setup_clamp():
    over_max = 32768 + 1
    ring = Ring()
    with pytest.raises(OSError):  # OSError: [Errno 22] Invalid argument
        io_uring_queue_init_params(over_max, ring, Param())

    ring = Ring()
    param = Param()
    param.flags = IORING_SETUP_CLAMP
    assert io_uring_queue_init_params(over_max, ring, param) == 0
    try:
        assert param.sq_entries == 32768
        assert param.cq_entries == 65536
    finally:
        io_uring_queue_exit(ring)
