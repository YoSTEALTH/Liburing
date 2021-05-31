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


@pytest.mark.skipif(skip, reason=f'requires Linux {required}+')
def test_unlink(tmpdir):
    file_path = os.path.join(tmpdir, 'file.txt').encode()
    dir_path = os.path.join(tmpdir, 'directory').encode()

    os.mkdir(dir_path)          # create directory
    with open(file_path, 'x'):  # create file
        pass

    flags = 0
    ring = liburing.io_uring()
    try:
        assert liburing.io_uring_queue_init(2, ring, 0) == 0

        sqes = liburing.get_sqes(ring, 2)
        liburing.io_uring_prep_unlinkat(sqes[0], liburing.AT_FDCWD, file_path, flags)
        liburing.io_uring_prep_unlinkat(sqes[1], liburing.AT_FDCWD, dir_path, liburing.AT_REMOVEDIR)

        assert liburing.io_uring_submit_and_wait(ring, 2) == 2
        liburing.io_uring_cq_advance(ring, 2)

        assert not os.path.exists(file_path)  # file should not exist
        assert not os.path.exists(dir_path)   # dir should not exist

    finally:
        liburing.io_uring_queue_exit(ring)
