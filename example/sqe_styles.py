"""Four ways to fill the submission queue: `io_uring_get_sqe(ring)`, `Sqe()`, `Sqe(ring)` and `Sqe(123)`."""

from liburing import *


def run(ring, cqe, count):
    """Submit, wait for `count` completions and return their `user_data`."""
    io_uring_submit_and_wait(ring, count)
    io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest completion
    ready = io_uring_cq_ready(ring)
    data = [cqe.user_data_at(i) for i in range(ready)]
    io_uring_cq_advance(ring, ready)  # done with all of them
    return data


def main():
    ring = Ring()
    cqe = Cqe()
    try:
        io_uring_queue_init(128, ring)

        # `io_uring_get_sqe(ring)`: the C way, a new `SQE` for every request; `None` when the queue is full.
        for i in range(3):
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_nop(sqe)
            sqe.user_data = i
        print("get_sqe():", run(ring, cqe, 3))

        # `Sqe()`: one entry you prepare once, then `put_sqe` copies it into the ring as often as you like.
        sqe = Sqe()
        io_uring_prep_nop(sqe)
        sqe.user_data = 7
        for _ in range(3):
            put_sqe(ring, sqe)  # `True`; `False` when the queue is full: submit, then put again
        print("Sqe():    ", run(ring, cqe, 3))

        # `Sqe(ring)`: one object for the ring's lifetime, each prep writes straight into the ring's next free entry:
        # no `put_sqe`, no `io_uring_get_sqe`, no object per request.
        sqe = Sqe(ring)
        for i in range(3):
            io_uring_prep_nop(sqe)
            sqe.user_data = i  # acts on the entry of the last prep
        print("Sqe(ring):", run(ring, cqe, 3))

        # `Sqe(123)`: 123 entries prepared as a block (`sqe[i]`), then one `put_sqe` puts all of them in the ring.
        sqe = Sqe(123)
        for i in range(len(sqe)):
            io_uring_prep_nop(sqe[i])
            sqe[i].user_data = i
        put_sqe(ring, sqe)
        done = run(ring, cqe, 123)
        print("Sqe(123):", len(done), "completions, first", done[:3], "last", done[-1])
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    main()
