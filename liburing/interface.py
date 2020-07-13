from ._liburing import lib
from .wrapper import trap_error
from .helper import NULL


# Library interface
# -----------------
def io_uring_opcode_supported(p, op):
    '''
        Type
            p:      io_uring_probe
            op:     int
            return: int

        Version
            0.4.0
    '''
    return trap_error(lib.io_uring_opcode_supported(p, op))


def io_uring_queue_init_params(entries, ring, p):
    '''
        Type
            entries:  int
            ring:     io_uring
            p:        io_uring_params
            return:   int
    '''
    if entries < 1:
        _ = 'io_uring_queue_init_params(entries) can not be < 1'
        raise ValueError(_)
    return trap_error(lib.io_uring_queue_init_params(entries, ring, p))


def io_uring_queue_init(entries, ring, flags=0):
    '''
        Example
            >>> ring = io_uring()
            >>> io_uring_queue_init(1024, ring, 0)
            >>> io_uring_queue_init(1024, ring, IORING_SETUP_IOPOLL)
            >>> io_uring_queue_init(1024, ring, IORING_SETUP_SQPOLL)

        Type
            entries:  int
            ring:     io_uring
            flags:    int
            return:   int
    '''
    if entries < 1:
        _ = '`io_uring_queue_init(entries)` can not be ``< 1``'
        raise ValueError(_)
    return trap_error(lib.io_uring_queue_init(entries, ring, flags))


def io_uring_queue_mmap(fd, p, ring):
    '''
        Type
            fd:     int
            p:      io_uring_params
            ring:   io_uring
            return: int
    '''
    return trap_error(lib.io_uring_queue_mmap(fd, p, ring))


def io_uring_ring_dontfork(ring):
    '''
        Type
            ring:   io_uring
            return: int

        Version
            0.4.0
    '''
    return trap_error(lib.io_uring_ring_dontfork(ring))


def io_uring_queue_exit(ring):
    '''
        Type
            ring:   io_uring
            return: int
    '''
    # Only call `io_uring_queue_exit(ring)` if `ring_fd` is true, or else
    # `Segmentation fault (core dumped)` could happen in certain scenarios.
    if ring.ring_fd:
        lib.io_uring_queue_exit(ring)


def io_uring_peek_batch_cqe(ring, cqes, count):
    '''
        Type
            ring:   io_uring
            cqes:   io_uring_cqes
            count:  int
            return: int
    '''
    return trap_error(lib.io_uring_peek_batch_cqe(ring, cqes, count))


def io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts=NULL, sm=NULL):
    ''' Wait Completion Queue Entry

        Type
            ring:    io_uring
            cqe_ptr: io_uring_cqes
            wait_nr: int
            ts:      timespec
            sm:      sigmask
            return:  int

        Example
            >>> cqes = io_uring_cqes()
            ...
            >>> io_uring_wait_cqes(ring, cqes, 2)
            >>> cqe = cqes[0]
            # do something with first `cqe`
            >>> liburing.io_uring_cqe_seen(ring, cqe)
            >>> io_uring_wait_cqes(ring, cqes, 2)
            >>> cqe = cqes[0]
            # do something with second `cqe`
            >>> liburing.io_uring_cqe_seen(ring, cqe)

        Note
            Like `io_uring_wait_cqe()`, except it accepts a timeout value as well. Note
            that an `sqe` is used internally to handle the timeout. Applications using
            this function must never set `sqe->user_data` to `LIBURING_UDATA_TIMEOUT`!

            If 'ts' is specified, the application need not call `io_uring_submit()` before
            calling this function, as we will do that on its behalf. From this it also follows
            that this function isn't safe to use for applications that split SQ and CQ
            handling between two threads and expect that to work without synchronization,
            as this function manipulates both the SQ and CQ side.
    '''
    return trap_error(lib.io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts, sm))


def io_uring_wait_cqe_timeout(ring, cqe_ptr, ts):
    '''
        Type
            ring:    io_uring
            cqe_ptr: io_uring_cqes
            ts:      timespec
            return:  int
    '''
    return trap_error(lib.io_uring_wait_cqe_timeout(ring, cqe_ptr, ts))


def io_uring_submit(ring):
    '''
        Type
            ring:   io_uring
            return: int
    '''
    return trap_error(lib.io_uring_submit(ring))


def io_uring_submit_and_wait(ring, wait_nr):
    '''
        Type
            ring:    io_uring
            wait_nr: int
            return:  int
    '''
    return trap_error(lib.io_uring_submit_and_wait(ring, wait_nr))


def io_uring_register_buffers(ring, iovecs, nr_iovecs):
    '''
        Type
            ring:      io_uring
            iovecs:    iovec
            nr_iovecs: int
            return:    int
    '''
    return trap_error(lib.io_uring_register_buffers(ring, iovecs, nr_iovecs))


def io_uring_unregister_buffers(ring):
    '''
        Type
            ring:   io_uring
            return: int
    '''
    return trap_error(lib.io_uring_unregister_buffers(ring))


def io_uring_register_files(ring, files, nr_files):
    '''
        Type
            ring:     io_uring
            files:    files
            nr_files: int
            return:   int
    '''
    return trap_error(lib.io_uring_register_files(ring, files, nr_files))


def io_uring_unregister_files(ring):
    '''
        Type
            ring:   io_uring
            return: int
    '''
    return trap_error(lib.io_uring_unregister_files(ring))


def io_uring_register_files_update(ring, off, files, nr_files):
    '''
        Type
            ring:     io_uring
            off:      int
            files:    files
            nr_files: int
            return:   int
    '''
    return trap_error(lib.io_uring_register_files_update(ring, off, files, nr_files))


def io_uring_register_eventfd(ring, fd):
    '''
        Type
            ring:   io_uring
            fd:     int
            return: int
    '''
    return trap_error(lib.io_uring_register_eventfd(ring, fd))


def io_uring_unregister_eventfd(ring):
    '''
        Type
            ring:   io_uring
            return: int
    '''
    return trap_error(lib.io_uring_unregister_eventfd(ring))


def io_uring_register_eventfd_async(ring, event_fd):
    '''
        Type
            ring:     io_uring
            event_fd: int
            return:   int

        Version
            0.6.0
    '''
    return trap_error(lib.io_uring_register_eventfd_async(ring, event_fd))


def io_uring_register_probe(ring, p, nr):
    '''
        Type
            ring:   io_uring
            p:      io_uring_probe
            nr:     int
            return: int

        Version
            0.4.0
    '''
    return trap_error(lib.io_uring_register_probe(ring, p, nr))


def io_uring_register_personality(ring):
    '''
        Type
            ring:   io_uring
            return: int

        Version
            0.4.0
    '''
    return trap_error(lib.io_uring_register_personality(ring))


def io_uring_unregister_personality(ring, id):
    '''
        Type
            ring:   io_uring
            id:     int
            return: int

        Version
            0.4.0
    '''
    return trap_error(lib.io_uring_unregister_personality(ring, id))


# Peek & Wait
# -----------
def io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr):
    '''
        Note
            Return an IO completion, waiting for `wait_nr` completions if one isn't
            readily available. Returns ``0`` with `cqe_ptr` filled in on success, ``-errno`` on
            failure.
    '''
    return trap_error(lib.io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr))


def io_uring_peek_cqe(ring, cqe_ptr):
    '''
        Note
            Return an IO completion, if one is readily available. Returns ``0`` with
            `cqe_ptr` filled in on success, ``-errno`` on failure.
    '''
    return trap_error(lib.io_uring_peek_cqe(ring, cqe_ptr))


def io_uring_wait_cqe(ring, cqe_ptr):
    '''
        Note
            Return an IO completion, waiting for it if necessary. Returns ``0`` with
            `cqe_ptr` filled in on success, ``-errno`` on failure.
    '''
    return trap_error(lib.io_uring_wait_cqe(ring, cqe_ptr))


# Prep Functions
# --------------
def io_uring_prep_read(sqe, fd, buf, nbytes, offset, flags=0):
    '''
        Type
            sqe:    io_uring_sqe
            fd:     int
            buf:    ffi.from_buffer
            nbytes: int
            offset: int
            flags:  int
            return: None

        Example
            >>> buffer = bytearray(11)
            >>> iov = iovec(buffer)
            >>> io_uring_prep_read(sqe, fd, iov[0].iov_base, iov[0].iov_len, 0, 0)
            ...
            >>> buffer
            b'hello world'

        Version
            linux: 5.6

        Note
            - Liburing C library does not provide much needed `flags` parameter
    '''
    lib.io_uring_prep_read(sqe, fd, buf, nbytes, offset)
    if flags:
        lib.io_uring_sqe_set_flags(sqe, flags)


def io_uring_prep_readv(sqe, fd, iovecs, nr_vecs, offset, flags=0):
    '''
        Type
            fd:      int
            iovecs:  iovec
            nr_vecs: int
            offset:  int
            flags:   int
            return:  None

        Example
            >>> fd = os.open(...)
            >>> buffer = bytearray(5)
            >>> iov = iovec(buffer)
            >>> sqe = io_uring_get_sqe(ring)
            >>> io_uring_prep_readv(sqe, fd, iov, len(iov), 0, os.RWF_NOWAIT)
            ...
            >>> buffer
            b'hello'

        Note
            - Liburing C library does not provide much needed `flags` parameter
    '''
    lib.io_uring_prep_readv(sqe, fd, iovecs, nr_vecs, offset)
    if flags:
        lib.io_uring_sqe_set_flags(sqe, flags)


def io_uring_prep_write(sqe, fd, buf, nbytes, offset, flags=0):
    '''
        Type
            sqe:    io_uring_sqe
            fd:     int
            buf:    ffi.from_buffer
            nbytes: int
            offset: int
            flags:  int
            return: None

        Example
            >>> iov = iovec(bytearray(b'hello world'))
            >>> io_uring_prep_write(sqe, fd, iov[0].iov_base, iov[0].iov_len, 0, 0)
            ...

        Version
            linux: 5.6

        Note
            - Liburing C library does not provide much needed `flags` parameter
    '''
    lib.io_uring_prep_write(sqe, fd, buf, nbytes, offset)
    if flags:
        lib.io_uring_sqe_set_flags(sqe, flags)


def io_uring_prep_writev(sqe, fd, iovecs, nr_vecs, offset, flags=0):
    '''
        Type
            fd:      int
            iovecs:  iovec
            nr_vecs: int
            offset:  int
            flags:   int
            return:  None

        Example
            >>> iov = iovec(bytearray(b'hello'), bytearray(b'world'))
            >>> io_uring_prep_writev(sqe, fd, iov, len(iov), 0, 0)
            ...

        Note
            - Liburing C library does not provide much needed `flags` parameter
    '''
    lib.io_uring_prep_writev(sqe, fd, iovecs, nr_vecs, offset)
    if flags:
        lib.io_uring_sqe_set_flags(sqe, flags)
