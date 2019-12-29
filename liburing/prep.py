import ctypes
from . import iovec, IORING_OP_READV
''' Note
        Prep functions are mainly for test and example usage only! You as a developer would have
        to write better function/library based on these example.
'''


def iovec_array(*buffers):
    '''
        Example
            >>> one = iovec_read(bytearray(5))
            >>> two = iovec_read(bytearray(5))
            >>> files = iovec_array(one, two)
            >>> files[0].iov_base
            >>> files[0].iov_len
            ...
    '''
    return (iovec * len(buffers))(*buffers)


def iovec_read(buffer):
    '''
        Example
            >>> data = bytearray(5)
            >>> iovec_read(data)
    '''
    length = len(buffer)
    arr_t1 = (ctypes.c_char * length)
    arr_p1 = ctypes.cast(arr_t1.from_buffer(buffer), ctypes.c_void_p)
    return iovec(arr_p1, length)


def iovec_write(*data):
    '''
        >>> iovec_write(b'hello', b'world')
    '''
    hold = []
    for buf in data:
        length = len(buf)
        arr_p1 = ctypes.cast(ctypes.c_char_p(buf), ctypes.c_void_p)
        hold.append(iovec(arr_p1, length))
    return (iovec * len(hold))(*hold)


def io_uring_prep_rw(op, sqe, fd, addr, _len, offset):
    '''
        Type
            op:         int
            sqe:        io_uring_sqe
            fd:         int
            addr:       # const void
            _len:       int
            offset:     int                 # __u64
            return:     None                # static inline void
    '''
    sqe = sqe.contents

    # help(sqe)
    # print(len(sqe))
    # print('contents:', sqe)
    # print('addr:', addr.iov_base)
    # print('contents:', sqe.iov_base, sqe.iov_len)
    # print('contents:', sqe.contents)
    # print('contents:', sqe.contents.addr, addr)
    # print()
    # help(sqe.contents)

    sqe.opcode = op
    sqe.flags = 0
    sqe.ioprio = 0
    sqe.fd = fd
    sqe.off = offset
    sqe.addr = addr.iov_base        # (unsigned long) addr; iovec address
    # sqe.addr = addr     # (unsigned long) addr; iovec address
    sqe.len = _len
    sqe.rw_flags = 0
    sqe.user_data = 0
    sqe.__pad2[0] = sqe.__pad2[1] = sqe.__pad2[2] = 0


def io_uring_prep_readv(sqe, fd, iovecs, nr_vecs, offset):
    '''
        Type
            sqe:        io_uring_sqe
            fd:         int
            iovecs:     iovec           # const struct iovec
            nr_vecs:    int             # unsigned
            offset:     int             # off_t
            return:     None            # static inline void
    '''
    io_uring_prep_rw(IORING_OP_READV, sqe, fd, iovecs, nr_vecs, offset)


def io_uring_cqe_seen(ring, cqe):
    '''
        Type
            ring:       io_uring
            cqe:        io_uring_cqe
            return:     None

        Note
            Must be called after `io_uring_{peek,wait}_cqe()` after the cqe has
            been processed by the application.
    '''
    # TODO: `cqe` will also be true atm! investigate to make sure it results what it should.
    if cqe:
        io_uring_cq_advance(ring, 1)


def io_uring_cq_advance(ring, nr):
    '''
        Type
            ring:       io_uring
            nr:         int
            return:     None

        Note
            Must be called after `io_uring_for_each_cqe()`
    '''
    if nr:
        cq = ring.cq

        # Ensure that the kernel only sees the new value of the head
        # index after the CQEs have been read.
        io_uring_smp_store_release(cq.khead, cq.khead + nr)


def io_uring_smp_store_release():
    # leads me to having to write https://github.com/axboe/liburing/blob/master/src/include/liburing/barrier.h#L49