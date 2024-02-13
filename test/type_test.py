import re
import pytest
from liburing import SC_IOV_MAX, timespec, iovec


def test_timespec():
    ts = timespec(1)
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 0

    ts = timespec(1.5)
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 500000000

    ts = timespec()
    assert ts.tv_sec == 0
    assert ts.tv_nsec == 0
    ts.tv_sec = 1
    ts.tv_nsec = 500000000
    assert ts.tv_sec == 1
    assert ts.tv_nsec == 500000000


def test_iovec():
    assert len(iovec(bytes(1))) == 1
    assert len(iovec(bytearray(2))) == 1
    assert len(iovec(memoryview(bytearray(3)))) == 1

    # read
    read_bytes = [bytes(1), bytes(2), bytes(3)]
    read_bytearray = [bytearray(2), bytearray(1)]
    read_memoryview = [memoryview(bytearray(3))]

    assert len(iovec(read_bytes)) == 3
    assert len(iovec(read_bytearray)) == 2
    assert len(iovec(read_memoryview)) == 1

    assert iovec(read_bytes).iov_len == 1
    assert iovec(read_bytearray).iov_len == 2
    assert iovec(read_memoryview).iov_len == 3

    # empty for internal use
    iov = iovec(None)
    assert len(iov) == 0
    assert bool(iov) is False

    # write
    write_bytes = [b'a']
    write_bytearray = [bytearray(b'bb')]
    write_memoryview = [memoryview(bytearray(b'ccc'))]

    assert iovec(write_bytes).iov_len == 1
    assert iovec(write_bytearray).iov_len == 2
    assert iovec(write_memoryview).iov_len == 3
    assert iovec(write_bytes).iov_base == b'a'
    assert iovec(write_bytearray).iov_base == b'bb'
    assert iovec(write_memoryview).iov_base == b'ccc'

    iov_max = SC_IOV_MAX + 1
    buffers = [bytes(1)] * iov_max
    error = re.escape(f"`iovec()` - `buffers` length of {iov_max} exceeds `SC_IOV_MAX` limit set by OS of {SC_IOV_MAX}")
    with pytest.raises(OverflowError, match=error):
        iovec(buffers)
