from sys import byteorder
from socket import AF_INET, inet_pton, htons
from ._liburing import ffi, lib
from .interface import io_uring_submit


__all__ = 'NULL', 'files', 'io_uring', 'io_uring_params', 'io_uring_cqe', 'io_uring_cqes', 'io_uring_get_sqes', \
          'get_sqes', 'get_sqe', 'iovec', 'open_how', 'timespec', 'time_convert', 'statx', 'sigmask', 'sockaddr', \
          'sockaddr_in', 'probe'


# localize
new = ffi.new
NULL = ffi.NULL
cast = ffi.cast
sizeof = ffi.sizeof
from_buffer = ffi.from_buffer

sigaddset = lib.sigaddset
sigemptyset = lib.sigemptyset
io_uring_get_sqe = lib.io_uring_get_sqe
io_uring_get_probe = lib.io_uring_get_probe
io_uring_sq_space_left = lib.io_uring_sq_space_left
io_uring_opcode_supported = lib.io_uring_opcode_supported

io_uring_free_probe = getattr(lib, 'io_uring_free_probe', None)


def files(*fds):
    '''
        Example
            >>> fds = files(fd1, fd2, ...)
    '''
    return new('int[]', fds)


def io_uring():
    '''
        Example
            >>> ring = io_uring()
    '''
    return new('struct io_uring *')


def io_uring_params():
    '''
        Example
            >>> params = io_uring_params()
    '''
    return new('struct io_uring_params *')


def io_uring_cqe():
    ''' completion queue entry

        Example
            >>> cqe = io_uring_cqe()
    '''
    return new('struct io_uring_cqe *')


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
    return new('struct io_uring_cqe *[]', no)


def io_uring_get_sqes(ring, no=2):
    ''' Get multiple sqes

        Type
            ring:   io_uring
            no:     int
            return: Optional[<cdata>]

        Example
            >>> if sqes := io_uring_get_sqes(ring, 2):
            ...     io_uring_prep_read(sqes[0], ...)
            ...     io_uring_prep_write(sqes[1], ...)

        Note
            - look into `get_sqes` for alternative version
    '''
    # make sure enough sq entries are available before proceeding
    if no > io_uring_sq_space_left(ring):
        return None
    sqes = new('struct io_uring_sqe *[]', no)
    for i in range(no):
        sqes[i] = io_uring_get_sqe(ring)
    return sqes


def get_sqes(ring, count):
    ''' Safely get multiple `sqes`

        Type
            ring:   io_uring
            count:  int
            return: List[io_uring_sqe]

        Example
            >>> for sqe in get_sqes(ring, 2):
            ...     io_uring_prep_read(sqe, ...)
            ...     io_uring_sqe_set_flags(sqe, IOSQE_IO_LINK)
            ...     ...

            # or

            >>> sqes = get_sqes(ring, 2)
            ...
            >>> sqe = sqes[0]
            >>> io_uring_prep_read(sqe, ...)
            >>> io_uring_sqe_set_flags(sqe, IOSQE_IO_LINK)
            ...
            >>> sqe = sqes[1]
            ... ...

        Note
            - Getting multiple `sqes` is mainly useful when linking multiple `sqe` together using `IOSQE_IO_LINK`
            - Auto submits previous queue entries if sqes required is < count
    '''
    # make sure `count` is not greater then init's `entries`
    if count > ring.sq.kring_entries[0]:
        raise ValueError('`get_sqes()` - `count` can not be higher then `entries` in `io_uring_queue_init()`')
    elif count < io_uring_sq_space_left(ring):
        io_uring_submit(ring)
    return [io_uring_get_sqe(ring) for _ in range(count)]
    # note: using List vs Generator so all the sqes is ready to be used at once


def get_sqe(ring):
    ''' Safely get single `sqe`

        Type
            ring:   io_uring
            return: io_uring_sqe

        Example
            >>> sqe = get_sqe(ring)

        Note
            - Auto submits previous queue entries if no sqe is free.
    '''
    while True:
        sqe = io_uring_get_sqe(ring)
        if sqe:  # note: not using `:=` for python 3.6 support
            return sqe
        io_uring_submit(ring)


def iovec(*buffers):
    '''
        Type
            buffers: Union[bytearray, memoryview, mmap]
            return:  struct iovec

        Example
            # single read
            >>> data = bytearray(5)
            >>> iov = iovec(data)

            # for multiple reads
            >>> one = bytearray(5)
            >>> two = bytearray(5)
            >>> iovs = iovec(one, two)

            # single write
            >>> data = bytearray(b'hello)
            >>> iov = iovec(data)

            # for multiple writes
            >>> one = bytearray(b'hello')
            >>> two = bytearray(b'world)
            >>> iovs = iovec(one, two)

            # get length
            >>> buffers = [bytearray(5), bytearray(5)]
            >>> iov = iovec(*buffers)
            >>> len(iov)
            2

        WARNING
            - You should hold on to reference passed into `iovec` till the transaction is complete,
            or else the object passed into `iovec` will disappear resulting in corrupt data and 
            unforeseen results e.g:

                # Good
                >>> one = bytearray(...)
                >>> iov = iovec(one)

                # Bad
                >>> iov = iovec(bytearray(...))
    '''
    iovs = new('struct iovec []', len(buffers))
    for i, buffer in enumerate(buffers):
        iovs[i].iov_base = from_buffer(buffer)
        iovs[i].iov_len = len(buffer)
    return iovs


def open_how(flags, mode=0, resolve=0):
    '''
        Type
            flags:   int
            mode:    int
            resolve: int
            return:  <cdata>

        Example
            >>> how = open_how(O_RDWR, 0, RESOLVE_CACHED)
            >>> io_uring_prep_openat2(..., how)

        Resolve
            RESOLVE_BENEATH
            RESOLVE_IN_ROOT
            RESOLVE_NO_MAGICLINKS
            RESOLVE_NO_SYMLINKS
            RESOLVE_NO_XDEV
            RESOLVE_CACHED

        Note
            - visit https://man7.org/linux/man-pages/man2/openat2.2.html for more information.
    '''
    how = new('struct open_how [1]')
    how[0].flags = flags
    how[0].mode = mode
    how[0].resolve = resolve
    return how


def timespec(seconds=0, nanoseconds=0):
    ''' Kernel Timespec

        Type
            seconds:        int
            nanoseconds:    int
            return:         struct __kernel_timespec

        Example
            >>> timespec()
            >>> timespec(None)
            ffi.NULL

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
        ts = new('struct __kernel_timespec[1]')
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
            >>> stat = statx()
            >>> io_uring_prep_statx(sqe, -1, path, 0, 0, stat)
            # or
            >>> io_uring_prep_statx(sqe, -1, path, 0, liburing.STATX_SIZE, stat)
            >>> stat[0].stx_size
            123
    '''
    return new('struct statx []', no)


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
        sigset = new('sigset_t *')
        sigemptyset(sigset)
        sigaddset(sigset, mask)
        return sigset


def sockaddr():
    ''' Socket Address

        Example
            >>> sock_addr, sock_len = sockaddr()
    '''
    addr = new('struct sockaddr *')
    len_ = new('socklen_t *', sizeof(addr))
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
    family = AF_INET
    pack = inet_pton(family, ip)

    sa = new('struct sockaddr_in [1]')
    sa[0].sin_addr.s_addr = int.from_bytes(pack, byteorder)
    sa[0].sin_port = htons(port)
    sa[0].sin_family = family

    addr = cast('struct sockaddr[1]', sa)
    len_ = new('socklen_t[1]', [sizeof(addr)])
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
    get_probe = io_uring_get_probe()
    r = {}
    for name in dir(lib):  # find `IORING_OP_*` defined in "builder.py"
        if name.startswith('IORING_OP_') and name != 'IORING_OP_LAST':
            value = getattr(lib, name)
            r[name] = bool(io_uring_opcode_supported(get_probe, value))
    if io_uring_free_probe:
        io_uring_free_probe(get_probe)
    return r
