import faulthandler
import os
import resource
import signal
import pytest
from liburing import *


def test_dontfork_not_initialized():
    with pytest.raises(RuntimeError):
        io_uring_ring_dontfork(Ring())


def _child_touches_ring(ring):
    '''Fork, use `ring` in child, return child's wait status.'''
    pid = os.fork()
    if pid == 0:
        faulthandler.disable()  # expected crash, no traceback noise
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))  # and no core dump
        io_uring_get_sqe(ring)  # SIGSEGV if ring memory is not in the child.
        os._exit(0)
    return os.waitpid(pid, 0)[1]


def test_dontfork(ring):
    assert os.waitstatus_to_exitcode(_child_touches_ring(ring)) == 0  # shared by default

    assert io_uring_ring_dontfork(ring) == 0
    assert os.waitstatus_to_exitcode(_child_touches_ring(ring)) == -signal.SIGSEGV

    # parent is still fine
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_nop(sqe)
    assert io_uring_submit(ring) == 1
