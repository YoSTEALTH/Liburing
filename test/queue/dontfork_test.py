import faulthandler
import os
import signal
import pytest
import liburing


def test_dontfork_not_initialized():
    with pytest.raises(RuntimeError):
        liburing.io_uring_ring_dontfork(liburing.Ring())


def _child_touches_ring(ring):
    ''' Fork, use `ring` in child, return child's wait status. '''
    pid = os.fork()
    if pid == 0:
        faulthandler.disable()  # expected crash, no traceback noise
        liburing.io_uring_get_sqe(ring)  # SIGSEGV if ring memory is not in the child.
        os._exit(0)
    return os.waitpid(pid, 0)[1]


def test_dontfork(ring):
    assert os.waitstatus_to_exitcode(_child_touches_ring(ring)) == 0  # shared by default

    assert liburing.io_uring_ring_dontfork(ring) == 0
    assert os.waitstatus_to_exitcode(_child_touches_ring(ring)) == -signal.SIGSEGV

    # parent is still fine
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_nop(sqe)
    assert liburing.io_uring_submit(ring) == 1
