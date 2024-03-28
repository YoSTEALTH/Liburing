import liburing


def test_uring_defines():
    assert liburing.LIBURING_UDATA_TIMEOUT == 18446744073709551615
