import ctypes
from . import iovec, IORING_OP_READV, IORING_OP_WRITEV
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


def iovec_read(*buffers):
    '''
        Example
            >>> one = bytearray(5)
            >>> two = bytearray(5)
            >>> iovec_read(one, two)
    '''
    hold = []
    for buffer in buffers:
        length = len(buffer)
        calc = (ctypes.c_char * length)
        base = ctypes.cast(calc.from_buffer(buffer), ctypes.c_void_p)
        hold.append(iovec(base, length))
    return (iovec * len(hold))(*hold)


def iovec_write(*data):
    '''
        >>> iovec_write(b'hello', b'world')
    '''
    hold = []
    for buf in data:
        base = ctypes.cast(ctypes.c_char_p(buf), ctypes.c_void_p)
        hold.append(iovec(base, len(buf)))
    return (iovec * len(hold))(*hold)


def io_uring_prep_rw(op, sqe, fd, addr, len_, offset):
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

    # print('sqe:', sqe)
    # print('here:', dir(sqe))
    # print('addr:', addr)
    # print('sqe.addr:', sqe.addr, addr.iov_base)
    # print('fd:', sqe.fd)

    sqe.opcode = op
    sqe.flags = 0
    sqe.ioprio = 0
    sqe.fd = fd
    sqe.off = offset
    sqe.addr = ctypes.addressof(addr)    # (unsigned long) addr;
    sqe.len = len_
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


def io_uring_prep_writev(sqe, fd, iovecs, nr_vecs, offset):
    '''
        Type
            sqe:        io_uring_sqe
            fd:         int
            iovecs:     iovec           # const struct iovec
            nr_vecs:    int             # unsigned
            offset:     int             # off_t
            return:     None            # static inline void
    '''
    io_uring_prep_rw(IORING_OP_WRITEV, sqe, fd, iovecs, nr_vecs, offset)


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
    # print('here here:', cqe.contents)
    # print('here here:', dir(cqe))
    # print('here here:', cqe)
    if cqe.contents:
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

        # print('khead:', cq.khead)
        # print('dir:', dir(cq.khead))
        # print('content:', cq.khead.contents)

        # cq.khead.contents += ctypes.c_uint(nr)
        # cq.khead.contents = ctypes.c_uint(cq.khead.contents) + ctypes.c_uint(nr)

        # print('cq:', dir(cq))

        # Ensure that the kernel only sees the new value of the head
        # index after the CQEs have been read.
        io_uring_smp_store_release(cq.khead, cq.khead + nr)
        # io_uring_smp_store_release(cq.khead, *cq.khead + ctypes.c_uint(nr))
        # io_uring_smp_store_release(cq.khead, *cq.khead + ctypes.c_uint(nr))


def io_uring_smp_store_release(p, v):
    # leads me to having to write https://github.com/axboe/liburing/blob/master/src/include/liburing/barrier.h#L49
    pass
