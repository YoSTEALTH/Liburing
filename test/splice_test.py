import os
import os.path
import pytest
import liburing


@pytest.mark.skip_linux(5.7)
def test_clone_file_using_splice(tmp_dir, ring, cqe):
    flags = liburing.SPLICE_F_MOVE | liburing.SPLICE_F_MORE
    data = b'hello world'
    buf_len = len(data)
    ts = liburing.timespec(3)

    fd_in = os.open(os.path.join(tmp_dir, 'splice-1.txt'), os.O_RDWR | os.O_CREAT, 0o660)
    os.write(fd_in, data)
    fd_out = os.open(os.path.join(tmp_dir, 'splice-2.txt'), os.O_RDWR | os.O_CREAT, 0o660)

    try:
        r, w = os.pipe()

        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_splice(sqe, fd_in, 0, w, -1, buf_len, flags)
        sqe.user_data = 1

        # chain top and bottom sqe
        sqe.flags |= liburing.IOSQE_IO_LINK

        # write to file "2.txt"
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_splice(sqe, r, -1, fd_out, 0, buf_len, flags)
        sqe.user_data = 2

        assert liburing.io_uring_submit_and_wait_timeout(ring, cqe, 2, ts) == 2
        assert cqe.res == 11
        assert cqe.user_data == 1
        assert cqe[1].res == 11
        assert cqe[1].user_data == 2
        liburing.io_uring_cq_advance(ring, 2)

        assert os.read(fd_out, buf_len) == data

    finally:
        os.close(r)
        os.close(w)
        os.close(fd_in)
        os.close(fd_out)
