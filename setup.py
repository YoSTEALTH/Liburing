from os import cpu_count
from shutil import copy2, copytree
from os.path import join
from tempfile import TemporaryDirectory
from subprocess import run as sub_process_run
from setuptools import setup
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


threads = cpu_count()//2 or 1  # use half of cpu resources
# compiler options
Options.annotate = False
Options.fast_fail = True
Options.docstrings = True
Options.warning_errors = False

with TemporaryDirectory() as tmpdir:
    lib = join(tmpdir, 'libs/liburing')
    libsrc = join(lib, 'src')
    libinc = join(libsrc, 'include')
    copytree('libs/liburing/src', libsrc)
    for src in ('libs/liburing/configure',
                'libs/liburing/liburing-ffi.pc.in',
                'libs/liburing/liburing.pc.in',
                'libs/liburing/liburing.spec',
                'libs/liburing/Makefile',
                'libs/liburing/Makefile.common',
                'libs/liburing/Makefile.quiet'):
        copy2(src, join(tmpdir, src))

    sub_process_run(['./configure', '--use-libc'], cwd=lib, capture_output=True, check=True)
    sub_process_run(['make', f'--jobs={threads}'], cwd=lib, capture_output=True)
    # note: just runs `configure` & `make`, does not `install`.

    extension = [Extension(name='liburing.*',  # where the `.so` will be saved.
                           sources=['src/liburing/*.pyx'],
                           language='c',
                           libraries=['uring'],
                           library_dirs=[libsrc],
                           include_dirs=[libinc],
                           extra_compile_args=['-O3', '-g0'])
                 ]  # optimize & remove debug symbols + data.

    # replace temp `include` holder files with actaul `include` content.
    copytree(libinc, 'src/liburing/include', dirs_exist_ok=True)
    # install
    setup(ext_modules=cythonize(extension,
                                nthreads=threads,
                                compiler_directives={
                                    'embedsignature': True,  # show all `__doc__`
                                    'boundscheck': False,
                                    'wraparound': False,
                                    'language_level': 3}))
