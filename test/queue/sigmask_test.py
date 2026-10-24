import signal
import threading
import pytest
from liburing import *


def test_sigset_t():
    SigsetT()
    SigsetT([signal.SIGINT, signal.SIGTERM])
    with pytest.raises(ValueError):
        SigsetT([0])


def test_sigmask(ring, cqe):
    # `SIGUSR1` blocked for this thread, only `sigmask` lets it in during the wait.
    handler = signal.signal(signal.SIGUSR1, lambda *_: None)
    mask = signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGUSR1])
    try:
        # raised before the wait (no timing): blocked, so it stays pending until a wait lets it in.
        signal.pthread_kill(threading.get_ident(), signal.SIGUSR1)
        assert signal.SIGUSR1 in signal.sigpending()

        # without `sigmask`: signal stays pending, wait runs into its timeout.
        with pytest.raises(OSError) as err:
            io_uring_wait_cqes(ring, cqe, 1, timespec(0.05))
        assert not isinstance(err.value, InterruptedError)
        assert signal.SIGUSR1 in signal.sigpending()

        # with empty `sigmask`: pending signal is delivered, wait is interrupted.
        with pytest.raises(InterruptedError):
            io_uring_wait_cqes(ring, cqe, 1, timespec(2), SigsetT())
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        signal.signal(signal.SIGUSR1, handler)
