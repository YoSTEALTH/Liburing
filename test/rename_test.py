from os.path import join, exists
from pytest import mark
from liburing import AT_FDCWD, io_uring, io_uring_cqes, io_uring_queue_init, \
                     io_uring_get_sqe, io_uring_queue_exit, io_uring_prep_renameat, skip_it
from test_helper import submit_wait_result


version = '5.11'


@mark.skipif(skip_it(version), reason=f'Requires Linux {version}+')
def test_rename_file(tmpdir):
    src_file_path = join(tmpdir, 'src_file.txt').encode()
    dst_file_path = join(tmpdir, 'dst_file.txt').encode()

    # create src file
    with open(src_file_path, 'x'):
        pass

    ring = io_uring()
    cqes = io_uring_cqes()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        assert exists(src_file_path)
        assert not exists(dst_file_path)

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_renameat(sqe, AT_FDCWD, src_file_path, AT_FDCWD, dst_file_path, 0)
        assert submit_wait_result(ring, cqes) == 0

        assert not exists(src_file_path)  # old file should not exist
        assert exists(dst_file_path)      # renamed file should exist
    finally:
        io_uring_queue_exit(ring)
