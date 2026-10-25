"""TCP echo server: C liburing's `examples/echo-server.c`, the modern io_uring networking pattern.

- Multishot accept: armed once, one completion per new connection.
- Multishot receive: armed once per connection, one completion per chunk of data.
- A provided buffer ring: the kernel picks a buffer from a shared pool for each receive, so no buffer is
  allocated or held per connection; the buffer goes back into the pool when its send has completed.

One thread, one ring, no object per request: `Sqe(ring)` preps straight into the next free entry, and
`Ring(auto_submit=True)` submits by itself when the queue is full. Linux 6.0+.

    python3 example/echo_server.py [port=8000]
    nc localhost 8000
"""

import errno
import os
import socket
import sys
from liburing import *

QD = 64  # submission queue entries
BUF_SIZE = 4096  # bytes per provided buffer
BUFFERS = 256  # buffers in the pool (a power of 2)
BGID = 0  # the pool's buffer group id

# `user_data`: bits 63-56 the event, 31-16 the buffer id (a send: which buffer to recycle), 15-0 the fd
ACCEPT, RECV, SEND = 1, 2, 3


def encode(event, fd, bid=0):
    return event << 56 | bid << 16 | fd


def main(port):
    ring = Ring(auto_submit=True)  # a full submission queue submits itself
    cqe = Cqe()
    listener = socket.socket()
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", port))
    listener.listen(QD)
    listen_fd = listener.fileno()
    # `DEFER_TASKRUN`: completions are processed only when this thread waits for them (needs `SINGLE_ISSUER`).
    io_uring_queue_init(QD, ring, IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN)
    sqe = Sqe(ring)  # each prep takes the ring's next free entry

    # the buffer pool: `BUFFERS` buffers the kernel picks from when a receive needs one
    bufs = [bytearray(BUF_SIZE) for _ in range(BUFFERS)]
    mask = io_uring_buf_ring_mask(BUFFERS)
    br = io_uring_setup_buf_ring(ring, BUFFERS, BGID, 0)
    for bid, buf in enumerate(bufs):
        io_uring_buf_ring_add(br, buf, bid, mask, bid)
    io_uring_buf_ring_advance(br, BUFFERS)
    conns = set()  # open connections
    starved = set()  # connections whose receive stopped because the pool was empty (`ENOBUFS`)

    def add_accept():
        io_uring_prep_multishot_accept(sqe, listen_fd)
        sqe.user_data = encode(ACCEPT, listen_fd)

    def add_recv(fd):
        io_uring_prep_recv_multishot(sqe, fd)  # no buffer: the kernel picks one from group `BGID`
        sqe.flags = IOSQE_BUFFER_SELECT
        io_uring_sqe_set_buf_group(sqe, BGID)
        sqe.user_data = encode(RECV, fd)

    def add_send(fd, bid, length):
        io_uring_prep_send(sqe, fd, memoryview(bufs[bid])[:length])  # held until the completion
        sqe.user_data = encode(SEND, fd, bid)

    def recycle(bid):
        io_uring_buf_ring_add(br, bufs[bid], bid, mask, 0)
        io_uring_buf_ring_advance(br, 1)

    def close(fd):
        if fd in conns:  # once: a send may fail after its connection's receive closed it
            conns.discard(fd)
            starved.discard(fd)
            os.close(fd)

    print(f"echo server on 127.0.0.1:{port}", flush=True)
    add_accept()
    try:
        while True:
            io_uring_submit_and_wait(ring, 1)
            io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest completion
            ready = io_uring_cq_ready(ring)
            for i in range(ready):
                entry = cqe[i]
                flags, data = entry.flags, entry.user_data
                event, fd = data >> 56, data & 0xFFFF
                try:
                    res = entry.res  # raises the matching `OSError` for a failed request
                except OSError as e:
                    res = -e.errno
                more = flags & IORING_CQE_F_MORE  # the multishot request is still armed

                if event == ACCEPT:
                    if res >= 0:
                        conns.add(res)  # the new connection's fd
                        add_recv(res)
                    if not more:
                        add_accept()
                elif event == RECV:
                    if res > 0:
                        add_send(fd, flags >> IORING_CQE_BUFFER_SHIFT, res)  # echo from the buffer the kernel picked
                        if not more:
                            starved.add(fd)
                    elif res == -errno.ENOBUFS:
                        starved.add(fd)  # the pool is empty: arm again when a send gives a buffer back
                    else:
                        close(fd)  # `0`: the peer closed; else an error
                else:  # SEND
                    recycle(data >> 16 & 0xFFFF)  # back into the pool, sent or not
                    if res < 0:
                        close(fd)
                    while starved:  # a buffer is free again
                        add_recv(starved.pop())
            io_uring_cq_advance(ring, ready)  # done with all of them
    finally:
        io_uring_queue_exit(ring)  # frees the buffer ring too
        listener.close()


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 8000)
