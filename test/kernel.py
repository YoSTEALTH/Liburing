"""A failed operation the running kernel lacks raises `UnsupportedError`: `conftest.py` skips its test.

The kernel fails an `IORING_OP_*` it doesn't know in its CQE, with `EINVAL`, as it does a bad argument;
`probe()` tells the two apart.
"""

import errno
import functools

import liburing as u


@functools.cache
def _ops() -> tuple[tuple[str, bool], ...]:
    return tuple(u.probe().items())  # in opcode order


def supported(op: int | str) -> tuple[str, bool]:
    """`(name, supported)` of `op`: an opcode (`sqe.opcode`) or an `IORING_OP_*` name."""
    ops = _ops()
    if isinstance(op, str):
        return op, dict(ops).get(op, False)
    return ops[op] if op < len(ops) else (f"opcode {op}", False)


def res(entry: u.CQE, *ops: int | str, name: str | None = None) -> int:
    """`entry.res`, `UnsupportedError` (not `OSError`) when it failed and the kernel has no one of `ops`.

    Example
        >>> op = sqe.opcode  # before `io_uring_submit`
        >>> kernel.res(cqe[0], op)
        >>> # a flag the probe can't tell: the opcode that came with it (as liburing's own tests do)
        >>> kernel.res(cqe[0], "IORING_OP_READV_FIXED", name="`IORING_OP_SENDMSG_ZC` + `IORING_RECVSEND_FIXED_BUF`")
    """
    try:
        return entry.res
    except OSError as e:
        if e.errno == errno.EINVAL:
            for op in ops:
                op_name, ok = supported(op)
                if not ok:
                    msg = f"Kernel `{u.LINUX_VERSION_MAJOR}.{u.LINUX_VERSION_MINOR}` does not support "
                    raise u.UnsupportedError(e.errno, msg + (name or f"`{op_name}`")) from None
        raise
