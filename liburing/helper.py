from ._liburing import ffi, lib

__all__ = ('files', 'io_uring', 'io_uring_cqe', 'io_uring_cqes', 'iovec', 'timespec', 'sigmask')


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


def io_uring_cqes():
    #
    return ffi.new('struct io_uring_cqe **')


def iovec(*buffers):
    '''
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
    '''
    iovs = ffi.new('struct iovec *')
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

            >>> timespec(1, 2)
            ts

        Usage
            >>> io_uring_wait_cqes(..., ts=timespec(1, 2), ...)
            >>> io_uring_wait_cqes(..., ts=timespec(), ...)
            >>> io_uring_wait_cqes(..., ts=timespec(None), ...)
    '''
    if seconds or nanoseconds:
        ts = ffi.new('struct __kernel_timespec[1]')
        ts[0].tv_sec = seconds or 0
        ts[0].tv_nsec = nanoseconds or 0
        return ts
    else:
        return ffi.NULL


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
        return ffi.NULL
    else:
        sigset = ffi.new('sigset_t *')
        lib.sigemptyset(sigset)
        lib.sigaddset(sigset, mask)
        return sigset
