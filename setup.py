from os import cpu_count
from subprocess import run as sub_process_run
from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


# manually change this:
os_liburing = False  # use OS `liburing.so`?
# note: OS `liburing.so` tend to be outdated! Try it, run test, if no error is raised its good :)
package = 'liburing'
threads = cpu_count()//2 or 1  # use half of cpu resources
sources = ['liburing/*.pyx']
# sources = ['liburing/version.pyx', 'liburing/helper.pyx']
language = 'c'
lib_name = f'{package}.*'

# compiler options
Options.warning_errors = True   # turn all warnings into errors.
# if __debug__:  # `gcc --help=common` for more info
#     Options.fast_fail = False
#     Options.annotate = True  # generate `*.html` file for debugging & optimization purposes.
#     compile_args = ['Oz', 'g0']
# else:
Options.fast_fail = False
Options.annotate = False
# compile_args = ['O3', 'g0']

compile_args = []  # bypass

if os_liburing:  # compile using OS `liburing.so`
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           extra_compile_args=compile_args)]
else:  # compile `liburing` C library as well.
    path = 'libs/liburing'
    makefile = 'libs/liburing/Makefile'
    src_path = 'libs/liburing/src'
    inc_path = 'libs/liburing/src/include'
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           include_dirs=[inc_path],
                           # TODO: see if this will include "includes" folder!
                           # cython_include_dirs=['liburing/includes'],
                           # note: commenting bellow will make liburing compile from `/usr/lib/`
                           libraries=[package[3:]],  # remove `lib` part.
                           library_dirs=[src_path],
                           extra_compile_args=compile_args)]
    # configure custom C liburing install
    sub_process_run(['./configure'], cwd=path, capture_output=True, check=True)
    sub_process_run(['make'], cwd=path, capture_output=True, check=True)
    sub_process_run(['make install'], cwd=path, capture_output=True, check=True)

setup(ext_modules=cythonize(extension,
                            nthreads=threads,
                            compiler_directives={'embedsignature': True,  # show all `__doc__`
                                                 'language_level': '3'}))
