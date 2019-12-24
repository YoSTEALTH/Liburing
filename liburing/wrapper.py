import errno
import ctypes
import functools

__all__ = ('cwrap', 'lib')

lib = ctypes.cdll.LoadLibrary('liburing.so')
# lib = ctypes.cdll.LoadLibrary('/opt/liburing/0.3/lib/liburing.so')  # custom liburing path


def cwrap(restype, *argtypes, error_check=None):
    """ Ctypes function wrapper - easy to create, visually readable code & meaningful `help()` docs

        Type
            restype:        any                 # ctypes return type
            argtypes:       Sequence[any]       # ctypes argument type
            error_check:    bool
            return:         lib_fun             # ctypes library function

        Example
            >>> @cwrap(ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
            >>> def io_uring_queue_init(entries, ring, flags):
            ...     '''
            ...         Type
            ...             entries:    int
            ...             ring:       io_uring
            ...             flags:      int
            ...             return:     int
            ...     '''

            # or

            >>> @cwrap(ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_uint)
            >>> def io_uring_queue_init(entries: any, ring: io_uring, flags: int) -> int:
            ...     pass

        Note
            - `function_name` created must be same as `lib.function_name`
    """
    def decorate(func):
        lib_fun = getattr(lib, func.__name__)
        lib_fun.restype = restype
        lib_fun.argtypes = argtypes

        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if error_check:
                if no := lib_fun(*args, **kwargs):  # noqa
                    raise OSError(no, errno.errorcode.get(no, ''))
                return no
            else:
                return lib_fun(*args, **kwargs)
        return wrapper
    return decorate
