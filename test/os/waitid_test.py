import os
import signal

import pytest

import liburing


def test_siginfo_t():
    info = liburing.SiginfoT()
    assert (info.si_signo, info.si_errno, info.si_code, info.si_pid, info.si_uid, info.si_status) == (0, 0, 0, 0, 0, 0)
    with pytest.raises(TypeError):
        liburing.SiginfoT(1)


@pytest.mark.requires_op("IORING_OP_WAITID")
def test_prep_waitid(ring, cqe):
    pid = os.posix_spawn("/bin/sh", ["sh", "-c", "exit 7"], os.environ)
    info = liburing.SiginfoT()
    sqe = liburing.io_uring_get_sqe(ring)
    liburing.io_uring_prep_waitid(sqe, os.P_PID, pid, info, os.WEXITED)
    assert liburing.io_uring_submit_and_wait(ring, 1) == 1
    assert liburing.io_uring_peek_cqe(ring, cqe) == 0
    assert cqe[0].res == 0
    liburing.io_uring_cqe_seen(ring, cqe[0])
    assert (info.si_pid, info.si_code, info.si_status, info.si_uid) == (pid, os.CLD_EXITED, 7, os.getuid())
    assert info.si_signo == signal.SIGCHLD
