import os
import ctypes
import functools

__all__ = ('cwrap', 'lib')

lib = ctypes.cdll.LoadLibrary('liburing.so')
# lib = ctypes.cdll.LoadLibrary('/opt/liburing/0.3/lib/liburing.so')  # custom liburing path


def cwrap(restype, *argtypes, error_check=None, rewrap=None):
    ''' Ctypes function wrapper - easy to create, visually readable code & meaningful `help()` docs

        Type
            restype:        any                 # ctypes return type
            argtypes:       Sequence[any]       # ctypes argument type
            error_check:    bool
            rewrap:         bool
            return:         lib_fun             # ctypes library function

        Example
            >>> @cwrap(ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
            >>> def io_uring_queue_init(entries, ring, flags):
            ...     """
            ...         Type
            ...             entries:    int
            ...             ring:       io_uring
            ...             flags:      int
            ...             return:     int
            ...     """

            # or

            >>> @cwrap(ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
            >>> def io_uring_queue_init(entries: int, ring: io_uring, flags: int) -> int:
            ...     pass

            TODO:
                - write example for `error_check` and `rewrap`

        Note
            - `function_name` created must be same as `lib.function_name`
            - `error_check` raises appropriate exception for -errno values
    '''
    def decorate(func):
        nonlocal error_check
        try:
            lib_fun = getattr(lib, func.__name__)
            lib_fun.restype = restype
            lib_fun.argtypes = argtypes
            # enable `error_check` to be `True` if not set, as all value < 0 will be error
            if error_check is None and restype is ctypes.c_int:
                error_check = True
        except AttributeError:
            @functools.wraps(func)
            def error(*args, **kwargs):
                _ = (f'`{func.__name__}()` does not exist in {lib._name!r} version being used.')
                raise FunctionNotFoundError(_)
            return error
            # If a function does not exist in 'liburing.so' version lets ignore the error
            # on startup and only raise error when user tries to call the function itself.
        else:
            @functools.wraps(func)
            def wrapper(*args, **kwargs):
                no = lib_fun(*args, **kwargs) if not rewrap else lib_fun(*func(*args, **kwargs))
                if error_check and no < 0:  # error
                    raise OSError(-no, os.strerror(-no))
                return no  # success or value
            return wrapper
    return decorate


class FunctionNotFoundError(Exception):
    __module__ = Exception.__module__
