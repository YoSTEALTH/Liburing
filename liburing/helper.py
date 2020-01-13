import ctypes


__all__ = ('iovec', 'sigset_t', 'kernel_timespec', 'iovec_read', 'iovec_write', 'files_fds')


# C internals
# -----------
class iovec(ctypes.Structure):
    _fields_ = ('iov_base', ctypes.c_void_p), ('iov_len', ctypes.c_size_t)


class sigset_t(ctypes.Structure):
    _fields_ = ('val', ctypes.c_uint * (1024 // (8 * ctypes.sizeof(ctypes.c_uint)))),


class kernel_timespec(ctypes.Structure):
    _fields_ = (('tv_sec',  ctypes.c_longlong),  # int64_t
                ('tv_nsec', ctypes.c_longlong))  # long long


# Python helper functions
# -----------------------
def iovec_read(*buffers):
    '''
        Example
            >>> one = bytearray(5)
            >>> two = bytearray(5)
            >>> iovec_read(one, two)
    '''
    hold = []
    for buffer in buffers:
        length = len(buffer)
        calc = (ctypes.c_char * length)
        base = ctypes.cast(calc.from_buffer(buffer), ctypes.c_void_p)
        hold.append(iovec(base, length))
    return (iovec * len(hold))(*hold)


def iovec_write(*data):
    '''
        >>> iovec_write(b'hello', b'world')
    '''
    hold = []
    for buf in data:
        base = ctypes.cast(ctypes.c_char_p(buf), ctypes.c_void_p)
        hold.append(iovec(base, len(buf)))
    return (iovec * len(hold))(*hold)


def files_fds(*fds):
    '''
        Type
            *fds:   int
            return: c_int_Array_*

        Example
            >>> files = files_fds(fd1, fd2, fd3, ...)
    '''
    return (ctypes.c_int * len(fds))(*fds)
