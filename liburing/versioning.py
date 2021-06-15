from sys import version_info
from platform import release, system
if version_info < (3, 10):
    from distutils.version import LooseVersion
else:
    from setuptools._distutils.version import LooseVersion
from functools import lru_cache


__all__ = 'skip_os',
RELEASE = LooseVersion(release())
OS = system().casefold()


@lru_cache(maxsize=None)
def skip_os(version, os=None):
    ''' Skip if OS version is not supported.

        Type
            version: str
            os:      str
            return:  bool

        Example
            # Assume Linux version is "5.13"

            >>> skip = skip_os('5.14')
            True
            >>> @pytest.mark.skipif(skip, reason='Requires Linux 5.14+')

            >>> skip = skip_os('5.11')
            False
            >>> @pytest.mark.skipif(skip, reason='Requires Linux 5.11+')


            >>> if skip_os('5.1', 'linux'):
            ...     ...
    '''
    required = LooseVersion(version)
    if os:
        return OS != os.casefold() or RELEASE < required
    return RELEASE < required
