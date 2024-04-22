from os import cpu_count
from shutil import copy2, copytree, rmtree
from os.path import join
from tempfile import mkdtemp
from subprocess import run as sub_process_run
from setuptools import setup
from setuptools.command.build_ext import build_ext
from Cython.Build import cythonize
from Cython.Compiler import Options
from Cython.Distutils import Extension


class BuildExt(build_ext):

    def initialize_options(self):
        super().initialize_options()
        self.parallel = threads

    def build_extensions(self):
        copytree('libs/liburing/src', libsrc)
        for src in ('libs/liburing/configure',
                    'libs/liburing/liburing-ffi.pc.in',
                    'libs/liburing/liburing.pc.in',
                    'libs/liburing/liburing.spec',
                    'libs/liburing/Makefile',
                    'libs/liburing/Makefile.common',
                    'libs/liburing/Makefile.quiet'):
            copy2(src, join(tmpdir, src))

        # sub_process_run(['./configure', '--use-libc'], cwd=lib, capture_output=True, check=True)
        sub_process_run(['./configure'], cwd=lib, capture_output=True, check=True)
        sub_process_run(['make', f'--jobs={threads}'], cwd=lib, capture_output=True)
        # note: just runs `configure` & `make`, does not `install`.

        # replace `include` placeholder files with actual content.
        copytree(libinc, 'src/liburing/include', dirs_exist_ok=True)
        super().build_extensions()


if __name__ == '__main__':
    # uring = 'uring'
    uring = 'uring-ffi'
    tmpdir = mkdtemp()
    threads = cpu_count()
    # compiler options
    Options.annotate = False
    Options.fast_fail = True
    Options.docstrings = True
    Options.warning_errors = False

    try:
        lib = join(tmpdir, 'libs/liburing')
        libsrc = join(lib, 'src')
        libinc = join(libsrc, 'include')
        extension = [Extension(name='liburing.*',  # where the `.so` will be saved.
                               sources=['src/liburing/*.pyx'],
                               language='c',
                               libraries=[uring],
                               library_dirs=[libsrc],
                               include_dirs=[libinc],
                               # optimize & remove debug symbols + data.
                               extra_compile_args=['-O3', '-g0'])]
        # install
        setup(cmdclass={'build_ext': BuildExt},
              ext_modules=cythonize(extension,
                                    nthreads=threads,
                                    compiler_directives={'embedsignature': True,  # show `__doc__`
                                                         'boundscheck': False,
                                                         'wraparound': False,
                                                         'language_level': 3}))
    finally:
        rmtree(tmpdir)
