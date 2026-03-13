import pytest
import liburing


def test_Sockaddr():
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_UNIX, " " * 109)
    addr = liburing.Sockaddr(liburing.AF_UNIX, "./path")
    with pytest.raises(NotImplementedError):
        addr.port
    with pytest.raises(NotImplementedError):
        addr.ip
    assert addr.family == liburing.AF_UNIX
    assert addr.path == "./path"

    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "./path")
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "bad. ad.dre.ss", 123)
    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET, "::1", 123)  # ipv6 in ipv4

    addr = liburing.Sockaddr(liburing.AF_INET, "127.0.0.1", 80)
    assert addr.family == liburing.AF_INET
    assert addr.port == 80
    assert addr.ip == "127.0.0.1"
    with pytest.raises(NotImplementedError):
        addr.path

    with pytest.raises(ValueError):
        liburing.Sockaddr(liburing.AF_INET6, "./path")
    with pytest.raises(TypeError):
        liburing.Sockaddr(liburing.AF_INET6, "123.123.123.123", 123, 234)  # IPv4 in IPv6
    assert liburing.Sockaddr(liburing.AF_INET6, "::fb%321", 12345)
    assert liburing.Sockaddr(liburing.AF_INET6, "::1", 65535)

