from os import cpu_count, environ  # noqa
from shutil import copytree
from os.path import join, exists
from tempfile import gettempdir
from subprocess import run as sub_process_run
from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


# enable `clang` compiler
# environ['LDSHARED'] = 'clang -shared'  # <- manually uncomment this

debug = False  # <- manually change this
os_liburing = False  # <- manually change this
# note: OS `liburing` tends to be outdated! Try it, run test, if no error is raised its good :)

libsrc = join(gettempdir(), 'liburing-source')  # /tmp/liburing-source
threads = cpu_count()//2 or 1  # use half of cpu resources
sources = ['src/liburing/*.pyx']
lib_name = 'liburing.*'
language = 'c'
uring = 'uring'
# uring = 'uring-ffi'

# compiler options
if debug:
    Options.warning_errors = True  # turn all warnings into errors.
    Options.fast_fail = False
    Options.annotate = True  # generate `*.html` file for debugging & optimization.
else:
    Options.warning_errors = False
    Options.fast_fail = True
    Options.annotate = False
Options.docstrings = True
compile_args = [
    '-O3',
    '-g0'
]  # Optimize and remove debug symbols + data.


if os_liburing:  # compile using OS installed `liburing`
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           libraries=[uring],
                           extra_compile_args=compile_args)]
else:  # (default) compile using latest `liburing` that's included.
    extension = [Extension(name=lib_name,  # where the `.so` will be saved.
                           sources=sources,
                           language=language,
                           libraries=[uring],
                           library_dirs=[join(libsrc, 'src')],
                           include_dirs=[join(libsrc, 'src/include')],
                           extra_compile_args=compile_args,
                           define_macros=[('CYTHON_TRACE_NOGIL', 1 if debug else 0)])]


if __name__ == '__main__':
    if not os_liburing:
        if not exists(libsrc):
            copytree('libs/liburing/', libsrc)
            sub_process_run(['./configure'], cwd=libsrc, capture_output=True, check=True)
            sub_process_run(['make', f'--jobs={threads}'], cwd=libsrc, capture_output=True)

    setup(ext_modules=cythonize(extension,
                                nthreads=threads,
                                compiler_directives={
                                    'embedsignature': True,  # show all `__doc__`
                                    'linetrace': True if debug else False,  # enable for coverage
                                    'boundscheck': False,
                                    'wraparound': False,
                                    'language_level': 3}))
