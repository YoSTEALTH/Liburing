from os import O_TMPFILE, O_RDWR, O_CREAT
from pytest import mark, raises
from os.path import join
from random import randint
from liburing import AT_FDCWD, IOSQE_FIXED_FILE, io_uring, io_uring_cqes, iovec, io_uring_queue_init, \
                     io_uring_get_sqe, io_uring_prep_openat, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_queue_exit, io_uring_register_files, skip_os, files, \
                     io_uring_register_files_update, io_uring_unregister_files, statx, io_uring_prep_statx, \
                     ffi
from test_helper import submit_wait_result


version = '5.5'
from_buffer = ffi.from_buffer


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_register_file():
    ring = io_uring()
    cqes = io_uring_cqes()
    write = bytearray(b'hello world')
    read = bytearray(11)
    iov = iovec(write, read)
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR, 0o700)
        fd = submit_wait_result(ring, cqes)

        # register `fds`
        fds = files(fd)  # `int[fd]`
        index = 0
        assert io_uring_register_files(ring, fds, len(fds)) == 0

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        assert submit_wait_result(ring, cqes) == 0

        # write - using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, index, iov[0].iov_base, iov[0].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # read - using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, index, iov[1].iov_base, iov[1].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert write == read
    finally:
        # note: let exit also unregister fds
        io_uring_queue_exit(ring)


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_register_file_update():
    ring = io_uring()
    cqes = io_uring_cqes()
    write = bytearray(b'hello world')
    read = bytearray(11)
    iov = iovec(write, read)
    fds = files(-1, -1, -1, -1)  # prep 4 fd spots
    index = 2  # only use index ``2`` of the `fds`
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        # register 4 `fds`
        assert io_uring_register_files(ring, fds, len(fds)) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR, 0o700)
        fd = submit_wait_result(ring, cqes)
        fds[index] = fd

        fd2 = files(fd)  # `int[fd]`
        # register - update only the index ``2`` value
        assert io_uring_register_files_update(ring, index, fd2, 1) == 1

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fds[index])
        assert submit_wait_result(ring, cqes) == 0

        # write - using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, index, iov[0].iov_base, iov[0].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # read - using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, index, iov[1].iov_base, iov[1].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert write == read

        # unregister
        assert io_uring_unregister_files(ring) == 0
    finally:
        io_uring_queue_exit(ring)


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_register_fd_close():
    ring = io_uring()
    cqes = io_uring_cqes()
    write = bytearray(b'hello world')
    read = bytearray(11)
    iov = iovec(write, read)
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR, 0o700)
        fd = submit_wait_result(ring, cqes)

        # register `fds`
        fds = files(fd)  # `int[fd]`
        index = 0
        assert io_uring_register_files(ring, fds, len(fds)) == 0

        # close - right away after registering fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        assert submit_wait_result(ring, cqes) == 0

        # write - using registered file index and closed fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, index, iov[0].iov_base, iov[0].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # read - using registered file index and closed fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, index, iov[1].iov_base, iov[1].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert write == read

        # unregister - index
        fds = files(-1)
        assert io_uring_register_files_update(ring, index, fds, 1) == 1

        # re-read - should not be able to since index was unregistered
        with raises(OSError):  # [Errno 9] Bad file descriptor
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_read(sqe, index, iov[1].iov_base, iov[1].iov_len, 0)
            sqe.flags |= IOSQE_FIXED_FILE
            assert submit_wait_result(ring, cqes) == 11
    finally:
        io_uring_queue_exit(ring)


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_multiple_register_fd_mix(tmpdir):
    ring = io_uring()
    cqes = io_uring_cqes()
    loop = randint(2, 5)
    data = b'hello world'
    write = [bytearray(data) for _ in range(loop)]
    iov = iovec(*write)
    fds = files(-1 for _ in range(loop))  # prep fds
    try:
        assert io_uring_queue_init(2, ring, 0) == 0
        # initialize register
        assert io_uring_register_files(ring, fds, len(fds)) == 0

        for index in range(loop):  # index = 0, 1, ...
            path = join(tmpdir, f'register-fd-mix-{index}.txt').encode()
            # open
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_openat(sqe, AT_FDCWD, path, O_CREAT | O_RDWR, 0o700)
            fd = submit_wait_result(ring, cqes)

            # register update
            if index == 1:  # skip registering middle one!
                fd1 = fd
            else:
                fds = files(fd)
                assert io_uring_register_files_update(ring, index, fds, 1) == 1

                # close registered fd only
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_close(sqe, fd)
                assert submit_wait_result(ring, cqes) == 0

        # write
        for index in range(loop):
            sqe = io_uring_get_sqe(ring)
            if index == 1:  # write using fd
                io_uring_prep_write(sqe, fd1, iov[index].iov_base, iov[index].iov_len, 0)
            else:  # write using registered file index
                io_uring_prep_write(sqe, index, iov[index].iov_base, iov[index].iov_len, 0)
                sqe.flags |= IOSQE_FIXED_FILE
            assert submit_wait_result(ring, cqes) == 11

        # read
        for index in range(loop):
            path = join(tmpdir, f'register-fd-mix-{index}.txt').encode()
            stat = statx()
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_statx(sqe, AT_FDCWD, path, 0, 0, stat)
            assert submit_wait_result(ring, cqes) == 0
            length = stat[0].stx_size  # get written file size
            # note: even though size is known, get it using statx

            read = bytearray(length)
            buffer = from_buffer(read)

            sqe = io_uring_get_sqe(ring)
            if index == 1:
                io_uring_prep_read(sqe, fd1, buffer, length, 0)
            else:  # read using registered file index
                io_uring_prep_read(sqe, index, buffer, length, 0)
                sqe.flags |= IOSQE_FIXED_FILE
            assert submit_wait_result(ring, cqes) == 11
            assert read == data

        # close
        for index in range(loop):
            if index == 1:
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_close(sqe, fd1)
                assert submit_wait_result(ring, cqes) == 0
            else:  # unregister file index
                fds = files(-1)
                assert io_uring_register_files_update(ring, index, fds, 1) == 1
    finally:
        io_uring_queue_exit(ring)
