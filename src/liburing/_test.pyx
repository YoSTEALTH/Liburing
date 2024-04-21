cpdef bint _io_uring_cqe_shift(io_uring ring):
    '''
        Note
            - This function is used only to test defines.
    '''
    return __io_uring_cqe_shift(&ring.ptr)

cpdef int _io_uring_cqe_index(io_uring ring, unsigned int ptr, unsigned int mask):
    '''
        Note
            - This function is used only to test defines.
    '''
    return __io_uring_cqe_index(&ring.ptr, ptr, mask)
