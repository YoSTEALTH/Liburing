from cython cimport boundscheck
from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .error cimport memory_error, index_error
from collections.abc import Iterable


cdef class timespec:
    ''' Kernel Timespec

        Example
            >>> ts = timespec(1)        # int
            >>> ts = timespec(1.5)      # float
            >>> io_uring_prep_timeout(sqe, ts, ...)

            # manually set raw value
            >>> ts = timespec()
            >>> ts.tv_sec = 1           # second
            >>> ts.tv_nsec = 500000000  # nanosecond
            >>> io_uring_prep_timeout(sqe, ts, ...)
    '''
    def __cinit__(self, double second=0):
        self.ptr = <__kernel_timespec*>PyMem_RawCalloc(1, sizeof(__kernel_timespec))
        if self.ptr is NULL:
            memory_error(self)
        if second:
            # note: converting from `double` is the reason for casting
            self.ptr.tv_sec = <int64_t>(second / 1)
            self.ptr.tv_nsec = <long long>(((second % 1) * 1_000_000_000) / 1)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def tv_sec(self):
        return self.ptr.tv_sec

    @tv_sec.setter
    def tv_sec(self, int64_t second):
        self.ptr.tv_sec = second

    @property
    def tv_nsec(self):
        return self.ptr.tv_nsec

    @tv_nsec.setter
    def tv_nsec(self, long long nanosecond):
        self.ptr.tv_nsec = nanosecond


cdef class iovec:
    ''' Vector I/O data structure '''
    def __cinit__(self, object buffers):
        '''
            Type
                buffers: Union[bytes, bytearray, memoryview, List[...], Tuple[...]]
                return:  None

            Example
                # read single
                # -----------
                >>> iov_read = iovec(bytearray(11))
                >>> io_uring_prep_readv(sqe, fd, iov_read, ...)

                # read multiple
                # -------------
                >>> iov_read = iovec([bytearray(1), bytearray(2), bytearray(3)])
                >>> io_uring_prep_readv(sqe, fd, iov_read, ...)

                # write single
                # ------------
                >>> iov_write = iovec(b'hello world')
                >>> io_uring_prep_readv(sqe, fd, iov_write, ...)

                # write multiple
                # --------------
                >>> iov_write = iovec([b'1', b'22', b'333'])
                >>> io_uring_prep_readv(sqe, fd, iov_write, ...)

            Note
                - Make sure to hold on to variable you are passing into `iovec` so it does not get
                garbage collected before you get the chance to use it!
        '''
        cdef:
            unsigned int index
            str error
            const unsigned char[:] buffer

        if buffers:
            self.ref = []  # reference holder
            if isinstance(buffers, (bytes, bytearray, memoryview)):
                self.ref.append(buffers)
            elif isinstance(buffers, Iterable):
                self.ref.extend(buffers)
            else:
                raise TypeError(f'`{self.__class__.__name__}(buffers)` type not supported!')

            self.len = len(self.ref)

            if self.len > SC_IOV_MAX:
                error = f'`{self.__class__.__name__}()` - `buffers` length of {self.len!r} ' \
                        f'exceeds `SC_IOV_MAX` limit set by OS of {SC_IOV_MAX!r}'
                raise OverflowError(error)

            self.ptr = <iovec_t*>PyMem_RawCalloc(self.len, sizeof(iovec_t))
            if self.ptr is NULL:
                memory_error(self)

            for index in range(self.len):
                buffer = self.ref[index]
                self.ptr[index].iov_base = <void*>&buffer[0]  # starting address
                self.ptr[index].iov_len = len(self.ref[index])

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __bool__(self):
        return self.ptr is not NULL

    def __len__(self):
        return self.len

    @boundscheck(True)
    def __getitem__(self, unsigned int index):
        cdef iovec iov
        if index:
            iov = iovec()
            iov.ptr = &self.ptr[index]
            if iov.ptr is not NULL:
                return iov
            index_error(self, index)
        return self

    @property
    def iov_base(self):
        return self.ref[0]

    @property
    def iov_len(self):
        return self.ptr.iov_len


cdef class siginfo:
    pass
