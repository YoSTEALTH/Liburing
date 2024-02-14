from liburing import O_CREAT, O_RDWR, AT_FDCWD, iovec, io_uring, io_uring_get_sqe, \
                     io_uring_prep_openat, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_submit, io_uring_wait_cqe, \
                     io_uring_cqe_seen, io_uring_cqe, io_uring_queue_init, io_uring_queue_exit, \
                     trap_error


def open(ring, cqe, path, flags, mode=0o660, dir_fd=AT_FDCWD):
    _path = path if isinstance(path, bytes) else str(path).encode()
    # if `path` is relative and `dir_fd` is `AT_FDCWD`, then `path` is relative
    # to current working directory. Also `_path` must be in bytes

    sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
    io_uring_prep_openat(sqe, dir_fd, _path, flags, mode)
    return _submit_and_wait(ring, cqe)  # returns fd


def write(ring, cqe, fd, data, offset=0):
    iov = iovec(data)  # or iovec([bytearray(data)])
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, fd, iov.iov_base, iov.iov_len, offset)
    return _submit_and_wait(ring, cqe)  # returns length(s) of bytes written


def read(ring, cqe, fd, length, offset=0):
    iov = iovec(bytearray(length))  # or [bytearray(length)]
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, fd, iov.iov_base, iov.iov_len, offset)
    _submit_and_wait(ring, cqe)  # get actual length of file read.
    return iov.iov_base


def close(ring, cqe, fd):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    _submit_and_wait(ring, cqe)  # no error means success!


def _submit_and_wait(ring, cqe):
    io_uring_submit(ring)  # submit entry
    io_uring_wait_cqe(ring, cqe)  # wait for entry to finish
    result = trap_error(cqe.res)  # auto raise appropriate exception if failed
    # note `cqe.res` returns results, if ``< 0`` its an error, if ``>= 0`` its the value

    # done with current entry so clear it from completion queue.
    io_uring_cqe_seen(ring, cqe)
    return result  # type: int


def main():
    ring = io_uring()
    cqe = io_uring_cqe()  # completion queue entry
    try:
        io_uring_queue_init(8, ring, 0)

        fd = open(ring, cqe, '/tmp/liburing-test-file.txt', O_CREAT | O_RDWR)
        print('fd:', fd)

        length = write(ring, cqe, fd, b'hello world')
        print('wrote:', length)

        content = read(ring, cqe, fd, length)
        print('read:', content)

        close(ring, cqe, fd)
        print('closed.')
    finally:
        io_uring_queue_exit(ring)


if __name__ == '__main__':
    main()
