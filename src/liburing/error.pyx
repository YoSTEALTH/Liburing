from libc.errno cimport errno
from libc.string cimport strerror


cpdef inline int trap_error(int no, str msg='') except -1 nogil:
    ''' Trap Error

        Type
            no     int
            msg    str
            return int

        Example
            >>> trap_error(1)
            1

            >>> trap_error(-11)
            BlockingIOError: [Errno 11] Resource temporarily unavailable

            >>> trap_error(-11, 'some message')
            BlockingIOError: [Errno 11] some message

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

    with gil:
        raise_error(no, msg)


cdef inline void raise_error(int no=-1, str msg='') except *:
    ''' This function will only raise Error '''
    no = -errno or no
    raise OSError(-no, msg or strerror(-no).decode())


cpdef inline void memory_error(object self, str msg='is out of memory!') except *:
    ''' Raises MemoryError '''
    raise MemoryError(f'`{self.__class__.__name__}()` {msg}')


cpdef inline void index_error(object self, unsigned int index, str msg='out of range!') except *:
    ''' Raises IndexError '''
    raise IndexError(f'`{self.__class__.__name__}()[{index}]` {msg}')
