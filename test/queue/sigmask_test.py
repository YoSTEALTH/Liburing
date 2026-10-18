import signal
import threading
import pytest
import liburing


def test_sigset_t():
    liburing.SigsetT()
    liburing.SigsetT([signal.SIGINT, signal.SIGTERM])
    with pytest.raises(ValueError):
        liburing.SigsetT([0])


def test_sigmask(ring, cqe):
    # `SIGUSR1` blocked for this thread, only `sigmask` lets it in during the wait.
    handler = signal.signal(signal.SIGUSR1, lambda *_: None)
    mask = signal.pthread_sigmask(signal.SIG_BLOCK, [signal.SIGUSR1])
    try:
        tid = threading.get_ident()
        kill = lambda: signal.pthread_kill(tid, signal.SIGUSR1)

        # without `sigmask`: signal stays pending, wait runs into its timeout.
        threading.Timer(0.05, kill).start()
        with pytest.raises(OSError) as err:
            liburing.io_uring_wait_cqes(ring, cqe, 1, liburing.timespec(0.3))
        assert not isinstance(err.value, InterruptedError)
        assert signal.SIGUSR1 in signal.sigpending()

        # with empty `sigmask`: pending signal is delivered, wait is interrupted.
        with pytest.raises(InterruptedError):
            liburing.io_uring_wait_cqes(ring, cqe, 1, liburing.timespec(2), liburing.SigsetT())
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, mask)
        signal.signal(signal.SIGUSR1, handler)
