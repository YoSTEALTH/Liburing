from sys import version_info
from platform import release
from setuptools import setup, find_packages
from datestamp import stamp
if version_info < (3, 10):
    from distutils.version import LooseVersion
else:
    from setuptools._distutils.version import LooseVersion


package = 'liburing'
current_os_version = release()
required_os_version = '5.1'


# check to make sure `package` is only installed on supported Linux version.
if LooseVersion(current_os_version) < LooseVersion(required_os_version):
    raise RuntimeError(f'"{package.title()}" only supported to run on Linux {required_os_version}+')


with open('README.rst', 'r') as file:
    long_description = file.read()


setup(url='https://github.com/YoSTEALTH/Liburing',
      name=package,
      author='STEALTH',
      version=stamp(package),  # version number is auto generated.
      packages=find_packages(),
      description=('This is a Python + CFFI wrapper around Liburing C library, '
                   'which is a helper to setup and tear-down io_uring instances.'),
      cffi_modules=['builder.py:ffi'],
      python_requires='>=3.6',
      install_requires=['cffi'],
      long_description=long_description,
      include_package_data=True,
      long_description_content_type="text/x-rst",
      classifiers=['License :: Public Domain',
                   'Operating System :: POSIX :: Linux',
                   'Intended Audience :: Developers',
                   # 'Development Status :: 1 - Planning',
                   # 'Development Status :: 2 - Pre-Alpha',
                   'Development Status :: 3 - Alpha',
                   # 'Development Status :: 4 - Beta',
                   # 'Development Status :: 5 - Production/Stable',
                   # 'Development Status :: 6 - Mature',
                   # 'Development Status :: 7 - Inactive',
                   'Programming Language :: Python :: 3.6',
                   'Programming Language :: Python :: 3.7',
                   'Programming Language :: Python :: 3.8',
                   'Programming Language :: Python :: 3.9',
                   'Programming Language :: Python :: 3.10',
                   'Topic :: Software Development :: Libraries :: Python Modules'])
