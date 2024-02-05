# cython: linetrace=False
from libc.stdlib cimport calloc, free
from .helper cimport memory_error


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
        cdef str error
        self.ptr = <__kernel_timespec*>calloc(1, sizeof(__kernel_timespec))
        if self.ptr is NULL:
            memory_error(self)
        if second:
            # note: converting from `double` is the reason for casting
            self.ptr.tv_sec  = <int64_t>(second / 1)
            self.ptr.tv_nsec = <long long>(((second % 1) * 1_000_000_000) / 1)

    def __dealloc__(self):
        if self.ptr is not NULL:
            free(self.ptr)

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
    ''' Vector I/O data structure

        Example
            # read
            # ====
            >>> read_buffer = [bytes(11)]
            >>> read_buffer = [bytearray(11)]
            >>> read_buffer = [memoryview(bytearray(11))]
            ...
            >>> iov_read = iovec(read_buffer)
            >>> io_uring_prep_readv(sqe, fd, iov_read, ...)

            # write
            # =====
            >>> write_buffer = [b'hello world']
            >>> write_buffer = [bytearray(b'hello world')]
            >>> write_buffer = [memoryview(bytearray(b'hello world'))]
            ...
            >>> iov_write = iovec(write_buffer)
            >>> io_uring_prep_writev(sqe, fd, iov_write, ...)

        Note
            - Make sure to hold on to variable you are passing into `iovec` so it does not get
            garbage collected before you get the chance to use it!
            - Indexing is not supported for now! e.g. `iovec[0]`
    '''
    def __cinit__(self, list buffers not None):
        cdef:
            unsigned int           buffers_len, index
            const unsigned char[:] buffer
            str                    error

        if (buffers_len := len(buffers)) > SC_IOV_MAX:
            error = f'`{self.__class__.__name__}()` - `buffers` length of {buffers_len!r} '
            error += f'exceeds `SC_IOV_MAX` limit set by OS of {SC_IOV_MAX!r}'
            raise OverflowError(error)
        elif buffers_len:
            self.len = buffers_len
            self.ptr = <iovec_t*>calloc(buffers_len, sizeof(iovec_t))
            if self.ptr is NULL:
                memory_error(self)
            for index in range(buffers_len):
                buffer = buffers[index]
                self.ptr[index].iov_base = <void*>&buffer[0]   # starting address
                self.ptr[index].iov_len = len(buffers[index])  # size of the memory pointed to by iov_base.

    def __dealloc__(self):
        if self.ptr is not NULL:
            free(self.ptr)

    def __getitem__(self, int index):
        # TODO:
        raise NotImplementedError('Indexing is not supported for now! e.g. `iovec[0]`')

    def __len__(self):
        return self.len

    # TODO:
    # @property
    # def iov_base(self):
    #     return self.ptr.iov_base

    # TODO:
    # @iov_base.setter
    # def iov_base(self, ?):
    #     self.ptr.iov_base = ?

    @property
    def iov_len(self):
        return self.ptr.iov_len

    # TODO:
    # @iov_len.setter
    # def iov_len(self, ?):
    #     self.ptr.iov_len = ?
