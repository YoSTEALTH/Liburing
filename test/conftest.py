import os
import os.path
import pytest
import pathlib
import getpass
import tempfile
import liburing


@pytest.fixture
def tmp_dir():
    ''' Temporary directory to store test data.

        Example
            >>> test_my_function(tmp_dir)
            ...     # create directory
            ...     # ----------------
            ...     my_dir = tmp_dir / 'my_dir'
            ...     my_dir.mkdir()
            ...
            ...     # create file
            ...     # -----------
            ...     my_file = tmp_dir / 'my_file.ext'
            ...     my_file.write_text('Hello World!!!')

        Note
            - unlike pytest's `tmpdir`, `tmp_path`, ... `tmp_dir` generated
            files & directories are not deleted after 3 runs.
    '''
    path = f'{tempfile.gettempdir()}/pytest-of-{getpass.getuser()}-holder'
    if not os.path.exists(path):
        os.mkdir(path)
    return pathlib.Path(tempfile.mkdtemp(dir=path))


# liburing start >>>
@pytest.fixture
def ring():
    ring = liburing.io_uring()
    try:
        liburing.io_uring_queue_init(32, ring)
        yield ring
    finally:
        liburing.io_uring_queue_exit(ring)


@pytest.fixture
def cqe():
    return liburing.io_uring_cqe()
# liburing end <<<


# linux version start >>>
LINUX_VERSION = f'{liburing.LINUX_VERSION_MAJOR}.{liburing.LINUX_VERSION_MINOR}'


@pytest.fixture(autouse=True)
def skip_by_platform(request):
    '''
        Example
            >>> @pytest.mark.skip_linux(6.7)
            >>> def test_function():
            ...
            test.py::test_function SKIPPED (Linux `6.7 < 6.8`)

            >>> @pytest.mark.skip_linux(6.7, 'custom message')
            >>> def test_function():
            ...
            test.py::test_function SKIPPED (custom message)

            >>> @pytest.mark.skip_linux('6.7', '')
            >>> def test_function():
            ...
            test.py::test_function SKIPPED
    '''
    if r := request.node.get_closest_marker('skip_linux'):
        major, minor = map(int, str(float(r.args[0])).split('.'))  # '6.7' -> 6 7
        if liburing.linux_version_check(major, minor):
            msg = r.args[1] if len(r.args) > 1 else f'Kernel `{LINUX_VERSION} < {major}.{minor}`'
            pytest.skip(msg)


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "skip_linux(version:str|float|int, message:str): skipping linux version not supported.")
# linux version end <<<
