from os import O_TMPFILE, O_RDWR
from pytest import mark
from liburing import AT_FDCWD, IOSQE_FIXED_FILE, io_uring, io_uring_cqes, iovec, io_uring_queue_init, \
                     io_uring_get_sqe, IORING_SETUP_SQPOLL, \
                     io_uring_prep_openat, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_queue_exit, io_uring_register_files, skip_os, files, \
                     io_uring_register_files_update, io_uring_unregister_files
from test_helper import submit_wait_result


version = '5.5'


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_register_file():
    ring = io_uring()
    cqes = io_uring_cqes()
    read = bytearray(11)
    write = bytearray(b'hello world')
    iov = iovec(write, read)
    fds = files(-1, -1, -1, -1)  # register 4 fd spots
    index = 2  # only use index ``2`` of the `fds`
    try:
        assert io_uring_queue_init(2, ring, 0) == 0
        assert io_uring_register_files(ring, fds, len(fds)) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR, 0o700)
        fd = submit_wait_result(ring, cqes)
        fds[index] = fd
        fd2 = files(fd)  # `int[fd]`

        # register update only the index ``2`` value
        assert io_uring_register_files_update(ring, 2, fd2, 1) == 1

        # write using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, index, iov[0].iov_base, iov[0].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # read using registered file index vs fd
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, index, iov[1].iov_base, iov[1].iov_len, 0)
        sqe.flags |= IOSQE_FIXED_FILE
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert write == read

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fds[index])
        assert submit_wait_result(ring, cqes) == 0

        # unregister
        assert io_uring_unregister_files(ring) == 0
    finally:
        io_uring_queue_exit(ring)
