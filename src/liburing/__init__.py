from . import liburing, version
from .liburing import *
from .liburing import __version__ as __version__
from .version import *

del liburing, version  # the submodules: `from liburing import *` gives only their names
