'''HTTP keep-alive echo server on Liburing's Python API: the same server, response and load as
`liburing_bench.c` (translated line by line: `io_uring_sqe_set_data64` as in C, which also measures
1 ns under the `sqe.user_data` property).

    python3.15t example/bench/liburing_bench.py [port=12345] [--peek | --at | --data] [--defer] [--tmpl] [--ring]
        [--threads=N]
    zig-out/bin/load 12345 64 5 100     # `zig build load`: port, connections, seconds, requests/connection

One thread, one ring, default flags. `--threads=N`: N threads, each this server with its own ring and listening
socket (`SO_REUSEPORT`), pinned to the process's CPUs in order (`taskset -c 2-5 ... --threads=4`): with the GIL they
take turns, free-threaded they run at once. Each connection: recv, send the response, recv again. Closes
the connection when recv or send returns 0 or an error.

Completions are read in a batch, `cqe[i]` for every ready one, then `io_uring_cq_advance`. `--peek`
reads them one at a time instead (`io_uring_peek_cqe`, `cqe[0]`, `io_uring_cqe_seen`): the only way
that works on the old PyOZ build, whose `cqe[i]` reads past the end of the completion queue once it
wraps around. `--at` reads them with `cqe.user_data_res(i)`: one call, no entry objects. `--data` attaches the
connection itself to each request (`io_uring_sqe_set_data`, as C attaches a pointer) and reads `(conn, res)` with
`cqe.data_res(i)`: no `user_data` to encode and no lookup of the connection (not with `--tmpl`).
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
import threading
from liburing import *

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
ACCEPT = object()  # `--data`: the accept request's object


class Conn:
    '''One client: its fd, receive buffer and how much of the response has been sent.'''

    __slots__ = ('buf', 'cid', 'fd', 'op', 'out', 'recv', 'send', 'sent', 'ud_recv', 'ud_send')

    def __init__(self, fd, cid=0, tmpl=False):
        self.fd = fd
        self.cid = cid
        self.op = OP_RECV  # `--data`: the operation in flight (one per connection at a time)
        self.buf = bytearray(BUFSIZE)
        self.sent = 0
        self.out = None  # the unsent part of `RESPONSE`, alive until its send completes
        self.ud_recv = cid << 2 | OP_RECV  # this connection's `user_data` per operation, computed once
        self.ud_send = cid << 2 | OP_SEND
        self.recv = self.send = None
        if tmpl:  # `--tmpl`: this connection's recv and send, prepared once
            self.recv = Sqe()
            io_uring_prep_recv(self.recv, fd, self.buf)
            io_uring_sqe_set_data64(self.recv, self.ud_recv)
            self.send = Sqe()
            io_uring_prep_send(self.send, fd, RESPONSE)
            io_uring_sqe_set_data64(self.send, self.ud_send)


def main(port, peek=False, at=False, data=False, defer=False, tmpl=False, ring_sqe=False):
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
        if data:
            io_uring_sqe_set_data(s, ACCEPT)
        else:
            io_uring_sqe_set_data64(s, OP_ACCEPT)

    def arm_recv(c):
        if tmpl:
            return put(c.recv)
        s = sqe if ring_sqe else get_sqe()
        if io_uring_prep_recv(s, c.fd, c.buf) is False:  # `Sqe(ring)` SQ full: flush, retry
            io_uring_submit(ring)
            io_uring_prep_recv(s, c.fd, c.buf)
        if data:
            c.op = OP_RECV
            io_uring_sqe_set_data(s, c)
        else:
            io_uring_sqe_set_data64(s, c.ud_recv)

    def arm_send(c):
        if tmpl and not c.sent:
            return put(c.send)
        c.out = RESPONSE[c.sent :] if c.sent else RESPONSE  # `bytes` (the PyOZ build takes no `memoryview`)
        s = sqe if ring_sqe else get_sqe()
        if io_uring_prep_send(s, c.fd, c.out) is False:  # `Sqe(ring)` SQ full: flush, retry
            io_uring_submit(ring)
            io_uring_prep_send(s, c.fd, c.out)
        if data:
            c.op = OP_SEND
            io_uring_sqe_set_data(s, c)
        else:
            io_uring_sqe_set_data64(s, c.ud_send)

    def close_conn(cid):
        os.close(conns.pop(cid).fd)

    listen = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)  # `--threads`: one listening socket per thread
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
            if data:
                c, res = cqe.data_res(i)  # `res` as is: negative for a failed operation
                op, cid = (OP_ACCEPT, 0) if c is ACCEPT else (c.op, c.cid)
            elif at:
                ud, res = cqe.user_data_res(i)
            else:
                if peek:
                    if i:
                        io_uring_peek_cqe(ring, cqe)
                    entry = cqe[0]
                else:
                    entry = cqe[i]
                ud = entry.user_data
                try:
                    res = entry.res
                except OSError:  # a failed operation
                    res = -1
            if not data:
                op, cid = ud & OP_MASK, ud >> 2
            if op == OP_ACCEPT:
                if res >= 0:
                    cid, next_id = next_id, next_id + 1
                    conns[cid] = c = Conn(res, cid, tmpl)
                    arm_recv(c)
                arm_accept()
            elif op == OP_RECV:
                if res <= 0:
                    close_conn(cid)
                else:
                    if not data:
                        c = conns[cid]
                    c.sent = 0
                    arm_send(c)
            else:  # OP_SEND
                if not data:
                    c = conns[cid]
                if res <= 0:
                    close_conn(cid)
                else:
                    c.sent += res
                    if c.sent < len(RESPONSE):
                        arm_send(c)
                    else:
                        c.out = None
                        arm_recv(c)
            if peek:
                io_uring_cqe_seen(ring, entry)
        if not peek:
            io_uring_cq_advance(ring, ready)


def run(main, port, threads, *args):
    '''`main(port, *args)` on `threads` threads, each with its own listening socket on `port` (`SO_REUSEPORT`: the
    kernel spreads the connections) and pinned to one CPU of this process (`taskset -c ...`, in order); one thread:
    in this one, not pinned.'''
    if threads == 1:
        return main(port, *args)
    cpus = sorted(os.sched_getaffinity(0))

    def serve(i):
        os.sched_setaffinity(0, {cpus[i % len(cpus)]})  # `0`: the calling thread
        main(port, *args)

    pool = [threading.Thread(target=serve, args=(i,), daemon=True) for i in range(threads)]
    for t in pool:
        t.start()
    for t in pool:
        t.join()


if __name__ == '__main__':
    flags = ('--peek', '--at', '--data', '--defer', '--tmpl', '--ring')
    threads = next((int(a[len('--threads=') :]) for a in sys.argv[1:] if a.startswith('--threads=')), 1)
    args = [a for a in sys.argv[1:] if a not in flags and not a.startswith('--threads=')]
    run(main, int(args[0]) if args else 12345, threads, *(f in sys.argv for f in flags))
