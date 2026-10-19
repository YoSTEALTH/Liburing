'''Submit/complete micro benchmark: NOPs only, no sockets (Liburing's counterpart of Shakti's
`example/bench/loop_bench.py`). Uses only API both the Setu and the old PyOZ builds have, so they
can be compared on one machine.

    python3.15t example/bench/loop_bench.py
'''

import sys
from time import perf_counter
import liburing
from liburing import (
    Cqe,
    Ring,
    Sqe,
    io_uring_cq_advance,
    io_uring_cqe_seen,
    io_uring_get_sqe,
    io_uring_prep_nop,
    io_uring_queue_exit,
    io_uring_queue_init,
    io_uring_submit,
    io_uring_submit_and_wait,
    io_uring_wait_cqe,
    io_uring_wait_cqe_nr,
    put_sqe,
)

ROUNDS = 5
BATCH = 1024


def nop_serial(ring, cqe, n):
    '''one NOP, submitted and reaped `n` times back to back (per-round-trip overhead)'''
    for i in range(n):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = i
        io_uring_submit_and_wait(ring, 1)
        io_uring_wait_cqe(ring, cqe)
        io_uring_cqe_seen(ring, cqe[0])


def nop_batch(ring, cqe, n):
    '''`BATCH` NOPs from `io_uring_get_sqe` per submit, `n` in total (per-op overhead)'''
    for _ in range(n // BATCH):
        for i in range(BATCH):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_nop(sqe)
            sqe.user_data = i
        io_uring_submit(ring)
        io_uring_wait_cqe_nr(ring, cqe, BATCH)
        io_uring_cq_advance(ring, BATCH)


def nop_batch_read(ring, cqe, n):
    '''`nop_batch`, plus reading every completion's `user_data` and `res` (what a server does)'''
    for _ in range(n // BATCH):
        for i in range(BATCH):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_nop(sqe)
            sqe.user_data = i
        io_uring_submit(ring)
        io_uring_wait_cqe_nr(ring, cqe, BATCH)
        for i in range(BATCH):
            entry = cqe[i]
            entry.user_data
            entry.res
        io_uring_cq_advance(ring, BATCH)


def nop_batch_read_at(ring, cqe, n):
    '''`nop_batch_read` with `cqe.user_data_at(i)` / `cqe.res_at(i)` (no entry object; not in the PyOZ build)'''
    for _ in range(n // BATCH):
        for i in range(BATCH):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_nop(sqe)
            sqe.user_data = i
        io_uring_submit(ring)
        io_uring_wait_cqe_nr(ring, cqe, BATCH)
        for i in range(BATCH):
            cqe.user_data_at(i)
            cqe.res_at(i)
        io_uring_cq_advance(ring, BATCH)


def put_batch(ring, cqe, n):
    '''`BATCH` NOPs prepared once in an `Sqe(BATCH)` and copied in with `put_sqe` per submit'''
    sqes = Sqe(BATCH)
    for i in range(BATCH):
        io_uring_prep_nop(sqes[i])
    for _ in range(n // BATCH):
        put_sqe(ring, sqes)
        io_uring_submit(ring)
        io_uring_wait_cqe_nr(ring, cqe, BATCH)
        io_uring_cq_advance(ring, BATCH)


CASES = [
    ('nop serial', 100_000, nop_serial),
    (f'nop batch x{BATCH}', 1_024_000, nop_batch),
    (f'nop batch x{BATCH} + read', 1_024_000, nop_batch_read),
    *([(f'nop batch x{BATCH} + read_at', 1_024_000, nop_batch_read_at)] if hasattr(Cqe, 'user_data_at') else []),
    (f'put_sqe batch x{BATCH}', 1_024_000, put_batch),
]


def main():
    gil = getattr(sys, '_is_gil_enabled', lambda: True)()
    print(f'liburing {getattr(liburing, "__version__", "?")} from {liburing.__file__}')
    print(f'Python {sys.version.split()[0]} GIL={"on" if gil else "off"}, best of {ROUNDS}\n')
    print(f'{"case":<26}{"ops":>10}{"total ms":>11}{"ns/op":>9}')
    for name, n, fn in CASES:
        best = min(_time(fn, n) for _ in range(ROUNDS))
        print(f'{name:<26}{n:>10}{best * 1e3:>11.1f}{best / n * 1e9:>9.0f}')


def _time(fn, n):
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(BATCH * 2, ring)
    try:
        start = perf_counter()
        fn(ring, cqe, n)
        return perf_counter() - start
    finally:
        io_uring_queue_exit(ring)


if __name__ == '__main__':
    main()
