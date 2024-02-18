from cython cimport boundscheck
from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .error cimport memory_error, index_error
from .liburing cimport io_uring_sqe_set_flags_c, io_uring_sqe_set_data64_c


cdef class io_uring_sqe:
    ''' IO submission data structure (Submission Queue Entry)

        Example
            # single
            >>> sqe = io_uring_sqe()
            >>> io_uring_prep_read(sqe, ...)

            # multiple
            >>> sqe = io_uring_sqe(2)
            >>> io_uring_prep_write(sqe[0], ...)
            >>> io_uring_prep_read(sqe[1], ...)
    '''
    def __cinit__(self, unsigned int num=1):
        cdef str error
        if num:
            self.ptr = <io_uring_sqe_t*>PyMem_RawCalloc(num, sizeof(io_uring_sqe_t))
            if self.ptr is NULL:
                memory_error(self)
            if num > 1:
                self.ref = [None]*(num-1)  # do not hold `0` reference.
        else:
            self.ptr = NULL
        self.len = num
        # note: if `self.len` is not set it means its for internally `ptr` reference use.

    def __dealloc__(self):
        if self.len and self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __bool__(self):
        return self.ptr is not NULL

    def __len__(self):
        return self.len
        
    @boundscheck(True)
    def __getitem__(self, unsigned int index):
        cdef io_uring_sqe sqe
        if self.ptr is not NULL:
            if index == 0:
                return self
            elif self.len and index < self.len:
                if (sqe := self.ref[index-1]) is not None:
                    return sqe  # from reference cache

                # create new reference class
                sqe = io_uring_sqe(0)  # `0` is set to indicated `ptr` is being set for internal use
                sqe.ptr = &self.ptr[index]
                if sqe.ptr is not NULL:
                    # cache sqe as this class attribute
                    self.ref[index-1] = sqe
                    return sqe
                
        index_error(self, index, 'out of `sqe`')

    @property
    def flags(self) -> __u8:
        return self.ptr.flags

    @flags.setter
    def flags(self, __u8 flags):
        io_uring_sqe_set_flags_c(self.ptr, flags)

    @property
    def user_data(self) -> __u64:
        return self.ptr.user_data

    @user_data.setter
    def user_data(self, __u64 data):
        io_uring_sqe_set_data64_c(self.ptr, data)


cdef class io_uring_cqe:
    ''' IO completion data structure (Completion Queue Entry)

        Example
            >>> cqes = io_uring_cqe()

            # single
            # ------
            >>> cqe = cqes  # same as `cqes[0]`
            >>> cqe.res
            0
            >>> cqe.flags
            0
            >>> cqe.user_data
            123

            # get item
            # --------
            >>> cqes[0].user_data
            123

            # iter
            # ----
            >>> ready = io_uring_cq_ready(ring)
            >>> for i in range(ready):
            ...     cqe = cqes[i]
            ...     cqe.user_data
            ...     io_uring_cq_advance(ring, 1)
            123

        Note
            - `cqes = io_uring_cqe()` only needs to be defined once, and reused.
            - Use `io_uring_cq_ready(ring)` to figure out how many cqe's are ready.
    '''
    @boundscheck(True)
    def __getitem__(self, unsigned int index):
        cdef io_uring_cqe cqe
        if self.ptr is NULL:
            index_error(self, index, 'out of `cqe`')
        if index:
            cqe = io_uring_cqe()
            cqe.ptr = &self.ptr[index]
            if cqe.ptr is not NULL:
                return cqe
            index_error(self, index, 'out of `cqe`')
        return self
        # note: no need to cache items since `cqe` is normally called once or passed around.

    def __bool__(self):
        return self.ptr is not NULL

    def __repr__(self):
        if self.ptr is not NULL:
            return f'{self.__class__.__name__}(user_data={self.ptr.user_data!r}, ' \
                   f'res={self.ptr.res!r}, flags={self.ptr.flags!r})'
        memory_error(self, 'out of `cqe`')

    @property
    def user_data(self) -> __u64:
        if self.ptr is not NULL:
            return self.ptr.user_data
        memory_error(self, 'out of `cqe`')

    @property
    def res(self) -> __s32:
        if self.ptr is not NULL:
            return self.ptr.res
        memory_error(self, 'out of `cqe`')

    @property
    def flags(self) -> __u32:
        if self.ptr is not NULL:
            return self.ptr.flags
        memory_error(self, 'out of `cqe`')
