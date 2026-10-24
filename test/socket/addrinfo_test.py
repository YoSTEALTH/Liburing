import pytest
from liburing import *

NOT_IMPLEMENTED = "`getaddrinfo` / `getnameinfo` are not implemented yet"


@pytest.mark.skip(NOT_IMPLEMENTED)
def test_getaddrinfo():
    # `SOCK_STREAM` only: without hints libc also returns dgram & raw entries.
    result = [r for r in getaddrinfo(b"127.0.0.1", b"12345") if r[1] == SOCK_STREAM]
    assert len(result) == 1
    af, _sock, proto, canon, addr = result[0]
    assert af == AF_INET
    assert proto == IPPROTO_TCP
    assert canon == b""
    assert type(addr) is Sockaddr
    assert addr.family == AF_INET

    with pytest.raises(OSError):  # bad service name
        getaddrinfo(b"127.0.0.1", b"123abc45")


@pytest.mark.skip(NOT_IMPLEMENTED)
def test_getnameinfo():
    flags = NI_NUMERICHOST | NI_NUMERICSERV
    assert getnameinfo(Sockaddr(AF_INET, "0.0.0.0", 12345), flags) == ("0.0.0.0", 12345)
    assert getnameinfo(Sockaddr(AF_INET6, "::", 12345), flags) == ("::", 12345)
