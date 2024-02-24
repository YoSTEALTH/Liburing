import pytest
import liburing


def test_openat_close():
    ring = liburing.io_uring()
    cqe = liburing.io_uring_cqe()
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    try:
        liburing.io_uring_queue_init(1, ring)
        # open
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_openat(sqe, b'.', flags)
        sqe.user_data = 123
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        fd = liburing.trap_error(cqe.res)
        assert cqe.user_data == 123

        liburing.io_uring_cqe_seen(ring, cqe)

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close(sqe, fd)
        sqe.user_data = 321
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        assert liburing.trap_error(cqe.res) == 0
        assert cqe.user_data == 321
    finally:
        liburing.io_uring_queue_exit(ring)


# TODO:
def test_openat2_close():
    # how = liburing.open_how()  # TODO: dynamic-import bug, look into it.
    ring = liburing.io_uring()
    cqe = liburing.io_uring_cqe()
    how = liburing.open_how(liburing.O_TMPFILE | liburing.O_WRONLY, 0o777, liburing.RESOLVE_IN_ROOT)
    try:
        liburing.io_uring_queue_init(1, ring)
        # open
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_openat2(sqe, b'.', how)
        sqe.user_data = 123
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        fd = liburing.trap_error(cqe.res)
        assert cqe.user_data == 123

        liburing.io_uring_cqe_seen(ring, cqe)

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close(sqe, fd)
        sqe.user_data = 321
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        assert liburing.trap_error(cqe.res) == 0
        assert cqe.user_data == 321
    finally:
        liburing.io_uring_queue_exit(ring)


def test_openat_close_direct():
    ring = liburing.io_uring()
    cqe = liburing.io_uring_cqe()
    index = 0
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    try:
        liburing.io_uring_queue_init(1, ring)
        # register
        liburing.io_uring_register_files(ring, [index, 1, 2, 3])
        # open
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_openat_direct(sqe, b'.', index, flags)
        sqe.user_data = 123
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        result = liburing.trap_error(cqe.res)
        assert result == 0
        assert cqe.user_data == 123

        liburing.io_uring_cqe_seen(ring, cqe)

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close_direct(sqe, index)
        sqe.user_data = 321
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        assert liburing.trap_error(cqe.res) == 0
        assert cqe.user_data == 321

        # unregister
        liburing.io_uring_unregister_files(ring)
    finally:
        liburing.io_uring_queue_exit(ring)


def test_openat2_close_direct():
    ring = liburing.io_uring()
    cqe = liburing.io_uring_cqe()
    how = liburing.open_how(liburing.O_TMPFILE | liburing.O_WRONLY)
    index = 0
    try:
        liburing.io_uring_queue_init(8, ring)
        # register
        liburing.io_uring_register_files(ring, [index, 1, 2, 3])
        # open
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_openat2_direct(sqe, b'.', index, how)
        sqe.user_data = 123
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        result = liburing.trap_error(cqe.res)
        assert result == 0
        assert cqe.user_data == 123

        liburing.io_uring_cqe_seen(ring, cqe)

        # close
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_close_direct(sqe, index)
        sqe.user_data = 321
        liburing.io_uring_submit(ring)
        liburing.io_uring_wait_cqe(ring, cqe)
        assert liburing.trap_error(cqe.res) == 0
        assert cqe.user_data == 321

        # unregister
        liburing.io_uring_unregister_files(ring)
    finally:
        liburing.io_uring_queue_exit(ring)

