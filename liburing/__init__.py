''' This is a light-weight python wrapper around liburing library,
    which is a helper to setup and tear-down io_uring instances. '''
from .liburing import *  # noqa
from .io_uring import *  # noqa

# enables `help(liburing)` to display everything
__all__ = [i for i in locals().keys() if not i.startswith(('_', 'cwrap'))]
__version__ = '0.0.6'
