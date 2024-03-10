import liburing


def test_queue_define():
    # sqe.flags
    assert liburing.IOSQE_FIXED_FILE == 1 << 0
    assert liburing.IOSQE_IO_DRAIN == 1 << 1
    assert liburing.IOSQE_IO_LINK == 1 << 2
    assert liburing.IOSQE_IO_HARDLINK == 1 << 3
    assert liburing.IOSQE_ASYNC == 1 << 4
    assert liburing.IOSQE_BUFFER_SELECT == 1 << 5
    assert liburing.IOSQE_CQE_SKIP_SUCCESS == 1 << 6
