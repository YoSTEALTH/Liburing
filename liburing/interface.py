from ._liburing import lib
from .wrapper import trap_error
from .helper import timespec, sigmask


# Library interface
# -----------------
def io_uring_queue_init_params(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_queue_init_params(*args, **kwargs))


def io_uring_queue_init(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_queue_init(*args, **kwargs))


def io_uring_queue_mmap(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_queue_mmap(*args, **kwargs))


def io_uring_peek_batch_cqe(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_peek_batch_cqe(*args, **kwargs))


def io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts=None, sm=None):
    ''' Wait Completion Queue Entry

        Example
            >>> cqe = io_uring_cqe()
            >>> io_uring_wait_cqes(ring, cqe, 2)

        Note
            Like io_uring_wait_cqe(), except it accepts a timeout value as well. Note
            that an sqe is used internally to handle the timeout. Applications using
            this function must never set sqe->user_data to LIBURING_UDATA_TIMEOUT!

            Note that the application need not call io_uring_submit() before calling
            this function, as we will do that on its behalf. From this it also follows
            that this function isn't safe to use for applications that split SQ and CQ
            handling between two threads and expect that to work without synchronization,
            as this function manipulates both the SQ and CQ side.
    '''
    ts = timespec(ts)
    sm = sigmask(sm)
    return trap_error(lib.io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts, sm))


def io_uring_submit(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_submit(*args, **kwargs))


def io_uring_submit_and_wait(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_submit_and_wait(*args, **kwargs))


def io_uring_register_buffers(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_register_buffers(*args, **kwargs))


def io_uring_unregister_buffers(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_unregister_buffers(*args, **kwargs))


def io_uring_register_files(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_register_files(*args, **kwargs))


def io_uring_unregister_files(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_unregister_files(*args, **kwargs))


def io_uring_register_files_update(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_register_files_update(*args, **kwargs))


def io_uring_register_eventfd(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_register_eventfd(*args, **kwargs))


def io_uring_unregister_eventfd(*args, **kwargs):
    '''
        ...
    '''
    return trap_error(lib.io_uring_unregister_eventfd(*args, **kwargs))


# TODO:
# #define io_uring_for_each_cqe(ring, head, cqe)


def io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr):
    '''
        Note
            Return an IO completion, waiting for 'wait_nr' completions if one isn't
            readily available. Returns 0 with cqe_ptr filled in on success, `-errno` on
            failure.
    '''
    return trap_error(lib.io_uring_wait_cqe_nr(ring, cqe_ptr, wait_nr))


def io_uring_peek_cqe(ring, cqe_ptr):
    '''
        Note
            Return an IO completion, if one is readily available. Returns 0 with
            cqe_ptr filled in on success, `-errno` on failure.
    '''
    return trap_error(lib.io_uring_peek_cqe(ring, cqe_ptr))


def io_uring_wait_cqe(ring, cqe_ptr):
    '''
        Note
            Return an IO completion, waiting for it if necessary. Returns 0 with
            cqe_ptr filled in on success, `-errno` on failure.
    '''
    return trap_error(lib.io_uring_wait_cqe(ring, cqe_ptr))
