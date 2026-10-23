'''HTTP keep-alive echo server on Liburing's Python API: the same server, response and load as
`liburing_bench.c` (translated line by line; both from Shakti's `example/bench`).

    python3.15t example/bench/liburing_bench.py [port=12345] [--peek | --at] [--defer] [--tmpl] [--ring]
    zig-out/bin/load 12345 64 5 100     # `zig build load`: port, connections, seconds, requests/connection

One thread, one ring, default flags. Each connection: recv, send the response, recv again. Closes
the connection when recv or send returns 0 or an error.

Completions are read in a batch, `cqe[i]` for every ready one, then `io_uring_cq_advance`. `--peek`
reads them one at a time instead (`io_uring_peek_cqe`, `cqe[0]`, `io_uring_cqe_seen`): the only way
that works on the old PyOZ build, whose `cqe[i]` reads past the end of the completion queue once it
wraps around. `--at` reads them with `cqe.user_data_at(i)` / `cqe.res_at(i)`: no entry objects.
`--defer` sets the ring up with `IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN` (default: no flags).
`--tmpl` prepares each connection's recv and send once, in a `Sqe()` template each, and arms them with
`put_sqe` (a copy into the ring: no `io_uring_get_sqe`, prep or `user_data` call per request); a partial send
still preps the rest. `liburing_bench.c --tmpl` does the same (`memcpy` of prepared SQEs).
Each request gets its entry from `io_uring_get_sqe`, then the prep, as the C server does. `--ring` preps into one
`Sqe(ring)` instead (each prep takes the ring's next free entry: no `io_uring_get_sqe` call and no object per
request).
'''

import os
import socket
import sys
from liburing import (
    IORING_SETUP_DEFER_TASKRUN,
    IORING_SETUP_SINGLE_ISSUER,
    SOCK_CLOEXEC,
    Cqe,
    Ring,
    Sqe,
    io_uring_cq_advance,
    io_uring_cq_ready,
    io_uring_cqe_seen,
    io_uring_get_sqe,
    io_uring_peek_cqe,
    io_uring_prep_accept,
    io_uring_prep_recv,
    io_uring_prep_send,
    io_uring_queue_init,
    io_uring_submit,
    io_uring_submit_and_wait,
    put_sqe,
)

LISTEN = 1024
ENTRIES = 4096
BUFSIZE = 1024
RESPONSE = b'HTTP/1.1 200 OK\r\n'
RESPONSE += b'Content-Type: text/html\r\n'
RESPONSE += b'Content-Length: 131\r\n'
RESPONSE += b'Connection:close\r\n\r\n'
RESPONSE += b'<!DOCTYPE html><html><head><title>Hello</title></head>'
RESPONSE += b'<body style="background-color:#151515;color:#ccc;">'
RESPONSE += b'Hello world!</body></html>'

# user_data: connection id << 2 | operation
OP_ACCEPT, OP_RECV, OP_SEND, OP_MASK = 0, 1, 2, 3


class Conn:
    '''One client: its fd, receive buffer and how much of the response has been sent.'''

    __slots__ = ('fd', 'buf', 'sent', 'out', 'recv', 'send')

    def __init__(self, fd, cid=0, tmpl=False):
        self.fd = fd
        self.buf = bytearray(BUFSIZE)
        self.sent = 0
        self.out = None  # the unsent part of `RESPONSE`, alive until its send completes
        self.recv = self.send = None
        if tmpl:  # `--tmpl`: this connection's recv and send, prepared once
            self.recv = Sqe()
            io_uring_prep_recv(self.recv, fd, self.buf)
            self.recv.user_data = cid << 2 | OP_RECV
            self.send = Sqe()
            io_uring_prep_send(self.send, fd, RESPONSE)
            self.send.user_data = cid << 2 | OP_SEND


def main(port, peek=False, at=False, defer=False, tmpl=False, ring_sqe=False):
    ring, cqe = Ring(), Cqe()
    sqe = None  # `--ring`: `Sqe(ring)`, after the init
    conns = {}  # id -> Conn
    next_id = 1

    def get_sqe():
        sqe = io_uring_get_sqe(ring)
        if sqe is None:  # SQ full (`Sqe(ring)`): flush and retry
            io_uring_submit(ring)
            sqe = io_uring_get_sqe(ring)
        return sqe

    def put(template):
        if not put_sqe(ring, template):  # SQ full (`Sqe(ring)`): flush and retry
            io_uring_submit(ring)
            put_sqe(ring, template)

    def arm_accept():
        s = sqe if ring_sqe else get_sqe()
        if io_uring_prep_accept(s, listen.fileno(), None, SOCK_CLOEXEC) is False:  # `Sqe(ring)` SQ full: flush, retry
            io_uring_submit(ring)
            io_uring_prep_accept(s, listen.fileno(), None, SOCK_CLOEXEC)
        s.user_data = OP_ACCEPT

    def arm_recv(cid, c):
        if tmpl:
            return put(c.recv)
        s = sqe if ring_sqe else get_sqe()
        if io_uring_prep_recv(s, c.fd, c.buf) is False:  # `Sqe(ring)` SQ full: flush, retry
            io_uring_submit(ring)
            io_uring_prep_recv(s, c.fd, c.buf)
        s.user_data = cid << 2 | OP_RECV

    def arm_send(cid, c):
        if tmpl and not c.sent:
            return put(c.send)
        c.out = RESPONSE[c.sent :] if c.sent else RESPONSE  # `bytes` (the PyOZ build takes no `memoryview`)
        s = sqe if ring_sqe else get_sqe()
        if io_uring_prep_send(s, c.fd, c.out) is False:  # `Sqe(ring)` SQ full: flush, retry
            io_uring_submit(ring)
            io_uring_prep_send(s, c.fd, c.out)
        s.user_data = cid << 2 | OP_SEND

    def close_conn(cid):
        os.close(conns.pop(cid).fd)

    listen = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listen.bind(('127.0.0.1', port))
    listen.listen(LISTEN)
    io_uring_queue_init(ENTRIES, ring, IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN if defer else 0)
    if ring_sqe:
        sqe = Sqe(ring)
    print(f'Starting Liburing server on 127.0.0.1:{port}', flush=True)
    arm_accept()

    while True:
        io_uring_submit_and_wait(ring, 1)
        io_uring_peek_cqe(ring, cqe)  # `cqe[0]` is the oldest completion
        ready = io_uring_cq_ready(ring)
        for i in range(ready):
            if at:
                data = cqe.user_data_at(i)
            else:
                if peek:
                    if i:
                        io_uring_peek_cqe(ring, cqe)
                    entry = cqe[0]
                else:
                    entry = cqe[i]
                data = entry.user_data
            op, cid = data & OP_MASK, data >> 2
            try:
                res = cqe.res_at(i) if at else entry.res
            except OSError:  # a failed operation
                res = -1
            if op == OP_ACCEPT:
                if res >= 0:
                    cid, next_id = next_id, next_id + 1
                    conns[cid] = c = Conn(res, cid, tmpl)
                    arm_recv(cid, c)
                arm_accept()
            elif op == OP_RECV:
                if res <= 0:
                    close_conn(cid)
                else:
                    c = conns[cid]
                    c.sent = 0
                    arm_send(cid, c)
            else:  # OP_SEND
                c = conns[cid]
                if res <= 0:
                    close_conn(cid)
                else:
                    c.sent += res
                    if c.sent < len(RESPONSE):
                        arm_send(cid, c)
                    else:
                        c.out = None
                        arm_recv(cid, c)
            if peek:
                io_uring_cqe_seen(ring, entry)
        if not peek:
            io_uring_cq_advance(ring, ready)


if __name__ == '__main__':
    flags = ('--peek', '--at', '--defer', '--tmpl', '--ring')
    args = [a for a in sys.argv[1:] if a not in flags]
    main(int(args[0]) if args else 12345, *(f in sys.argv for f in flags))
