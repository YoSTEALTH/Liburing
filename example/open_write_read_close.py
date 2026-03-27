from liburing import (
    O_CREAT,
    O_RDWR,
    Ring,
    Cqe,
    io_uring_get_sqe,
    io_uring_prep_open,
    io_uring_prep_write,
    io_uring_prep_read,
    io_uring_prep_close,
    io_uring_submit,
    io_uring_wait_cqe,
    io_uring_cqe_seen,
    io_uring_queue_init,
    io_uring_queue_exit,
)


def open(ring, cqe, path, flags):
    sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
    io_uring_prep_open(sqe, path, flags)
    # set submit entry identifier as `1` which is returned back in `cqe.user_data`
    # so you can keep track of submit/completed entries.
    sqe.user_data = 1
    return _submit_and_wait(ring, cqe)  # returns fd


def write(ring, cqe, fd, data):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, fd, data)
    sqe.user_data = 2
    return _submit_and_wait(ring, cqe)  # returns length(s) of bytes written


def read(ring, cqe, fd, length):
    buffer = bytearray(length)  # where read data will be stored
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, fd, buffer)
    sqe.user_data = 3
    _submit_and_wait(ring, cqe)  # get actual length of file read.
    return buffer


def close(ring, cqe, fd):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 4
    _submit_and_wait(ring, cqe)  # no error means success!


def _submit_and_wait(ring, cqe):
    io_uring_submit(ring)  # submit entry
    io_uring_wait_cqe(ring, cqe)  # wait for entry to finish
    entry = cqe[0]
    try:
        result = entry.res  # auto raises appropriate exception if failed
    except Exception as e:
        raise e  # do stuff with error
    # done with current entry so clear it from completion queue.
    io_uring_cqe_seen(ring, entry)
    return result  # type: int


def main():
    ring = Ring()
    cqe = Cqe()  # completion queue entry
    try:
        io_uring_queue_init(8, ring)

        fd = open(ring, cqe, "/tmp/liburing-test-file.txt", O_CREAT | O_RDWR)
        print("fd:", fd)

        length = write(ring, cqe, fd, b"hi... bye!")
        print("wrote:", length)

        content = read(ring, cqe, fd, length)
        print("read:", content)

        close(ring, cqe, fd)
        print("closed.")
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    main()
