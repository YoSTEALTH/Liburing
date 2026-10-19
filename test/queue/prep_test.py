"""`io_uring_prep_*`: each one fills the `Sqe` with its opcode, fd and (where it has one) other fields.

These only prepare an entry (nothing is submitted); the ones with a visible effect on disk or sockets are run
in the tests next to them (`test/file`, `test/os`, `test/socket`).
"""

import mmap
import os
import pytest
import select
import liburing as L

OP = L.io_uring_op


def ts():
    return L.timespec(1)


def buf():
    return bytearray(8)


def iov():
    return L.Iovec([bytearray(8)])


# (function call, expected opcode, expected `sqe.fd` or None to skip the check)
CASES = {
    "nop": (lambda s: L.io_uring_prep_nop(s), OP.IORING_OP_NOP, None),
    "nop128": (lambda s: L.io_uring_prep_nop128(s), OP.IORING_OP_NOP128, None),
    "readv": (lambda s: L.io_uring_prep_readv(s, 7, iov()), OP.IORING_OP_READV, 7),
    "writev": (lambda s: L.io_uring_prep_writev(s, 7, iov()), OP.IORING_OP_WRITEV, 7),
    "readv_fixed": (lambda s: L.io_uring_prep_readv_fixed(s, 7, iov(), 0), OP.IORING_OP_READV_FIXED, 7),
    "writev_fixed": (lambda s: L.io_uring_prep_writev_fixed(s, 7, iov(), 0), OP.IORING_OP_WRITEV_FIXED, 7),
    "read_fixed": (lambda s: L.io_uring_prep_read_fixed(s, 7, buf(), 0), OP.IORING_OP_READ_FIXED, 7),
    "write_fixed": (lambda s: L.io_uring_prep_write_fixed(s, 7, buf(), 0), OP.IORING_OP_WRITE_FIXED, 7),
    "read": (lambda s: L.io_uring_prep_read(s, 7, buf()), OP.IORING_OP_READ, 7),
    "write": (lambda s: L.io_uring_prep_write(s, 7, buf()), OP.IORING_OP_WRITE, 7),
    "read_multishot": (lambda s: L.io_uring_prep_read_multishot(s, 7, 1), OP.IORING_OP_READ_MULTISHOT, 7),
    "fsync": (lambda s: L.io_uring_prep_fsync(s, 7), OP.IORING_OP_FSYNC, 7),
    "poll_add": (lambda s: L.io_uring_prep_poll_add(s, 7, select.POLLIN), OP.IORING_OP_POLL_ADD, 7),
    "poll_multishot": (lambda s: L.io_uring_prep_poll_multishot(s, 7, select.POLLIN), OP.IORING_OP_POLL_ADD, 7),
    "poll_remove": (lambda s: L.io_uring_prep_poll_remove(s, 5), OP.IORING_OP_POLL_REMOVE, None),
    "poll_update": (lambda s: L.io_uring_prep_poll_update(s, 5, 6, select.POLLIN), OP.IORING_OP_POLL_REMOVE, None),
    "timeout": (lambda s: L.io_uring_prep_timeout(s, ts(), 0), OP.IORING_OP_TIMEOUT, None),
    "timeout_remove": (lambda s: L.io_uring_prep_timeout_remove(s, 5), OP.IORING_OP_TIMEOUT_REMOVE, None),
    "timeout_update": (lambda s: L.io_uring_prep_timeout_update(s, ts(), 5), OP.IORING_OP_TIMEOUT_REMOVE, None),
    "link_timeout": (lambda s: L.io_uring_prep_link_timeout(s, ts(), 0), OP.IORING_OP_LINK_TIMEOUT, None),
    "accept": (lambda s: L.io_uring_prep_accept(s, 7), OP.IORING_OP_ACCEPT, 7),
    "accept_direct": (lambda s: L.io_uring_prep_accept_direct(s, 7), OP.IORING_OP_ACCEPT, 7),
    "multishot_accept": (lambda s: L.io_uring_prep_multishot_accept(s, 7), OP.IORING_OP_ACCEPT, 7),
    "multishot_accept_direct": (lambda s: L.io_uring_prep_multishot_accept_direct(s, 7), OP.IORING_OP_ACCEPT, 7),
    "cancel": (lambda s: L.io_uring_prep_cancel(s, 5), OP.IORING_OP_ASYNC_CANCEL, None),
    "cancel64": (lambda s: L.io_uring_prep_cancel64(s, 5), OP.IORING_OP_ASYNC_CANCEL, None),
    "cancel_fd": (lambda s: L.io_uring_prep_cancel_fd(s, 7), OP.IORING_OP_ASYNC_CANCEL, 7),
    "listen": (lambda s: L.io_uring_prep_listen(s, 7, 4), OP.IORING_OP_LISTEN, 7),
    "fallocate": (lambda s: L.io_uring_prep_fallocate(s, 7, 0, 0, 10), OP.IORING_OP_FALLOCATE, 7),
    "close": (lambda s: L.io_uring_prep_close(s, 7), OP.IORING_OP_CLOSE, 7),
    "close_direct": (lambda s: L.io_uring_prep_close_direct(s, 3), OP.IORING_OP_CLOSE, 0),
    "fadvise": (lambda s: L.io_uring_prep_fadvise(s, 7, 10, os.POSIX_FADV_NORMAL), OP.IORING_OP_FADVISE, 7),
    "fadvise64": (lambda s: L.io_uring_prep_fadvise64(s, 7, 10, os.POSIX_FADV_NORMAL), OP.IORING_OP_FADVISE, 7),
    "madvise": (lambda s: L.io_uring_prep_madvise(s, 4096, 10, mmap.MADV_NORMAL), OP.IORING_OP_MADVISE, None),
    "madvise64": (lambda s: L.io_uring_prep_madvise64(s, 4096, 10, mmap.MADV_NORMAL), OP.IORING_OP_MADVISE, None),
    "send": (lambda s: L.io_uring_prep_send(s, 7, b"hi"), OP.IORING_OP_SEND, 7),
    "send_zc": (lambda s: L.io_uring_prep_send_zc(s, 7, b"hi"), OP.IORING_OP_SEND_ZC, 7),
    "send_zc_fixed": (lambda s: L.io_uring_prep_send_zc_fixed(s, 7, b"hi", 0), OP.IORING_OP_SEND_ZC, 7),
    "recv": (lambda s: L.io_uring_prep_recv(s, 7, buf()), OP.IORING_OP_RECV, 7),
    "recv_multishot": (lambda s: L.io_uring_prep_recv_multishot(s, 7, buf()), OP.IORING_OP_RECV, 7),
    "provide_buffers": (lambda s: L.io_uring_prep_provide_buffers(s, bytearray(16), 2, 1, 0), OP.IORING_OP_PROVIDE_BUFFERS, None),
    "remove_buffers": (lambda s: L.io_uring_prep_remove_buffers(s, 2, 1), OP.IORING_OP_REMOVE_BUFFERS, None),
    "shutdown": (lambda s: L.io_uring_prep_shutdown(s, 7, L.SHUT_RD), OP.IORING_OP_SHUTDOWN, 7),
    "sync_file_range": (lambda s: L.io_uring_prep_sync_file_range(s, 7, 10), OP.IORING_OP_SYNC_FILE_RANGE, 7),
    "msg_ring": (lambda s: L.io_uring_prep_msg_ring(s, 7, 1, 2), OP.IORING_OP_MSG_RING, 7),
    "msg_ring_cqe_flags": (lambda s: L.io_uring_prep_msg_ring_cqe_flags(s, 7, 1, 2, 0, 0), OP.IORING_OP_MSG_RING, 7),
    "msg_ring_fd": (lambda s: L.io_uring_prep_msg_ring_fd(s, 7, 8, 9, 1), OP.IORING_OP_MSG_RING, 7),
    "msg_ring_fd_alloc": (lambda s: L.io_uring_prep_msg_ring_fd_alloc(s, 7, 8, 1), OP.IORING_OP_MSG_RING, 7),
    "socket": (lambda s: L.io_uring_prep_socket(s, L.AF_INET, L.SOCK_STREAM, 0), OP.IORING_OP_SOCKET, None),
    "socket_direct": (lambda s: L.io_uring_prep_socket_direct(s, L.AF_INET, L.SOCK_STREAM, 0), OP.IORING_OP_SOCKET, None),
    "uring_cmd": (lambda s: L.io_uring_prep_uring_cmd(s, 1, 7), OP.IORING_OP_URING_CMD, 7),
    "uring_cmd128": (lambda s: L.io_uring_prep_uring_cmd128(s, 1, 7), OP.IORING_OP_URING_CMD128, 7),
    "fixed_fd_install": (lambda s: L.io_uring_prep_fixed_fd_install(s, 3), OP.IORING_OP_FIXED_FD_INSTALL, 3),
    "ftruncate": (lambda s: L.io_uring_prep_ftruncate(s, 7, 10), OP.IORING_OP_FTRUNCATE, 7),
    "cmd_discard": (lambda s: L.io_uring_prep_cmd_discard(s, 7, 0, 4096), OP.IORING_OP_URING_CMD, 7),
    "pipe": (lambda s: L.io_uring_prep_pipe(s, 0, 0), OP.IORING_OP_PIPE, None),
    "pipe_direct": (lambda s: L.io_uring_prep_pipe_direct(s, 0, 0, 0), OP.IORING_OP_PIPE, None),
    "unlink": (lambda s: L.io_uring_prep_unlink(s, "/nope"), OP.IORING_OP_UNLINKAT, None),
    "rename": (lambda s: L.io_uring_prep_rename(s, "/a", "/b"), OP.IORING_OP_RENAMEAT, None),
    "mkdir": (lambda s: L.io_uring_prep_mkdir(s, "/a", 0o755), OP.IORING_OP_MKDIRAT, None),
    "symlink": (lambda s: L.io_uring_prep_symlink(s, "/a", "/b"), OP.IORING_OP_SYMLINKAT, None),
    "link": (lambda s: L.io_uring_prep_link(s, "/a", "/b"), OP.IORING_OP_LINKAT, None),
    "getxattr": (lambda s: L.io_uring_prep_getxattr(s, "user.x", buf(), "/a", 8), OP.IORING_OP_GETXATTR, None),
    "setxattr": (lambda s: L.io_uring_prep_setxattr(s, "user.x", b"v", "/a", 0, 1), OP.IORING_OP_SETXATTR, None),
    "fgetxattr": (lambda s: L.io_uring_prep_fgetxattr(s, 7, "user.x", buf(), 8), OP.IORING_OP_FGETXATTR, 7),
    "fsetxattr": (lambda s: L.io_uring_prep_fsetxattr(s, 7, "user.x", b"v", 0, 1), OP.IORING_OP_FSETXATTR, 7),
    "tee": (lambda s: L.io_uring_prep_tee(s, 7, 8, 10, 0), OP.IORING_OP_TEE, 8),
    "splice": (lambda s: L.io_uring_prep_splice(s, 7, 0, 8, 0, 10, 0), OP.IORING_OP_SPLICE, 8),
}


@pytest.mark.parametrize("name", CASES)
def test_prep(name):
    call, opcode, fd = CASES[name]
    sqe = L.Sqe()
    call(sqe)
    assert sqe.opcode == opcode
    if fd is not None:
        assert sqe.fd == fd
