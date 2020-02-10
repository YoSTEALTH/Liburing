from ._liburing import ffi, lib  # noqa
from ._liburing.lib import *  # noqa
from .interface import *  # noqa 
from .helper import *  # noqa 
# note:
#   - `.interface` module functions will override `lib` functions for better user experience.
#   - `lib` and `ffi` is provided for those that like to tinker with cffi.
'''
    This is a Python wrapper around liburing C library,
    which is a helper to setup and tear-down io_uring instances.
'''
__liburing__ = '0.3.0'
__version__ = '2020.2.10'
