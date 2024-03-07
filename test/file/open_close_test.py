import liburing


def test_openat_close(ring, cqe):
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat(sqe, b'.', flags)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    fd = liburing.trap_error(cqe.res)
    assert cqe.user_data == 123
    liburing.io_uring_cqe_seen(ring, cqe)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 321


def test_openat2_close(ring, cqe):
    how = liburing.open_how(liburing.O_TMPFILE | liburing.O_WRONLY, 0o777, liburing.RESOLVE_IN_ROOT)
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2(sqe, b'.', how)
    sqe.user_data = 123
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    fd = liburing.trap_error(cqe.res)
    assert cqe.user_data == 123
    liburing.io_uring_cqe_seen(ring, cqe)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close(sqe, fd)
    sqe.user_data = 321
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 321


def test_openat_close_direct(ring, cqe):
    index = 0
    flags = liburing.O_TMPFILE | liburing.O_WRONLY
    # register
    liburing.io_uring_register_files(ring, [index, 1, 2, 3])
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat_direct(sqe, b'.', flags, index)
    sqe.user_data = 123
    # submit
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
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 321
    # unregister
    liburing.io_uring_unregister_files(ring)


def test_openat2_close_direct(ring, cqe):
    how = liburing.open_how(liburing.O_TMPFILE | liburing.O_WRONLY)
    index = 3
    # register
    liburing.io_uring_register_files(ring, [0, 1, 2, index])
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2_direct(sqe, b'.', how, index)
    sqe.user_data = 123
    # submit
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
    # submit
    liburing.io_uring_submit(ring)
    liburing.io_uring_wait_cqe(ring, cqe)
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 321
    # unregister
    liburing.io_uring_unregister_files(ring)


def test_openat2_close_direct_auto_file_index_alloc(ring, cqe):
    how = liburing.open_how(liburing.O_TMPFILE | liburing.O_RDWR)
    find_index = 3
    # register
    liburing.io_uring_register_files(ring, [0, 1, 2, -1])
    # open
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_openat2_direct(sqe, b'.', how)  # `file_index=IORING_FILE_INDEX_ALLOC`
    sqe.user_data = 123
    # submit
    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0
    assert liburing.trap_error(cqe.res) == find_index
    assert cqe.user_data == 123
    liburing.io_uring_cqe_seen(ring, cqe)
    # close
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_close_direct(sqe, 0)
    sqe.user_data = 321
    # submit
    assert liburing.io_uring_submit(ring) == 1
    assert liburing.io_uring_wait_cqe(ring, cqe) == 0
    assert liburing.trap_error(cqe.res) == 0
    assert cqe.user_data == 321
    liburing.io_uring_cqe_seen(ring, cqe)
    # unregister
    liburing.io_uring_unregister_files(ring)
