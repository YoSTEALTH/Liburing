from ._liburing import ffi, lib  # noqa
from ._liburing.lib import *  # noqa
from .interface import *  # noqa 
from .wrapper import *  # noqa 
from .helper import *  # noqa 
'''
    This is a Python wrapper around liburing C library,
    which is a helper to setup and tear-down io_uring instances.
'''
# note:
#   - `.interface` module functions will override `lib` functions for better user experience.
#   - `lib` and `ffi` is provided for those that like to tinker with cffi.
#   - enables `help(liburing)` to display everything
__all__ = [i for i in locals().keys() if not i.startswith('_')]
__liburing__ = '0.6.0'
__version__ = '2020.7.13'
