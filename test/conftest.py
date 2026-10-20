import os
import os.path
import pytest
import pathlib
import getpass
import tempfile
import liburing
import mmap


@pytest.fixture
def tmp_dir():
    """Temporary directory to store test data.

    Example
        >>> test_my_function(tmp_dir)
        ...     # create directory
        ...     # ----------------
        ...     my_dir = tmp_dir / 'my_dir'
        ...     my_dir.mkdir()
        ...
        ...     # create file
        ...     # -----------
        ...     my_file = tmp_dir / 'my_file.ext'
        ...     my_file.write_text('Hello World!!!')

    Note
        - unlike pytest's `tmpdir`, `tmp_path`, ... `tmp_dir` generated
        files & directories are not deleted after 3 runs.
    """
    path = f"{tempfile.gettempdir()}/pytest-of-{getpass.getuser()}-holder"
    if not os.path.exists(path):
        os.mkdir(path)
    return pathlib.Path(tempfile.mkdtemp(dir=path))


# liburing start >>>
@pytest.fixture(params=['queue_init', 'queue_init_mem'])
def ring(request):
    '''
    =======================
    params:
        queue_init:
            Init queue using `io_uring_queue_init`
        queue_init_mem:
            Init queue using `io_uring_queue_init_mem`
    '''
    ring = liburing.Ring()
    try:
        if request.param == 'queue_init':
            liburing.io_uring_queue_init(1024, ring)
        else:
            buf = mmap.mmap(-1, 8 * 1024 * 1024)
            param = liburing.Param()
            liburing.io_uring_queue_init_mem(1024, ring, param, buf)
        yield ring
    finally:
        liburing.io_uring_queue_exit(ring)


@pytest.fixture
def cqe():
    return liburing.Cqe()


# liburing end <<<


# linux version start >>>
LINUX_VERSION = f"{liburing.LINUX_VERSION_MAJOR}.{liburing.LINUX_VERSION_MINOR}"


@pytest.fixture(autouse=True)
def skip_by_platform(request):
    """
    Example
        >>> @pytest.mark.skip_linux(6.7)
        >>> def test_function():
        ...
        test.py::test_function SKIPPED (Linux `6.7 < 6.8`)

        >>> @pytest.mark.skip_linux(6.7, 'custom message')
        >>> def test_function():
        ...
        test.py::test_function SKIPPED (custom message)

        >>> @pytest.mark.skip_linux('6.7', '')
        >>> def test_function():
        ...
        test.py::test_function SKIPPED
    """
    if r := request.node.get_closest_marker("skip_linux"):
        if liburing.linux_version_check(version := r.args[0]):
            msg = r.args[1] if len(r.args) > 1 else f"Kernel `{LINUX_VERSION} < {version}`"
            pytest.skip(msg)


@pytest.fixture(autouse=True)
def skip_by_opcode(request):
    """Skip when the running kernel does not support an io_uring opcode (asked from the kernel itself).

    Prefer this over `skip_linux` for `IORING_OP_*`: it is right on backported / patched kernels too.
    `skip_linux` stays for what the probe can't tell (register opcodes, flags, setup features).

    Example
        >>> @pytest.mark.requires_op("IORING_OP_FUTEX_WAIT", "IORING_OP_FUTEX_WAKE")
        >>> def test_function():
        ...
        test.py::test_function SKIPPED (kernel has no `IORING_OP_FUTEX_WAIT`)
    """
    if r := request.node.get_closest_marker("requires_op"):
        supported = liburing.probe()
        for op in r.args:
            if not supported.get(op, False):
                pytest.skip(f"Kernel `{LINUX_VERSION}` has no `{op}`")


@pytest.hookimpl(wrapper=True)
def pytest_runtest_call(item):
    """A test the kernel can't run skips (`UnsupportedError`) instead of failing: no `skip_linux` needed.

    Example
        test.py::test_Query SKIPPED (Kernel `6.12` does not support `IORING_REGISTER_QUERY`)
    """
    try:
        return (yield)
    except liburing.UnsupportedError as e:
        # `_use_item_location`: `-rs` names the test, as for a skip marker, not this hook.
        raise pytest.skip.Exception(e.strerror, _use_item_location=True) from None


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "skip_linux(version:str|float|int, message:str): skipping linux version not supported.",
    )
    config.addinivalue_line(
        "markers",
        "requires_op(*names:str): skip unless the kernel's probe lists every `IORING_OP_*` name.",
    )


# linux version end <<<
