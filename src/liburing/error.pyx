from libc.errno cimport errno
from libc.string cimport strerror


cpdef inline int trap_error(int no) nogil:
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

    with gil:
        raise_error(no)

cdef inline void raise_error(signed int no=-1) except *:
    ''' This function will only raise Error '''
    no = -errno or no
    raise OSError(-no, strerror(-no))

cpdef inline void memory_error(object self, str msg='') except *:
    ''' Raises MemoryError '''
    if not msg:
        msg = 'is out of memory!'
    raise MemoryError(f'`{self.__class__.__name__}()` {msg}')

cpdef inline void index_error(object self, unsigned int index, str msg='') except *:
    ''' Raises IndexError '''
    if not msg:
        msg = 'out of range!'
    raise IndexError(f'`{self.__class__.__name__}()[{index}]` {msg}')
