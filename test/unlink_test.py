from os import mkdir
from os.path import join, exists
from pytest import mark
from liburing import AT_FDCWD, AT_REMOVEDIR, IOSQE_IO_LINK, io_uring, io_uring_cqes, get_sqes, io_uring_queue_init, \
                     io_uring_queue_exit, io_uring_prep_unlinkat, skip_os
from test_helper import submit_wait_result


version = '5.11'


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_unlink(tmpdir):
    dir_path = join(tmpdir, 'directory').encode()
    mkdir(dir_path)             # create directory

    file_path = join(tmpdir, 'file.txt').encode()
    with open(file_path, 'x'):  # create file
        pass

    flags = 0
    ring = io_uring()
    cqes = io_uring_cqes()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        sqes = get_sqes(ring, 2)
        io_uring_prep_unlinkat(sqes[0], AT_FDCWD, file_path, flags)
        sqes[0].flags |= IOSQE_IO_LINK
        flags |= AT_REMOVEDIR
        io_uring_prep_unlinkat(sqes[1], AT_FDCWD, dir_path, flags)

        assert submit_wait_result(ring, cqes, 2) == [0, 0]
        assert not exists(file_path)  # file should not exist
        assert not exists(dir_path)   # dir should not exist

    finally:
        io_uring_queue_exit(ring)
