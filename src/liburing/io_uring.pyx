# cython: linetrace=False
from libc.stdlib cimport calloc, free
from .helper cimport memory_error


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
            self.ptr = <io_uring_sqe_t*>calloc(num, sizeof(io_uring_sqe_t))
            if self.ptr is NULL:
                memory_error(self)
            if num > 1:
                self.ref = [None]*(num-1)  # do not hold `0` reference.
        else:
            self.ptr = NULL
        self.len = num

    def __dealloc__(self):
        if self.len and self.ptr is not NULL:
            free(self.ptr)

    def __bool__(self):
        return not self.ptr is NULL

    def __len__(self):
        return self.len
        # note: `self.len` is not set for internally used `ptr` to reference.

    def __getitem__(self, unsigned int index):
        cdef io_uring_sqe sqe
        cdef str error

        if index == 0:
            return self
        elif index < self.len:
            if (sqe := self.ref[index-1]) is not None:
                return sqe  # from reference cache
            # create new reference class
            sqe = io_uring_sqe(0)
            sqe.ptr = &self.ptr[index]
            if sqe.ptr is NULL:
                error = f'{self.__class__.__name__}()[{index}]'
                raise IndexError(error)
            # note: `len(sqe)` will be `0` since its a pointer and
            #       to make sure `free()` isn't called on it.
            # cache sqe as this class attribute
            self.ref[index-1] = sqe
            return sqe
        else:
            error = f'{self.__class__.__name__}()[{index}]'
            raise IndexError(error)


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
    def __bool__(self):
        return not self.ptr is NULL

    def __getitem__(self, unsigned int index):
        cdef io_uring_cqe cqe
        if index:
            cqe = io_uring_cqe()
            cqe.ptr = &self.ptr[index]
            if cqe.ptr is NULL:  # TODO: need to test this.
                raise IndexError(f'`{self.__class__.__name__}()[{index}]` is out of range')
            return cqe
        return self
        # note: no need to cache items since `cqe` is normally called once or passed around.

    def __repr__(self):
        return f'{self.__class__.__name__}(user_data={self.ptr.user_data!r}, res={self.ptr.res!r}, flags={self.ptr.flags!r})'

    @property
    def user_data(self):
        return self.ptr.user_data  # type: header.__u64

    @property
    def res(self):
        return self.ptr.res

    @property
    def flags(self):
        return self.ptr.flags
