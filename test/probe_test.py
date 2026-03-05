# from re import escape
from errno import EINVAL
from pytest import raises, mark
import liburing


def test_probe():
    op = liburing.probe()
    assert op["IORING_OP_NOP"] is True
    assert op["IORING_OP_READV"] is True
    assert op["IORING_OP_WRITEV"] is True
    assert op.get("IORING_OP_LAST", None) is None

    # basic class
    with raises(NotImplementedError):
        liburing.Probe()
    p = liburing.io_uring_get_probe()
    liburing.io_uring_free_probe(p)
    with raises(MemoryError):
        p.ops_len


def test_probe_ring():
    ring = liburing.Ring()
    liburing.io_uring_queue_init(8, ring)
    try:
        p = liburing.io_uring_get_probe_ring(ring)
        assert p.ops_len > 31
        assert p.last_op > 30
        assert p.last_op == p.ops_len - 1
        liburing.io_uring_free_probe(p)
    finally:
        liburing.io_uring_queue_exit(ring)


@mark.skip("Bug in struct size!?")
def test_probe_register():
    ring = liburing.Ring()
    liburing.io_uring_queue_init(8, ring)
    try:
        p = liburing.io_uring_probe(1)
        with raises(OSError) as e:
            liburing.io_uring_register_probe(ring, p, 256)
        assert e.value.errno == EINVAL
        # free is done by `__del__` since `num` is set

        p = liburing.io_uring_probe(2)
        assert liburing.io_uring_register_probe(ring, p, 2) == 0
        # free is done by `__del__` since `num` is set
    finally:
        liburing.io_uring_queue_exit(ring)
