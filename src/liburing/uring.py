'''
Liburing

Python layer on top of PYoZ built functions
'''

from .liburing import _io_uring_queue_init_mem

def io_uring_queue_init_mem(entries, ring, param, buf):
    """Setup `Ring` using caller supplied memory. Returns bytes used from `buf`.

    Example
        >>> import mmap
        >>> ring = Ring()
        >>> param = Param()
        >>> buf = mmap.mmap(-1, 1024**2 * 2)  # page-aligned & zeroed
        >>> io_uring_queue_init_mem(8, ring, param, buf)

    Note
        - `buf` must be page-size aligned and zeroed; `mmap.mmap(-1, size)` satisfies both.
        A `bytearray` does not (kernel rejects it with `EINVAL`).
        - Hold a reference to `buf` until `io_uring_queue_exit`, else the memory gets
        freed while the ring still uses it.
    """
    return _io_uring_queue_init_mem(entries, ring, param, memoryview(buf))

__all__ = [
    "io_uring_queue_init_mem"
]