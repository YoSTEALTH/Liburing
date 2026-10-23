from liburing import Ring, Cqe, Sqe, io_uring_prep_nop, io_uring_submit_and_wait, io_uring_peek_cqe, \
                     io_uring_cq_ready, io_uring_cq_advance, io_uring_queue_init, io_uring_queue_exit


def main():
    ring = Ring()
    cqe = Cqe()
    try:
        io_uring_queue_init(8, ring)
        sqe = Sqe(ring)  # one object for the ring's lifetime: each prep takes the next free entry
        for i in range(3):
            io_uring_prep_nop(sqe)  # `True`; `False` when the queue is full: submit, then prep again
            sqe.user_data = i  # acts on the entry of the last prep
        io_uring_submit_and_wait(ring, 3)
        io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest completion
        ready = io_uring_cq_ready(ring)
        print("user_data:", [cqe.user_data_at(i) for i in range(ready)])
        io_uring_cq_advance(ring, ready)  # done with all of them
    finally:
        io_uring_queue_exit(ring)


if __name__ == "__main__":
    main()
