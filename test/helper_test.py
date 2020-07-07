import math
import liburing


def test_time_convert():
    # int test
    assert liburing.time_convert(1) == (1, 0)
    # float test
    assert liburing.time_convert(1.5) == (1, 500_000_000)
    assert liburing.time_convert(1.05) == (1, 50_000_000)
    # float weirdness test
    result = liburing.time_convert(1.005)
    assert result[0] == 1
    assert math.isclose(result[1], 5_000_000, abs_tol=1)

    result = liburing.time_convert(1.0005)
    assert result[0] == 1
    assert math.isclose(result[1], 500_000, abs_tol=1)


def test_probe():
    op = liburing.probe()
    for name, bo in op.items():
        assert isinstance(name, str)
        assert isinstance(bo, bool)

    assert op['IORING_OP_NOP'] is True
    assert op.get('IORING_OP_LAST') is None
