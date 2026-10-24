'''Messages between threads, each with its own ring, through a futex (Linux 6.7+).

The receiver arms an `io_uring_prep_futex_wait` on its own ring: an ordinary request, with its own
`user_data`. A sender puts the message in a shared `deque` (any Python object, not only 64 bits), bumps the
futex and wakes it from its own ring. The receiver's wait completes, it takes every message queued (several
sends may give one wake-up) and arms the wait again.

`io_uring_prep_msg_ring` also posts on another ring, but carries only `data` (below 2**63) and `len`: use it
for a small value or to pass a registered file (`io_uring_prep_msg_ring_fd`).

    python3.15t example/futex_messages.py
'''

import collections
import threading
from liburing import *

FLAGS = FUTEX2_SIZE_U32 | FUTEX2_PRIVATE  # one process: a private futex is cheaper
WAIT = 1  # the receiver's `user_data` for its futex wait

futex = Futex(1, FLAGS)
messages = collections.deque()  # thread-safe appends / pops


def receiver(got):
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    try:
        while True:
            seen = futex.state  # waits only while the futex still holds this value
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_futex_wait(sqe, futex, seen, FUTEX_BITSET_MATCH_ANY, FLAGS)
            sqe.user_data = WAIT
            io_uring_submit(ring)
            io_uring_wait_cqe(ring, cqe)
            entry = cqe[0]
            assert entry.user_data == WAIT  # our own request: an entry of this ring's table
            try:
                _ = entry.res  # 0: woken
            except BlockingIOError:
                pass  # `EAGAIN`: a message came between reading `seen` and arming the wait
            io_uring_cqe_seen(ring, entry)
            while messages:  # one wake-up may stand for several messages
                message = messages.popleft()
                if message is None:
                    return
                got.append(message)
    finally:
        io_uring_queue_exit(ring)


def sender(items):
    ring, cqe = Ring(), Cqe()
    io_uring_queue_init(8, ring)
    try:
        for item in items:
            messages.append(item)
            futex.state = (futex.state + 1) & 0xFFFF_FFFF  # changed: a wait armed on the old value returns
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_futex_wake(sqe, futex, 1, FUTEX_BITSET_MATCH_ANY, FLAGS)
            io_uring_submit_and_wait(ring, 1)
            io_uring_wait_cqe(ring, cqe)
            io_uring_cqe_seen(ring, cqe[0])  # `res`: how many waiters it woke (0 if none was armed yet)
    finally:
        io_uring_queue_exit(ring)


def main():
    got = []
    r = threading.Thread(target=receiver, args=(got,))
    r.start()
    s = threading.Thread(target=sender, args=([{'id': i, 'text': f'message {i}'} for i in range(5)] + [None],))
    s.start()
    s.join()
    r.join()
    for message in got:
        print(message)


if __name__ == '__main__':
    main()
