from setuptools import setup, find_packages
from distutils.version import LooseVersion
from datestamp import stamp
from platform import uname

package = 'liburing'
platform = uname()
required = '5.5'

# check to make sure `package` is only installed on supported Linux version.
if platform.system != 'Linux' or LooseVersion(platform.release) < LooseVersion(required):
    _ = f'"{package.title()}" only supported to run on Linux {required}+'
    raise RuntimeError(_)

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
                   'Topic :: Software Development :: Libraries :: Python Modules'])
