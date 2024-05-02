from cython cimport boundscheck  # don't move
from collections.abc import Iterable


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
            str                     error
            unsigned int            index, length
            const unsigned char[:]  buffer

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

            self.ptr = <__iovec*>PyMem_RawCalloc(self.len, sizeof(__iovec))
            if self.ptr is NULL:
                memory_error(self)

            for index in range(self.len):
                buffer = self.ref[index]
                if not (length := len(self.ref[index])):
                    raise ValueError(f'`{self.__class__.__name__}()` can not be length of `0`')
                self.ptr[index].iov_base = <void*>&buffer[0]  # starting address
                self.ptr[index].iov_len = length

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __bool__(self):
        return self.ptr is not NULL

    def __len__(self):
        return self.len

    def __getitem__(self, unsigned int index):
        cdef iovec iov
        if index == 0:
            return self
        elif self.len and index < self.len:
            iov = iovec()
            iov.ptr = &self.ptr[index]
            if iov.ptr.iov_len:
                return iov
        index_error(self, index)

    @property
    def iov_base(self):
        return self.ref[0]

    @property
    def iov_len(self):
        return self.ptr.iov_len


cpdef inline void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil:
    __io_uring_prep_close(sqe.ptr, fd)

cpdef inline void io_uring_prep_close_direct(io_uring_sqe sqe,
                                             unsigned int file_index) noexcept nogil:
    __io_uring_prep_close_direct(sqe.ptr, file_index)


cpdef inline void io_uring_prep_provide_buffers(io_uring_sqe sqe,
                                                unsigned char[:] addr,  # void *addr,
                                                int len,
                                                int nr,
                                                int bgid,
                                                int bid=0) noexcept nogil:
    __io_uring_prep_provide_buffers(sqe.ptr, &addr[0], len, nr, bgid, bid)

cpdef inline void io_uring_prep_remove_buffers(io_uring_sqe sqe, int nr, int bgid) noexcept nogil:
    __io_uring_prep_remove_buffers(sqe.ptr, nr, bgid)
