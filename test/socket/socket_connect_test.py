import pytest
import liburing


def test_sockaddr_class():
    with pytest.raises(NotImplementedError):
        liburing.sockaddr(123)
    # TODO: ?
    # with pytest.raises(ValueError):
    #     liburing.sockaddr(123, b'hello world hello world')  # length over 14

    # AF_UNIX
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_UNIX, b'')
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_UNIX, b' '*109)
    assert liburing.sockaddr(liburing.AF_UNIX, b'./path')._test == {
        'sun_family': 1, 'sun_path': b'./path'}

    # AF_INET
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET)
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET, b'', 123)
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET, b'./path')
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET, b'bad. ad.dre.ss', 123)
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET, b'::1', 123)  # ipv6 in ipv4
    assert liburing.sockaddr(liburing.AF_INET, b'0.0.0.0', 123)._test == {
        'sin_family': 2, 'sin_port': 31488, 'sin_addr': {'s_addr': 0}}
    assert liburing.sockaddr(liburing.AF_INET, b'127.0.0.1', 80)._test == {
        'sin_family': 2, 'sin_port': 20480, 'sin_addr': {'s_addr': 16777343}}

    # AF_INET6
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET6)
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET6, b'', 123)
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET6, b'./path')
    with pytest.raises(ValueError):
        liburing.sockaddr(liburing.AF_INET6, b'123.123.123.123', 123, 234)  # IPv4 in IPv6
    assert liburing.sockaddr(liburing.AF_INET6, b'::', 123, 321)._test == {
        'sin6_family': 10, 'sin6_port': 31488, 'sin6_flowinfo': 0,
        'sin6_addr': {'s6_addr': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]},
        'sin6_scope_id': 321}
    assert liburing.sockaddr(liburing.AF_INET6, b'::1', 123, 321)._test == {
        'sin6_family': 10, 'sin6_port': 31488, 'sin6_flowinfo': 0,
        'sin6_addr': {'s6_addr': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]},
        'sin6_scope_id': 321}

