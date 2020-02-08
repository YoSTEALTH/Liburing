import sys
import time
import os.path

__all__ = ('versioning', 'parse_version')

# TODO: This module will be moved into its own project and included in `setup_requires`


def parse_version(line):
    '''
        Type
            line:   bytes
            return: str

        Example
            >>> parse_version(b"__version__ = '2020.2.3'\n")
            '2020.2.3'
    '''
    if line:
        # remove ', ", " ", '\n'
        line = line.replace(b'"', b'').replace(b"'", b'').replace(b' ', b'').replace(b'\n', b'')
        # e.g `__version__=2020.2.3`
        _, _, version = line.partition(b'=')
        # e.g '2020.2.3' or ''
        return version.decode() if b'.' in version else ''
    else:
        return ''


def versioning(package, revision=''):
    ''' Lazy persons version generator using `year.month.day` as its value.

        Type
            package:    str     # package directory
            revision:   str
            return:     str

        Example
            >>> versioning('pacakge_name')
            '2020.2.3'

            >>> versioning('pacakge_name', 'v1')
            '2020.2.3v1'

        Usage
            >>> setup(version=versioning('mylib'))

        Note
            - Auto generates date as version number, sets it in `setup(version='2020.2.3')` also
            replaces `__init__.py` file `__version__` line with `__version__ = '2020.2.3'`
            - only generates version if `python3 setup.py sdist` else uses the old version.

        Version
            0.1.0
    '''
    init_path = os.path.join(package, '__init__.py')

    with open(init_path, 'rb+') as file:
        # "__init__.py" file content
        content = file.readlines()

        # Find `__version__ = ...` line
        for index, line in enumerate(content):
            if line.startswith(b'__version__'):
                old_version = content[index]
                break
        else:
            old_version = None

        # Generate new version only if setup is built with "sdist"
        if 'sdist' in sys.argv:  # TODO: could account for 'bdist', ... ?
            # e.g '2020.2.3', '2020.2.3v1', ...
            version = time.strftime('%Y.%-m.%-d', time.localtime()) + revision
            new_version = f'__version__ = {version!r}\n'.encode()

            if old_version is None:
                # `__version__` line was not found, so lets add it to the bottom of the page.
                content.append(new_version)
            else:
                content[index] = new_version

            # write updated content
            file.seek(0)
            file.writelines(content)
            file.truncate()
        else:
            # use version number from current `__init__.py` file.
            version = parse_version(old_version)

    return version


def test_parse_line():
    assert parse_version(b"__version__ = '2020.2.3'\n") == '2020.2.3'
    assert parse_version(b'__version__= "2020.2.3"\n') == '2020.2.3'
    assert parse_version(b"__version__ = '1.2.3'\n") == '1.2.3'
    assert parse_version(b"__version__ = None\n") == ''
    assert parse_version(b"__version__ = ''\n") == ''
    assert parse_version(None) == ''
    assert parse_version(b"") == ''
