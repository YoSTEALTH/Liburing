cpdef bint _io_uring_cqe_shift(io_uring ring):
    '''
        Note
            - This function is used only to test macro functions.
    '''
    return __io_uring_cqe_shift(&ring.ptr)

cpdef int _io_uring_cqe_index(io_uring ring, unsigned int ptr, unsigned int mask):
    '''
        Note
            - This function is used only to test macro functions.
    '''
    return __io_uring_cqe_index(&ring.ptr, ptr, mask)



def test_cqe_get_index():
    cdef:
        io_uring ring = io_uring()
        io_uring_cqe cqe = io_uring_cqe()

    io_uring_queue_init(2, ring)
    try:
        assert (0, 0) == cqe.get_index(0)
        assert (0, 0) == cqe.get_index(1)

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = 1

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = 2

        assert io_uring_submit_and_wait_timeout(ring, cqe, 2) == 2

        assert (0, 1) == cqe.get_index(0)
        assert (0, 2) == cqe.get_index(1)
        assert (0, 0) == cqe.get_index(2)  # error/no cqe
    finally:
        io_uring_queue_exit(ring)
