import pytest
import liburing


def test_getnameinfo(ring, cqe):
    addr = liburing.sockaddr(liburing.AF_INET, b'0.0.0.0', 12345)
    host, port = liburing.getnameinfo(addr, liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV)
    assert host == b'0.0.0.0'
    assert port == 12345

    addr = liburing.sockaddr(liburing.AF_INET6, b'::', 12345)
    host, port = liburing.getnameinfo(addr, liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV)
    assert host == b'::'
    assert port == 12345

    with pytest.raises(ValueError):
        addr = liburing.sockaddr(liburing.AF_INET, b'::', 12345)
    with pytest.raises(ValueError):
        addr = liburing.sockaddr(liburing.AF_INET6, b'0.0.0.0', 12345)
