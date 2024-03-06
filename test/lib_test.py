import liburing


def test_defines():
    assert liburing.LIBURING_UDATA_TIMEOUT == 18446744073709551615
    assert liburing.IORING_FILE_INDEX_ALLOC == 4294967295
    assert liburing.IORING_REGISTER_USE_REGISTERED_RING == 2147483648
