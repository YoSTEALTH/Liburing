import os

__all__ = ('trap_error',)


def trap_error(no):
    '''
        Type
            no:     int
            return: int

        Example
            >>> trap_error(lib.function_name(*args, *kwargs))

        Note
            - Raises appropriate python exception for `-errno` returned by C.
            - `trap_error` name suggested by _habnabit @ https://github.com/habnabit
    '''
    if no < 0:
        raise OSError(-no, os.strerror(-no))
    return no  # success or value
