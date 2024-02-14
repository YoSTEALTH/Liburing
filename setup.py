from os import cpu_count
from os.path import exists
from subprocess import run as sub_process_run
from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


debug = __debug__
os_liburing = False  # <- manually change this
# note: OS `liburing` tends to be outdated! Try it, run test, if no error is raised its good :)

threads = cpu_count()//2 or 1  # use half of cpu resources
sources = ['src/liburing/*.pyx']
lib_name = 'liburing.*'
language = 'c'
# uring = 'uring'
uring = 'uring-ffi'

# compiler options
if debug:
    Options.docstrings = True
    Options.warning_errors = True  # turn all warnings into errors.
    Options.fast_fail = False
    Options.annotate = True  # generate `*.html` file for debugging & optimization.
    compile_args = ['-Og']
else:
    Options.docstrings = False
    Options.warning_errors = False
    Options.fast_fail = True
    Options.annotate = False
    compile_args = ['-O3']

if os_liburing:  # compile using OS `liburing.so`
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           libraries=[uring],
                           extra_compile_args=compile_args)]
else:  # compile `liburing` C library as well.
    path = 'libs/liburing'
    src_path = 'libs/liburing/src'
    inc_path = 'libs/liburing/src/include'
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           libraries=[uring],
                           include_dirs=[inc_path],
                           library_dirs=[src_path],
                           extra_compile_args=compile_args,
                           define_macros=[('CYTHON_TRACE_NOGIL', 1 if debug else 0)])]
    if not exists('libs/liburing/src/include/liburing/compat.h'):
        sub_process_run(['./configure'], cwd=path, capture_output=True, check=True)
        sub_process_run(['make', f'--jobs={threads}'], cwd=path, capture_output=True)  # do not check

setup(ext_modules=cythonize(extension,
                            nthreads=threads,
                            compiler_directives={'embedsignature': True,  # show all `__doc__`
                                                 'linetrace': True if debug else False,  # enable for coverage
                                                 'language_level': 3}))
