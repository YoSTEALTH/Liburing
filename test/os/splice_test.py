import os
import os.path
from liburing import *


def test_clone_file_using_splice(tmp_dir, ring, cqe):
    flags = SPLICE_F_MOVE | SPLICE_F_MORE
    data = b"hi... bye!"
    buf_len = len(data)
    ts = timespec(3)

    fd_in = os.open(os.path.join(tmp_dir, "splice-1.txt"), os.O_RDWR | os.O_CREAT, 0o660)
    os.write(fd_in, data)
    fd_out = os.open(os.path.join(tmp_dir, "splice-2.txt"), os.O_RDWR | os.O_CREAT, 0o660)
    r, w = os.pipe()

    try:
        # read from file "splice-1.txt"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_splice(sqe, fd_in, 0, w, -1, buf_len, flags)
        sqe.user_data = 1

        # chain top and bottom sqe
        sqe.flags |= IOSQE_IO_LINK

        # write to file "splice-2.txt"
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_splice(sqe, r, -1, fd_out, 0, buf_len, flags)
        sqe.user_data = 2

        assert io_uring_submit_and_wait_timeout(ring, cqe, 2, ts) == 2

        entry0 = cqe[0]
        assert entry0.res == 10
        assert entry0.user_data == 1

        entry1 = cqe[1]
        assert entry1.res == 10
        assert entry1.user_data == 2
        io_uring_cq_advance(ring, 2)

        assert os.read(fd_out, buf_len) == data

    finally:
        os.close(r)
        os.close(w)
        os.close(fd_in)
        os.close(fd_out)
