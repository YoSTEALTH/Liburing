import ctypes
from .wrapper import cwrap
from .io_uring import io_uring_sqe, io_uring_cqe, io_uring_params


# C internals
# -----------
class sigset_t(ctypes.Structure):
    _fields_ = [('val', ctypes.c_uint * (1024 // (8 * ctypes.sizeof(ctypes.c_uint))))]


class iovec(ctypes.Structure):
    _fields_ = [('iov_base', ctypes.c_void_p), ('iov_len', ctypes.c_size_t)]


class _kernel_timespec(ctypes.Structure):
    _fields_ = [('tv_sec',  ctypes.c_longlong),  # int64_t
                ('tv_nsec', ctypes.c_longlong)]  # long long


# Library interface to `io_uring`
# -----------------------------
class io_uring_sq(ctypes.Structure):
    ''' submission queue (sq) '''
    _fields_ = [('khead',         ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('ktail',         ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kring_mask',    ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kring_entries', ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kflags',        ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kdropped',      ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('array',         ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('sqes',          ctypes.POINTER(io_uring_sqe)),   # struct io_uring_sqe *

                ('sqe_head',      ctypes.c_uint),                  # unsigned
                ('sqe_tail',      ctypes.c_uint),                  # unsigned

                ('ring_sz',       ctypes.c_size_t),                # size_t
                ('ring_ptr',      ctypes.c_void_p)]                # void *


class io_uring_cq(ctypes.Structure):
    ''' completion queue (cq) '''
    _fields_ = [('khead',         ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('ktail',         ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kring_mask',    ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('kring_entries', ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('koverflow',     ctypes.POINTER(ctypes.c_uint)),  # unsigned *
                ('cqes',          ctypes.POINTER(io_uring_cqe)),   # struct io_uring_cqe *

                ('ring_sz',       ctypes.c_size_t),                # size_t
                ('ring_ptr',      ctypes.c_void_p)]                # void *


class io_uring(ctypes.Structure):
    _fields_ = [('sq',      io_uring_sq),    # struct
                ('cq',      io_uring_cq),    # struct
                ('flags',   ctypes.c_uint),  # unsigned
                ('ring_fd', ctypes.c_int)]   # int


# Library interface ('liburing.h')
# --------------------------------
@cwrap(ctypes.c_int,
       ctypes.c_uint,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(io_uring_params),
       error_check=True)
def io_uring_queue_init_params(entries, ring, p):
    '''
        Type
            entries:    int
            ring:       io_uring
            p:          io_uring_params     # p = parameter
            return:     int
    '''


@cwrap(ctypes.c_int, ctypes.c_uint, ctypes.POINTER(io_uring), ctypes.c_uint, error_check=True)
def io_uring_queue_init(entries, ring, flags, value=None):
    '''
        Type
            entries:    int
            ring:       io_uring
            flags:      int
            return:     int

        Note
            Returns -1 on error, or zero on success. On success, `ring` contains the necessary
            information to read/write to the rings.
    '''


@cwrap(ctypes.c_int,
       ctypes.c_int,
       ctypes.POINTER(io_uring_params),
       ctypes.POINTER(io_uring),
       error_check=True)
def io_uring_queue_mmap(fd, p, ring):
    '''
        Type
            fd:         int
            p:          io_uring_params     # p = parameter
            ring:       io_uring
            return:     int

        Note
            For users that want to specify `sq_thread_cpu` or `sq_thread_idle`, this interface
            is a convenient helper for mmap()ing the rings.

            Returns -1 on error, or zero on success.  On success, `ring` contains the necessary
            information to read/write to the rings.
    '''


@cwrap(None, ctypes.POINTER(io_uring))
def io_uring_queue_exit(ring):
    '''
        Type
            ring:       io_uring
            return:     None
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(ctypes.POINTER(io_uring_cqe)),
       ctypes.c_uint)
def io_uring_peek_batch_cqe(ring, cqes, count):
    '''
        Type
            ring:       io_uring
            cqes:       io_uring_cqe    # cq = completion queue
            count:      int
            return:     int

        Note
            Fill in an array of IO completions up to count, if any are available.
            Returns the amount of IO completions filled.
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(ctypes.POINTER(io_uring_cqe)),
       ctypes.c_uint,
       ctypes.POINTER(_kernel_timespec),
       ctypes.POINTER(sigset_t))
def io_uring_wait_cqes(ring, cqe_ptr, wait_nr, ts, sigmask):
    '''
        Type
            ring:       io_uring
            cqe_ptr:    io_uring_cqe        # cq = completion queue
            wait_nr:    int
            ts:         _kernel_timespec     # ts = timespec
            sigmask:    sigset_t
            return:     int

        Note
            Like `io_uring_wait_cqe()`, except it accepts a timeout value as well. Note
            that an `sqe` is used internally to handle the timeout. Applications using
            this function must never set `sqe->user_data` to `LIBURING_UDATA_TIMEOUT`

            Note that the application need not call `io_uring_submit()` before calling
            this function, as we will do that on its behalf. From this it also follows
            that this function isn't safe to use for applications that split SQ and CQ
            handling between two threads and expect that to work without synchronization,
            as this function manipulates both the SQ and CQ side.
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(ctypes.POINTER(io_uring_cqe)),
       ctypes.POINTER(_kernel_timespec))
def io_uring_wait_cqe_timeout(ring, cqe_ptr, ts):
    '''
        Type
            ring:       io_uring
            cqe_ptr:    io_uring_cqe        # cq = completion queue
            ts:         _kernel_timespec     # ts = timespec
            return:     int

        Note
            See `io_uring_wait_cqes()` - this function is the same, it just always uses
            `1` as the wait_nr.
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring))
def io_uring_submit(ring):
    '''
        Type
            ring:       io_uring
            return:     int

        Note
            Submit sqes acquired from `io_uring_get_sqe()` to the kernel.

            Returns number of sqes submitted
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring), ctypes.c_uint)
def io_uring_submit_and_wait(ring, wait_nr):
    '''
        Type
            ring:       io_uring
            wait_nr:    int
            return:     int

        Note
            - Like `io_uring_submit()`, but allows waiting for events as well.
            - Returns number of sqes submitted
    '''


@cwrap(io_uring_sqe, ctypes.POINTER(io_uring))
def io_uring_get_sqe(ring):
    '''
        Type
            ring:       io_uring
            return:     io_uring_sqe

        Note
            Return an sqe to fill. Application must later call `io_uring_submit()`
            when it's ready to tell the kernel about it. The caller may call this
            function multiple times before calling `io_uring_submit()`.

            Returns a vacant sqe, or NULL if we're full.
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(iovec),
       ctypes.c_uint,
       error_check=True)
def io_uring_register_buffers(ring, iovecs, nr_iovecs):
    '''
        Type
            ring:       io_uring
            iovecs:     iovec       # const struct iovec *iovecs
            nr_iovecs:  int
            return:     int
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring), error_check=True)
def io_uring_unregister_buffers(ring):
    '''
        Type
            ring:       io_uring
            return:     int
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.POINTER(ctypes.c_int),
       ctypes.c_uint,
       error_check=True)
def io_uring_register_files(ring, files, nr_files):
    '''
        Type
            ring:       io_uring
            files:      int         # const int *files
            nr_files:   int         # number of files
            return:     int
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring), error_check=True)
def io_uring_unregister_files(ring):
    '''
        Type
            ring:       io_uring
            return:     int
    '''


@cwrap(ctypes.c_int,
       ctypes.POINTER(io_uring),
       ctypes.c_uint,
       ctypes.POINTER(ctypes.c_int),
       ctypes.c_uint,
       error_check=True)
def io_uring_register_files_update(ring, off, files, nr_files):
    '''
        Type
            ring:       io_uring
            off:        int
            files:      List[int]       # int *files
            nr_files:   int             # number of files
            return:     int

        Note
            Register an update for an existing file set. The updates will start at `off` in the
            original array, and `nr_files` is the number of files we'll update.

            Returns number of files updated on success, -ERROR on failure.
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring), ctypes.c_int, error_check=True)
def io_uring_register_eventfd(ring, fd):
    '''
        Type
            ring:       io_uring
            fd:         int
            return:     int
    '''


@cwrap(ctypes.c_int, ctypes.POINTER(io_uring), error_check=True)
def io_uring_unregister_eventfd(ring):
    '''
        Type
            ring:       io_uring
            return:     int
    '''
