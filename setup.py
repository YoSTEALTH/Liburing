from os import cpu_count
from subprocess import run as sub_process_run
from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


# manually change this:
os_liburing = False  # use OS `liburing.so`?
# note: OS `liburing.so` tend to be outdated! Try it, run test, if no error is raised its good :)

threads = cpu_count()//2 or 1  # use half of cpu resources
sources = ['src/liburing/*.pyx']
language = 'c'
lib_name = 'src.liburing.*'

# compiler options
Options.warning_errors = True  # turn all warnings into errors.
Options.fast_fail = False
Options.annotate = False  # generate `*.html` file for debugging & optimization purposes.
compile_args = ['-Ofast']  # `gcc --help=common` for more info


if os_liburing:  # compile using OS `liburing.so`
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           extra_compile_args=compile_args)]
else:  # compile `liburing` C library as well.
    path = 'libs/liburing'
    src_path = 'libs/liburing/src'
    inc_path = 'libs/liburing/src/include'
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           include_dirs=[inc_path],
                           # TODO: see if this will include "includes" folder!
                           # cython_include_dirs=['liburing/includes'],
                           # note: commenting bellow will make liburing compile from `/usr/lib/`
                           libraries=['uring'],
                           library_dirs=[src_path],
                           extra_compile_args=compile_args)]
    sub_process_run(['./configure'], cwd=path, capture_output=True, check=True)
    # sub_process_run(['make'], cwd=path, capture_output=False, check=True)

setup(ext_modules=cythonize(extension,
                            nthreads=threads,
                            compiler_directives={
                                'embedsignature': True,  # show all `__doc__`
                                'language_level': '3'}))
