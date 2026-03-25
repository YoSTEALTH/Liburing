import re
import pytest
from liburing import IOV_MAX, Iovec


def test_iovec():
    assert len(Iovec([b""])) == 1
    assert len(Iovec([bytes(1)])) == 1
    assert len(Iovec([bytearray(2)])) == 1
    assert len(Iovec([memoryview(bytearray(3))])) == 1

    iov_bytes = [bytes(1), bytes(2), b""]
    iov_bytearray = [bytearray(2), bytearray(1)]
    iov_memoryview = [memoryview(bytearray(3))]

    assert len(Iovec(iov_bytes)) == 3
    assert len(Iovec(iov_bytearray)) == 2
    assert len(Iovec(iov_memoryview)) == 1

    # empty for internal use
    with pytest.raises(TypeError):
        Iovec(None)
    with pytest.raises(TypeError):
        Iovec(0)
    with pytest.raises(ValueError):
        assert len(Iovec([])) == 0

    iov_max = IOV_MAX + 10
    data = [bytes(1)] * iov_max
    msg = re.escape(f"`Iovec(data)` - length of {iov_max} exceeds `IOV_MAX` limit set by OS of {IOV_MAX}")
    with pytest.raises(ValueError, match=msg):
        Iovec(data)
