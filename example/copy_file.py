"""Copy a file with linked requests: C liburing's `examples/link-cp.c`.

Every chunk is a pair of requests in the ring at once: a read into a buffer, and (`IOSQE_IO_LINK`) the write of
that buffer at the same offset, which the kernel starts only after the read is done. Up to `QD` pairs are in
flight, so one `io_uring_submit` hands the kernel many reads and writes; nothing is copied through Python.
The size comes from `io_uring_prep_statx`, the files from `io_uring_prep_open`: every step goes through the ring.

    python3 example/copy_file.py <source> <destination>
"""

import sys
from liburing import *

QD = 64  # pairs in flight at most
BS = 32 * 1024  # bytes per pair

READ, WRITE = 0, 1  # the low bit of `user_data`; the rest is the offset of the pair's chunk


def one(ring, cqe, prep, *args):
    """Submit one request on its own and give its result."""
    sqe = io_uring_get_sqe(ring)
    prep(sqe, *args)
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqe)
    result = cqe[0].res  # raises the matching `OSError` if it failed
    io_uring_cqe_seen(ring, cqe[0])
    return result


def queue_pair(ring, src, dst, offset, size):
    """A read linked to a write of the same buffer: the two requests of one chunk."""
    buffer = bytearray(size)  # both requests hold it until their completions
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, src, buffer, offset)
    sqe.flags = IOSQE_IO_LINK  # the next entry starts when this one has finished, and only if it succeeded
    sqe.user_data = offset << 1 | READ
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, dst, buffer, offset)
    sqe.user_data = offset << 1 | WRITE


def copy_file(ring, cqe, src, dst, size):
    offset = inflight = 0
    while offset < size or inflight:
        queued = inflight
        while offset < size and inflight < 2 * QD:  # fill the queue: as many pairs as fit
            chunk = min(BS, size - offset)
            queue_pair(ring, src, dst, offset, chunk)
            offset += chunk
            inflight += 2
        if inflight != queued:
            io_uring_submit(ring)  # one syscall for every pair queued above

        depth = 2 * QD if offset < size else 1  # collect until a pair fits again (at the end: everything)
        while inflight >= depth:
            io_uring_wait_cqe(ring, cqe)
            entry = cqe[0]
            try:
                _ = entry.res  # the read's bytes, or the write's; a failed read also cancels its write (`ECANCELED`)
            finally:
                io_uring_cqe_seen(ring, entry)
            inflight -= 1


def main(source, destination):
    ring = Ring()
    cqe = Cqe()
    stat = Statx()
    io_uring_queue_init(2 * QD, ring)  # a read and a write per pair
    try:
        one(ring, cqe, io_uring_prep_statx, stat, source)
        src = one(ring, cqe, io_uring_prep_open, source, O_RDONLY)
        dst = one(ring, cqe, io_uring_prep_open, destination, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        copy_file(ring, cqe, src, dst, stat.size)
        one(ring, cqe, io_uring_prep_close, src)
        one(ring, cqe, io_uring_prep_close, dst)
        print(f"copied {stat.size} bytes")
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <source> <destination>")
    main(*sys.argv[1:])
