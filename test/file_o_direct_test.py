from os import O_TMPFILE, O_RDWR, O_DIRECT
from mmap import PAGESIZE, mmap
from liburing import AT_FDCWD, io_uring, io_uring_cqes, iovec, io_uring_queue_init, io_uring_get_sqe, \
                     io_uring_prep_openat, io_uring_prep_writev, io_uring_prep_readv, io_uring_prep_close, \
                     io_uring_queue_exit
from test_helper import submit_wait_result


def test_file_o_direct():
    # note: `O_DIRECT` does not work if the file path is in memory, like "/tmp"

    ring = io_uring()
    cqes = io_uring_cqes()

    read = mmap(-1, PAGESIZE)
    write = mmap(-1, PAGESIZE)
    write[0:11] = b'hello world'

    iov_read = iovec(read)
    iov_write = iovec(write)

    try:
        # initialization
        assert io_uring_queue_init(2, ring, 0) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR | O_DIRECT, 0o700)
        fd = submit_wait_result(ring, cqes)

        # write
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_writev(sqe, fd, iov_write, len(iov_write), 0)
        assert submit_wait_result(ring, cqes) == PAGESIZE

        # read
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_readv(sqe, fd, iov_read, len(iov_read), 0)
        assert submit_wait_result(ring, cqes) == PAGESIZE

        # confirm
        assert read[:20] == write[:20]

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        assert submit_wait_result(ring, cqes) == 0

    finally:
        read.close()
        write.close()
        io_uring_queue_exit(ring)
