"""The `example/` files the README and the docs show: each one runs and does what its text says."""

import os
import pathlib
import runpy
import socket
import subprocess
import sys
import threading
import pytest

EXAMPLE = pathlib.Path(__file__).parents[1] / "example"


def test_open_write_read_close_example(capsys):
    runpy.run_path(str(EXAMPLE / "open_write_read_close.py"), run_name="__main__")
    lines = capsys.readouterr().out.splitlines()
    assert lines[0].startswith("fd: ")
    assert lines[1:] == ["wrote: 16", "read: 16 bytearray(b'Hello, io_uring!')", "closed."]


def test_readv_writev_example(capsys):
    runpy.run_path(str(EXAMPLE / "readv_writev.py"), run_name="__main__")
    assert capsys.readouterr().out.splitlines() == [
        "written: 18",
        "read: 18",
        "[bytearray(b'hello '), bytearray(b'vector '), bytearray(b'world')]",
        "b'vector '",
    ]


def test_sqe_styles_example(capsys):
    runpy.run_path(str(EXAMPLE / "sqe_styles.py"), run_name="__main__")
    assert capsys.readouterr().out.splitlines() == [
        "get_sqe(): [0, 1, 2]",
        "Sqe():     [7, 7, 7]",
        "Sqe(ring): [0, 1, 2]",
        "Sqe(123): 123 completions, first [0, 1, 2] last 122",
    ]


@pytest.mark.parametrize("size", [0, 1, 32 * 1024, 5 * 1024 * 1024 + 3])
def test_copy_file_example(tmp_dir, size):
    src, dst = tmp_dir / "src.bin", tmp_dir / "dst.bin"
    src.write_bytes(os.urandom(size))
    out = subprocess.run(
        [sys.executable, str(EXAMPLE / "copy_file.py"), str(src), str(dst)],
        env={**os.environ, "PYTHONPATH": os.pathsep.join(sys.path)},
        capture_output=True,
        text=True,
        check=True,
    )
    assert out.stdout == f"copied {size} bytes\n"
    assert dst.read_bytes() == src.read_bytes()


def test_copy_file_example_missing_source(tmp_dir):
    out = subprocess.run(
        [sys.executable, str(EXAMPLE / "copy_file.py"), str(tmp_dir / "missing"), str(tmp_dir / "dst")],
        env={**os.environ, "PYTHONPATH": os.pathsep.join(sys.path)},
        capture_output=True,
        text=True,
        check=False,
    )
    assert out.returncode == 1
    assert "FileNotFoundError" in out.stderr


@pytest.mark.requires_op("IORING_OP_RECV", "IORING_OP_ACCEPT")
@pytest.mark.parametrize("buffers", [256, 1])  # the full pool, and one buffer: every receive after the first starves
def test_echo_server_example(capsys, buffers):
    sys.path.insert(0, str(EXAMPLE))
    try:
        echo_server = runpy.run_path(str(EXAMPLE / "echo_server.py"))  # defines `main`, does not run it
    finally:
        sys.path.remove(str(EXAMPLE))
    echo_server["BUFFERS"] = buffers
    with socket.socket() as probe:  # a free port
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    server = threading.Thread(target=echo_server["main"], args=(port,), daemon=True)
    server.start()

    def connect():
        for _ in range(50):
            try:
                s = socket.create_connection(("127.0.0.1", port))
            except ConnectionRefusedError:
                threading.Event().wait(0.1)  # not listening yet
            else:
                s.settimeout(10)
                return s
        raise AssertionError("the server did not start")

    # several connections, interleaved
    socks = [connect() for _ in range(8)]
    for i, s in enumerate(socks):
        s.sendall(f"hello {i}".encode())
    for i, s in enumerate(socks):
        assert s.recv(100) == f"hello {i}".encode()
    for s in socks:
        s.close()

    # a message of many chunks, sent while it is read back
    s = connect()
    payload = os.urandom(300_000)
    threading.Thread(target=s.sendall, args=(payload,)).start()
    got = bytearray()
    while len(got) < len(payload):
        chunk = s.recv(65536)
        assert chunk
        got += chunk
    assert got == payload
    s.close()

    # a peer that closes without sending does not stop the server
    connect().close()
    s = connect()
    s.sendall(b"still here")
    assert s.recv(100) == b"still here"
    s.close()
    assert server.is_alive()
    assert capsys.readouterr().out == f"echo server on 127.0.0.1:{port}\n"
