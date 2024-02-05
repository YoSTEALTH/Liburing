# cython: linetrace=False


cpdef inline int trap_error(int no):
    ''' Trap Error

        Type
            no     int
            return int

        Example
            >>> trap_error(1)
            1

            >>> trap_error(-11)
            BlockingIOError(...)

            >>> trap_error(-1)
            # dynamic error based on `errno`

        Note
            - any `no >= 0` is considered safe.
            - if `no=-1` it will check with `errno` first to see if proper error is set,
              and raise that as exception

        Special
            Thanks to "_habnabit" for coming up with this function name
    '''
    if no >= 0:
        return no
    raise_error(no)


cpdef inline void raise_error(signed int no=-1) except *:
    ''' This function will only raise Error '''
    no = -errno or no
    cdef str error = strerror(-no).decode()
    raise OSError(-no, error)


cpdef inline void memory_error(object self) except *:
    ''' Raises MemoryError '''
    cdef str error = f'`{self.__class__.__name__}()` is out of memory!'
    raise MemoryError(error)
