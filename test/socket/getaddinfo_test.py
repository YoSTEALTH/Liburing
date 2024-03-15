import pytest
import liburing


def test_getaddrinfo():
    assert len(list(liburing.getaddrinfo(b'127.0.0.1', b'12345'))) == 2
    assert len(list(liburing.getaddrinfo(b'python.org', b'80'))) > 12 < 33
    for af_, sock_, proto, canon, addr in liburing.getaddrinfo(b'127.0.0.1', b'12345'):
        assert af_ == liburing.AF_INET
        assert sock_ == liburing.SOCK_STREAM
        assert proto == liburing.IPPROTO_TCP
        assert canon == b''
        assert type(addr) is liburing.sockaddr
        assert addr.family == liburing.AF_INET
        break

    msg = 'Servname not supported for ai_socktype'
    with pytest.raises(OSError, match=msg):
        liburing.getaddrinfo(b'127.0.0.1', b'123abc45')
