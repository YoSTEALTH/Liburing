import pytest
from liburing import timespec, iovec


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
    # read
    read_bytes = [bytes(1), bytes(2), bytes(3)]
    read_bytearray = [bytearray(2), bytearray(1)]
    read_memoryview = [memoryview(bytearray(3))]

    assert len(iovec([])) == 0
    assert len(iovec(read_bytes)) == 3
    assert len(iovec(read_bytearray)) == 2
    assert len(iovec(read_memoryview)) == 1

    assert iovec(read_bytes).iov_len == 1
    assert iovec(read_bytearray).iov_len == 2
    assert iovec(read_memoryview).iov_len == 3

    with pytest.raises(TypeError):
        iovec(None)

    # write
    write_bytes = [b'a']
    write_bytearray = [bytearray(b'bb')]
    write_memoryview = [memoryview(bytearray(b'ccc'))]

    assert iovec(write_bytes).iov_len == 1
    assert iovec(write_bytearray).iov_len == 2
    assert iovec(write_memoryview).iov_len == 3

    # TOOD:
    # assert iovec(write_bytes).iov_base == b'a'
    # assert iovec(write_bytearray).iov_base == b'bb'
    # assert iovec(write_memoryview).iov_base == b'ccc'
