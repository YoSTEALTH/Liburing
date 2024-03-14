import pytest
import liburing


def test_getnameinfo(ring, cqe):
    addr = liburing.sockaddr(liburing.AF_INET, b'0.0.0.0', 12345)
    host, port = liburing.getnameinfo(addr, liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV)
    assert host == b'0.0.0.0'
    assert not host.isdigit()
    assert port == b'12345'
    assert port.isdigit()

    addr = liburing.sockaddr(liburing.AF_INET6, b'::', 12345)
    host, port = liburing.getnameinfo(addr, liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV)
    assert host == b'::'
    assert not host.isdigit()
    assert port == b'12345'
    assert port.isdigit()

    with pytest.raises(ValueError):
        addr = liburing.sockaddr(liburing.AF_INET, b'::', 12345)
    with pytest.raises(ValueError):
        addr = liburing.sockaddr(liburing.AF_INET6, b'0.0.0.0', 12345)
