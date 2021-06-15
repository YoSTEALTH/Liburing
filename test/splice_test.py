import os
from os.path import join
from pytest import mark
from liburing import SPLICE_F_MOVE, SPLICE_F_MORE, IOSQE_IO_LINK, io_uring, io_uring_cqes, io_uring_queue_init, \
                     io_uring_get_sqe, io_uring_prep_splice, io_uring_queue_exit, skip_os
from test_helper import submit_wait_result


version = '5.7'


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_clone_file_using_splice(tmpdir):
    fd_in = os.open(join(tmpdir, '1.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    fd_out = os.open(join(tmpdir, '2.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    flags = SPLICE_F_MOVE | SPLICE_F_MORE
    data = b'hello world'
    BUF_SIZE = len(data)
    os.write(fd_in, data)
    r, w = os.pipe()

    ring = io_uring()
    cqes = io_uring_cqes(2)

    try:
        # initialization
        assert io_uring_queue_init(2, ring, 0) == 0

        # read from file "1.txt"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_splice(sqe, fd_in, 0, w, -1, BUF_SIZE, flags)
        sqe.user_data = 1

        # chain top and bottom sqe
        sqe.flags |= IOSQE_IO_LINK

        # write to file "2.txt"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_splice(sqe, r, -1, fd_out, 0, BUF_SIZE, flags)
        sqe.user_data = 2

        assert submit_wait_result(ring, cqes, 2) == [BUF_SIZE, BUF_SIZE]
        assert os.read(fd_out, BUF_SIZE) == data

    finally:
        os.close(fd_in)
        os.close(fd_out)
        io_uring_queue_exit(ring)
