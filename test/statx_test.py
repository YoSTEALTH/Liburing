from os import O_CREAT, open, close
from os.path import join
from stat import S_IMODE
from pytest import mark
from liburing import AT_FDCWD, AT_STATX_FORCE_SYNC, STATX_MODE, io_uring_queue_init, io_uring_queue_exit, \
                     io_uring, io_uring_cqes, io_uring_get_sqe, statx, io_uring_prep_statx, skip_os
from test_helper import submit_wait_result


version = '5.6'


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_statx(tmpdir):
    ring = io_uring()
    cqes = io_uring_cqes()
    file_path = join(tmpdir, 'statx_test.txt').encode()
    bad_path = join(tmpdir, 'file-that-does-not-exist').encode()

    # create sample file
    fd = open(file_path, O_CREAT, 0o700)
    close(fd)

    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        stat = statx()
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_statx(sqe, AT_FDCWD, file_path, AT_STATX_FORCE_SYNC, STATX_MODE, stat)
        sqe.user_data = 1
        assert submit_wait_result(ring, cqes) == 0
        stat[0]
        assert S_IMODE(stat[0].stx_mode) == 448 == 0o700
        assert oct(S_IMODE(stat[0].stx_mode)) == oct(0o700)

        # statx version of file, dir, ... exists or not
        assert exists(ring, cqes, file_path)
        assert not exists(ring, cqes, bad_path)

    finally:
        io_uring_queue_exit(ring)


def exists(ring, cqes, path):
    try:
        stat = statx()
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_statx(sqe, AT_FDCWD, path, 0, 0, stat)
        submit_wait_result(ring, cqes)
    except OSError:
        return False
    else:
        return True
