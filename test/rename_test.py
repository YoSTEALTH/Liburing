import sys
import os.path
import pytest
from platform import uname
if sys.version_info < (3, 10):
    from distutils.version import LooseVersion
else:
    from setuptools._distutils.version import LooseVersion
import liburing


required = '5.11'
skip = LooseVersion(uname().release) < LooseVersion(required)


@pytest.mark.skipif(skip, reason=f'requires linux {required}+')
def test_rename_file(tmpdir):
    src_file_path = os.path.join(tmpdir, 'src_file.txt').encode()
    dst_file_path = os.path.join(tmpdir, 'dst_file.txt').encode()
    with open(src_file_path, 'x'):  # create src file
        pass

    flags = 0
    ring = liburing.io_uring()
    try:
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        sqe = liburing.get_sqe(ring)
        liburing.io_uring_prep_renameat(sqe,
                                        liburing.AT_FDCWD, src_file_path,
                                        liburing.AT_FDCWD, dst_file_path,
                                        flags)
        assert liburing.io_uring_submit_and_wait(ring, 1) == 1
        liburing.io_uring_cq_advance(ring, 1)

        assert not os.path.exists(src_file_path)  # old file should not exist
        assert os.path.exists(dst_file_path)      # renamed file should exist

    finally:
        liburing.io_uring_queue_exit(ring)

    
