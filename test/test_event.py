import os
import os.path
import liburing


def test_event(tmpdir):
    fd = os.open(os.path.join(tmpdir, 'event.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    ring = liburing.io_uring()

    # prepare for writing.
    data = bytearray(b'hello world')
    vecs = liburing.iovec(data)

    try:
        # initialization
        assert liburing.io_uring_queue_init(32, ring, 0) == 0

        # write "hello"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_writev(sqe, fd, vecs, 1, 0)
        liburing.io_uring_submit(ring)

        cqes = liburing.io_uring_cqes()
        while True:
            try:
                assert liburing.io_uring_peek_cqe(ring, cqes) >= 0
            except BlockingIOError:
                print('waiting ...')
            else:
                print('Finished.')
                break

        cqe = liburing.io_uring_cqe()
        liburing.io_uring_cqe_seen(ring, cqe)

        # confirm
        content = os.read(fd, 100)
        assert content == data
        assert len(content) == vecs[0].iov_len
    finally:
        os.close(fd)
        liburing.io_uring_queue_exit(ring)
