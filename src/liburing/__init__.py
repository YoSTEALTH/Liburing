from . import liburing
from .liburing import *
from .liburing import __version__ as __version__

del liburing  # the submodule: `from liburing import *` gives only its names
