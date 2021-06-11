from os import O_CREAT, O_RDWR
from os.path import join
from liburing import AT_FDCWD, RESOLVE_CACHED, IOSQE_IO_LINK, io_uring, io_uring_cqes, iovec, io_uring_queue_init, \
                     io_uring_get_sqe, io_uring_prep_openat2, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_queue_exit, io_uring_register_buffers, \
                     open_how
from test_helper import submit_wait_result


def test_openat2(tmpdir):
    ring = io_uring()
    cqes = io_uring_cqes()
    # prep
    buffers = (bytearray(b'hello world'), bytearray(11))
    iov = iovec(*buffers)
    
    file_path = join(tmpdir, 'openat2_test.txt').encode()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0
        assert io_uring_register_buffers(ring, iov, len(iov)) == 0

        # open
        how = open_how(O_CREAT | O_RDWR, 0o700)
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat2(sqe, AT_FDCWD, file_path, how)
        fd = submit_wait_result(ring, cqes)

        # write
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, iov[0].iov_base, iov[0].iov_len, 0)
        assert submit_wait_result(ring, cqes) == 11

        # read
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, iov[1].iov_base, iov[1].iov_len, 0)
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert buffers[0] == buffers[1]

        # second open for resolve test
        how = open_how(O_RDWR, 0, RESOLVE_CACHED)
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat2(sqe, AT_FDCWD, file_path, how)
        fd2 = submit_wait_result(ring, cqes)

        # close both files
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        sqe.flags |= IOSQE_IO_LINK
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd2)
        submit_wait_result(ring, cqes, 2)

    finally:
        io_uring_queue_exit(ring)
