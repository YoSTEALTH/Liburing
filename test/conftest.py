import os
import os.path
import pytest
import pathlib
import getpass
import tempfile


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
