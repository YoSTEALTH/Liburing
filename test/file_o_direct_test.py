from os import O_TMPFILE, O_RDWR, O_DIRECT
from mmap import PAGESIZE, MAP_PRIVATE, mmap
from liburing import AT_FDCWD, io_uring, io_uring_cqes, iovec, io_uring_queue_init, io_uring_get_sqe, \
                     io_uring_prep_openat, io_uring_prep_write_fixed, io_uring_prep_read_fixed, \
                     io_uring_prep_close, io_uring_queue_exit, io_uring_register_buffers
from test_helper import submit_wait_result


def test_file_o_direct():
    # note:
    #   - `O_DIRECT` does not work if the file path is in memory, like "/dev/shm" or "/tmp"
    #   - currently only `MAP_PRIVATE` works with `io_uring_register_buffers`, `MAP_SHARED` will be fixed soon!

    ring = io_uring()
    cqes = io_uring_cqes()

    read = mmap(-1, PAGESIZE, flags=MAP_PRIVATE)
    write = mmap(-1, PAGESIZE, flags=MAP_PRIVATE)
    write[0:11] = b'hello world'

    iov = iovec(write, read)

    try:
        assert io_uring_queue_init(2, ring, 0) == 0
        assert io_uring_register_buffers(ring, iov, len(iov)) == 0

        # open - create local testing file.
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, b'.', O_TMPFILE | O_RDWR | O_DIRECT, 0o700)
        fd = submit_wait_result(ring, cqes)

        # write
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write_fixed(sqe, fd, iov[0].iov_base, iov[0].iov_len, 0, 0)
        assert submit_wait_result(ring, cqes) == PAGESIZE

        # read
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read_fixed(sqe, fd, iov[1].iov_base, iov[1].iov_len, 0, 1)
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
