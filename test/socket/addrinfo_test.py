import pytest
import liburing

NOT_IMPLEMENTED = "`getaddrinfo` / `getnameinfo` are not implemented yet"


@pytest.mark.skip(NOT_IMPLEMENTED)
def test_getaddrinfo():
    # `SOCK_STREAM` only: without hints libc also returns dgram & raw entries.
    result = [r for r in liburing.getaddrinfo(b"127.0.0.1", b"12345") if r[1] == liburing.SOCK_STREAM]
    assert len(result) == 1
    af, sock, proto, canon, addr = result[0]
    assert af == liburing.AF_INET
    assert proto == liburing.IPPROTO_TCP
    assert canon == b""
    assert type(addr) is liburing.Sockaddr
    assert addr.family == liburing.AF_INET

    with pytest.raises(OSError):  # bad service name
        liburing.getaddrinfo(b"127.0.0.1", b"123abc45")


@pytest.mark.skip(NOT_IMPLEMENTED)
def test_getnameinfo():
    flags = liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV
    assert liburing.getnameinfo(liburing.Sockaddr(liburing.AF_INET, "0.0.0.0", 12345), flags) == ("0.0.0.0", 12345)
    assert liburing.getnameinfo(liburing.Sockaddr(liburing.AF_INET6, "::", 12345), flags) == ("::", 12345)
