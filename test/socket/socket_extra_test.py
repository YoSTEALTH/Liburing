import liburing


def test_isIP():
    assert liburing.isIP(liburing.AF_INET, b'0.0.0.0') is True
    assert liburing.isIP(liburing.AF_INET6, b'::1') is True
    assert liburing.isIP(liburing.AF_INET6, b'domain.ext') is False
    assert liburing.isIP(liburing.AF_INET, b'domain.ext') is False
    assert liburing.isIP(liburing.AF_UNIX, b'/path/socket') is False
