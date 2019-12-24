from setuptools import setup, find_packages

with open('README.rst', 'r') as file:
    long_description = file.read()

setup(name='liburing',
      author='STEALTH',
      version='0.0.6',
      description=('This is a light-weight python wrapper around liburing library,'
                   'which is a helper to setup and tear-down io_uring instances.'),
      python_requires='>=3.8',
      long_description=long_description,
      long_description_content_type="text/x-rst",
      packages=find_packages(),
      url='https://github.com/YoSTEALTH/Liburing',
      # Info: https://pypi.python.org/pypi?%3Aaction=list_classifiers
      classifiers=['License :: Public Domain',
                   'Operating System :: POSIX :: Linux',
                   'Intended Audience :: Developers',
                   # 'Development Status :: 1 - Planning',
                   'Development Status :: 2 - Pre-Alpha',
                   # 'Development Status :: 3 - Alpha',
                   # 'Development Status :: 4 - Beta',
                   # 'Development Status :: 5 - Production/Stable',
                   # 'Development Status :: 6 - Mature',
                   # 'Development Status :: 7 - Inactive',
                   'Programming Language :: Python :: 3.8',
                   'Topic :: Software Development :: Libraries :: Python Modules'])
