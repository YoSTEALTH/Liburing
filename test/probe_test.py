from errno import EINVAL
from pytest import raises
from liburing import probe, io_uring_get_probe, io_uring_get_probe_ring, io_uring_free_probe, \
                     io_uring_register_probe, io_uring_probe, \
                     io_uring, io_uring_queue_init, io_uring_queue_exit


def test_probe():
    op = probe()
    assert op['IORING_OP_NOP'] is True
    assert op.get('IORING_OP_LAST', None) is None

    # triggers `__dealloc__`
    io_uring_get_probe()


def test_probe_ring():
    ring = io_uring()
    try:
        io_uring_queue_init(8, ring, 0)
        p = io_uring_get_probe_ring(ring)

        assert p.ops_len > 31
        assert p.last_op > 30
        assert p.last_op == p.ops_len - 1

        io_uring_free_probe(p)
    finally:
        io_uring_queue_exit(ring)


def test_probe_register():
    ring = io_uring()
    try:
        io_uring_queue_init(8, ring, 0)
        p = io_uring_probe(1)
        with raises(OSError) as e:
            io_uring_register_probe(ring, p, 256)
        assert e.value.errno == EINVAL
        io_uring_free_probe(p)

        p = io_uring_probe(4)
        assert io_uring_register_probe(ring, p, 4) == 0
        io_uring_free_probe(p)
    finally:
        io_uring_queue_exit(ring)
