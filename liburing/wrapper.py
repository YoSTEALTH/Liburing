import os

__all__ = ('trap_error',)


def trap_error(no):
    '''
        Type
            no:     int
            return: int

        Example
            >>> def normal_function(arg):
            ...     return arg

            >>> trap_error(normal_function(123))
            123

            >>> trap_error(normal_function(-11))
            BlockingIOError: [Errno 11] Resource temporarily unavailable

        Note
            - Raises appropriate python exception for `-errno` returned by C.
    '''
    if no < 0:
        raise OSError(-no, os.strerror(-no))
    return no  # success or value
