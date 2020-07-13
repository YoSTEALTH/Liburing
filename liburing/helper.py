import sys
import socket
from ._liburing import ffi, lib

__all__ = ('NULL', 'files', 'io_uring', 'io_uring_cqe', 'io_uring_cqes', 'io_uring_get_sqes',
           'iovec', 'timespec', 'time_convert', 'statx', 'sigmask', 'sockaddr', 'sockaddr_in',
           'probe')


NULL = ffi.NULL


def files(*fds):
    '''
        Example
            >>> fds = files(fd1, fd2, ...)
    '''
    return ffi.new('int[]', fds)


def io_uring():
    '''
        Example
            >>> ring = io_uring()
    '''
    return ffi.new('struct io_uring *')


def io_uring_cqe():
    ''' completion queue entry

        Example
            >>> cqe = io_uring_cqe()
    '''
    return ffi.new('struct io_uring_cqe *')


def io_uring_cqes(no=1):
    '''
        Type
            no:      int
            return:  <cdata>

        Example
            >>> cqes = io_uring_cqes()
            >>> cqes[0]

            >>> cqes = io_uring_cqes(12)
            >>> cqes[0]
            ...
            >>> cqes[11]
    '''
    return ffi.new('struct io_uring_cqe *[]', no)


def io_uring_get_sqes(ring, no=2):
    ''' Get multiple sqes

        Type
            ring:   io_uring
            no:     int
            return: Optional[<cdata>]

        Example
            >>> sqes = io_uring_get_sqes(ring, 2)
            >>> if sqes:
            ...     io_uring_prep_accept(sqes[0], ...)
    '''
    sqes = ffi.new('struct io_uring_sqe *[]', no)
    for i in range(no):
        sqe = lib.io_uring_get_sqe(ring)
        if not sqe:
            # ran out of entries, return `None` so user can try again.
            return None
        sqes[i] = sqe
    return sqes


def iovec(*buffers):
    '''
        Type
            buffers: Sequence[bytearray, memoryview]
            return:  struct iovec

        Example
            # single read
            >>> data = bytearray(5)
            >>> iov = iovec(data)

            # multiple reads
            >>> one = bytearray(5)
            >>> two = bytearray(5)
            >>> iovs = iovec(one, two)

            # single write
            >>> data = bytearray(b'hello)
            >>> iov = iovec(data)

            # multiple writes
            >>> one = bytearray(b'hello')
            >>> two = bytearray(b'world)
            >>> iovs = iovec(one, two)

            # get length
            >>> iov = iovec(bytearray(5), bytearray(5))
            >>> len(iov)
            2
    '''
    iovs = ffi.new('struct iovec []', len(buffers))
    for i, buffer in enumerate(buffers):
        iovs[i].iov_base = ffi.from_buffer(buffer)
        iovs[i].iov_len = len(buffer)
    return iovs


def timespec(seconds=0, nanoseconds=0):
    ''' Kernel Timespec

        Type
            seconds:        int
            nanoseconds:    int
            return:         struct __kernel_timespec

        Example
            >>> timespec()
            >>> timespec(None)
            fii.NULL

            >>> timespec(1, 1000000)
            ts

        Usage
            >>> io_uring_wait_cqes(..., ts=timespec(1, 2), ...)
            >>> io_uring_wait_cqes(..., ts=timespec(), ...)
            >>> io_uring_wait_cqes(..., ts=timespec(None), ...)

        Note
            - 1 nanosecond  = 0.000_000_001 second.
            - 1 millisecond = 0.001         second.
    '''
    if seconds or nanoseconds:
        ts = ffi.new('struct __kernel_timespec[1]')
        ts[0].tv_sec = seconds or 0
        ts[0].tv_nsec = nanoseconds or 0
        return ts
    else:
        return NULL


def time_convert(second):
    ''' Convert `second` to ``second, nanosecond``

        Type
            second: Union[int, float]
            return: Tuple[int, int]

        Example
            >>> time_convert(1.5)
            1, 500_000_000

            >>> time_convert(1)
            1, 0

        Usage
            >>> timespec(*time_convert(1.5))
    '''
    # second(s) to second(s), nanosecond
    return int(second // 1), int((second % 1)*1_000_000_000 // 1)


def statx(no=1):
    '''
        Type
            no:     int
            return: <cdata>

        Example
            >>> stats = statx()
            >>> io_uring_prep_statx(sqe, -1, path, 0, 0, stats)
            # or
            >>> io_uring_prep_statx(sqe, -1, path, 0, liburing.STATX_SIZE, stats)
    '''
    return ffi.new('struct statx []', no)


# TODO: needs testing
def sigmask(mask=None):
    ''' Signal Mask

        Type
            mask:   Optional[int]
            return: Union[ffi.NULL, sigset_t]

        Example
            >>> sigmask()  # None for as is.
            # or
            >>> import signal
            >>> sigmask(signal.SIG_BLOCK)

        Note
            SIG_BLOCK
                The set of blocked signals is the union of the current set and the mask argument.
            SIG_UNBLOCK
                The signals in mask are removed from the current set of blocked signals.
                It is permissible to attempt to unblock a signal which is not blocked.
            SIG_SETMASK
                The set of blocked signals is set to the mask argument.

        Warning: TODO
            - could there be a leak if `sigset` isn't being removed using `sigdelset` ???
            - maybe need to create a `with sigmask():` and have it add and clean on exit ???
    '''
    if mask is None:
        return NULL
    else:
        sigset = ffi.new('sigset_t *')
        lib.sigemptyset(sigset)
        lib.sigaddset(sigset, mask)
        return sigset


def sockaddr():
    ''' Socket Address

        Example
            >>> sock_addr, sock_len = sockaddr()
    '''
    addr = ffi.new('struct sockaddr *')
    len_ = ffi.new('socklen_t *', ffi.sizeof(addr))
    return addr, len_


def sockaddr_in(ip, port):
    '''
        Type
            ip:      str
            port:    int
            return:  Union[<cdata>, <cdata>]

        Example
            >>> addr, addrlen = sockaddr_in('127.0.0.1', 3000)
    '''
    family = socket.AF_INET
    pack = socket.inet_pton(family, ip)

    sa = ffi.new('struct sockaddr_in [1]')
    sa[0].sin_addr.s_addr = int.from_bytes(pack, sys.byteorder)
    sa[0].sin_port = socket.htons(port)
    sa[0].sin_family = family

    addr = ffi.cast('struct sockaddr[1]', sa)
    len_ = ffi.new('socklen_t[1]', [ffi.sizeof(addr)])
    return addr, len_[0]


def probe():
    ''' Find out which `io_uring` operations is supported by the kernel.

        Type
            return: Dict[str, bool]

        Example
            >>> op = probe()
            >>> op['IORING_OP_NOP']
            True

            >>> for op, supported in probe().items():
            ...     op, supported
            'IORING_OP_NOP', True

        Note
            - Dict key/value is not sorted
    '''
    get_probe = lib.io_uring_get_probe()
    r = {}
    for name in dir(lib):
        # find `IORING_OP_*` defined in "builder.py"
        if name.startswith('IORING_OP_'):
            if name != 'IORING_OP_LAST':
                value = getattr(lib, name)
                r[name] = bool(lib.io_uring_opcode_supported(get_probe, value))
    return r
