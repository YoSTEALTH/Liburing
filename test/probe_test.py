from re import escape
from errno import EINVAL
from pytest import raises
from liburing import probe, io_uring_get_probe, io_uring_get_probe_ring, io_uring_free_probe, \
                     io_uring_register_probe, io_uring_probe


def test_probe():
    op = probe()
    assert op['IORING_OP_NOP'] is True
    assert op.get('IORING_OP_LAST', None) is None

    p = io_uring_get_probe()
    io_uring_free_probe(p)
    with raises(MemoryError, match=escape('`io_uring_probe()` is out of memory!')):
        p.ops_len


def test_probe_ring(ring):
    p = io_uring_get_probe_ring(ring)
    assert p.ops_len > 31
    assert p.last_op > 30
    assert p.last_op == p.ops_len - 1
    io_uring_free_probe(p)


def test_probe_register(ring):
    p = io_uring_probe(1)
    with raises(OSError) as e:
        io_uring_register_probe(ring, p, 256)
    assert e.value.errno == EINVAL
    # free is doen by the `__dealloc__` since `num` is set

    p = io_uring_probe(4)
    assert io_uring_register_probe(ring, p, 4) == 0
    # free is doen by the `__dealloc__` since `num` is set
