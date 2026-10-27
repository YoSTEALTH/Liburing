"""`UnsupportedError`: a feature the kernel lacks, told apart from a bad argument (both are `EINVAL`)."""

import errno
import os
import pathlib
import subprocess
import sys
import textwrap
import kernel
import pytest
from liburing import *

KERNEL = f"Kernel `{kernel.LINUX_VERSION}`"
ROOT = pathlib.Path(__file__).parent.parent
# where this `liburing` was imported from (`<dir>/liburing/__init__.so`: the star import does not bind the name)
PACKAGE_DIR = str(pathlib.Path(sys.modules["liburing"].__file__).parent.parent)

# Runs in a child process: a seccomp filter makes `io_uring_register` fail with `EINVAL` for opcodes from
# `IORING_REGISTER_QUERY` (35) on, which is what a kernel without `QUERY` does. Irreversible, hence the child.
NO_QUERY = textwrap.dedent("""
    import ctypes, struct
    libc = ctypes.CDLL(None, use_errno=True)
    def op(code, k, jt=0, jf=0):
        return struct.pack("HBBI", code, jt, jf, k)
    LD, JEQ, JGE, RET = 0x20, 0x15, 0x35, 0x06  # BPF_LD|BPF_W|BPF_ABS, BPF_JMP|BPF_{JEQ,JGE}|BPF_K, BPF_RET|BPF_K
    prog = b"".join((
        op(LD, 0),                  # seccomp_data.nr
        op(JEQ, 427, 0, 3),         # io_uring_register
        op(LD, 24),                 # low half of args[1]: the opcode
        op(JGE, 35, 0, 1),          # >= IORING_REGISTER_QUERY
        op(RET, 0x00050000 | 22),   # SECCOMP_RET_ERRNO | EINVAL
        op(RET, 0x7FFF0000),        # SECCOMP_RET_ALLOW
    ))
    buf = ctypes.create_string_buffer(prog)
    fprog = struct.pack("HxxxxxxP", len(prog) // 8, ctypes.addressof(buf))
    assert libc.prctl(38, 1, 0, 0, 0) == 0  # PR_SET_NO_NEW_PRIVS
    assert libc.prctl(22, 2, ctypes.c_char_p(fprog), 0, 0) == 0, ctypes.get_errno()  # PR_SET_SECCOMP, FILTER
""")


def run_without_query(code):
    """`code` run by a child process that sees a kernel without `IORING_REGISTER_QUERY`."""
    return subprocess.run(
        [sys.executable, "-c", NO_QUERY + textwrap.dedent(code)],
        cwd=ROOT,
        env={**os.environ, "PYTHONPATH": PACKAGE_DIR},
        capture_output=True,
        text=True,
        timeout=60,
        check=False,  # the caller reads its output and exit status
    )


def test_UnsupportedError_is_OSError():
    assert issubclass(UnsupportedError, OSError)


def test_unknown_register_opcode(ring):
    with pytest.raises(UnsupportedError, match="does not support `register opcode 200`") as e:
        io_uring_register(ring.ring_fd, 200, 0, None)
    assert e.value.errno == errno.EINVAL


def test_bad_argument_stays_OSError(ring):
    # `IORING_REGISTER_EVENTFD` is supported: a bad fd is the caller's error.
    with pytest.raises(OSError) as e:
        io_uring_register_eventfd(ring, -1)
    assert type(e.value) is not UnsupportedError
    assert e.value.errno == errno.EBADF


def test_unknown_setup_flag():
    io_uring_register_query(Query())  # setup flags are known only from `QUERY`: skips without it
    with pytest.raises(UnsupportedError, match="does not support `setup flag 0x40000000`") as e:
        io_uring_queue_init(1, Ring(), 1 << 30)
    assert e.value.errno == errno.EINVAL


def test_bad_setup_flags_stay_OSError():
    # `IORING_SETUP_SQ_AFF` is supported, it just needs `IORING_SETUP_SQPOLL`.
    with pytest.raises(OSError) as e:
        io_uring_queue_init(1, Ring(), IORING_SETUP_SQ_AFF)
    assert type(e.value) is not UnsupportedError


def test_kernel_without_query():
    r = run_without_query("""
        from liburing import *
        try:
            io_uring_register_query(Query())
        except UnsupportedError as e:
            print("query:", e.errno, e.strerror)
        ring = Ring()
        io_uring_queue_init(1, ring)
        try:  # opcode 36 came after `QUERY`, so a kernel without it has no 36 either
            io_uring_register(ring.ring_fd, 36, 0, None)
        except UnsupportedError as e:
            print("36:", e.strerror)
        try:  # `EVENTFD` (5.2) is in the version table: a bad fd stays `OSError`
            io_uring_register_eventfd(ring, -1)
        except OSError as e:
            print("eventfd:", type(e).__name__, e.errno)
        io_uring_queue_exit(ring)
    """)
    assert r.returncode == 0, r.stderr
    assert r.stdout.splitlines() == [
        f"query: 22 {KERNEL} does not support `IORING_REGISTER_QUERY`",
        f"36: {KERNEL} does not support `register opcode 36`",
        "eventfd: OSError 9",
    ]


def test_pytest_skips_unsupported():
    # `conftest.py` turns `UnsupportedError` into a skip: `test_Query` needs no marker.
    r = run_without_query("""
        import sys, pytest
        test = "test/queue/register_structs_test.py::test_Query"
        sys.exit(pytest.main(["-q", "-rs", "-p", "no:cacheprovider", test]))
    """)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "1 skipped" in r.stdout
    assert f"{KERNEL} does not support `IORING_REGISTER_QUERY`" in r.stdout
