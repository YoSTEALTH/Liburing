import os
import os.path
import pytest
import pathlib
import getpass
import tempfile
import platform
import functools
from packaging.version import Version


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


@functools.lru_cache
def parse_linux_version(version):
    '''
        Example
            >>> parse_linux_version('6.7.5')
            '6.7.5'  # <class 'packaging.version.Version'>
    '''
    return Version(version)


LINUX_VERSION = parse_linux_version(platform.release().split('-')[0])


@pytest.fixture(autouse=True)
def skip_by_platform(request):
    '''
        Example
            >>> @pytest.mark.skip_linux('6.7.5')
            >>> def test_function():
            ...
            test.py::test_function SKIPPED (Linux version `6.7.4 < 6.7.5` required version.)

            >>> @pytest.mark.skip_linux('6.7.5', 'custom message')
            >>> def test_function():
            ...
            test.py::test_function SKIPPED (custom message)

            >>> @pytest.mark.skip_linux('6.7.5', '')
            >>> def test_function():
            ...
            test.py::test_function SKIPPED
    '''
    if r := request.node.get_closest_marker('skip_linux'):
        if LINUX_VERSION < (res := parse_linux_version(r.args[0])):
            pytest.skip(r.args[1] if len(r.args) > 1 else f'Linux version `{LINUX_VERSION} < {res}` required version.')


def pytest_configure(config):
    config.addinivalue_line("markers",
                            "skip_linux(version, message): skipping linux version not supported.")
