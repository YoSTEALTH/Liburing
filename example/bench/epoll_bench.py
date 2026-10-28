'''HTTP keep-alive echo server on `select.epoll`: the same server, response and load as
`liburing_bench.py`, written the same way (one loop, no coroutines, a reused receive buffer per
connection), so the only difference is epoll + `recv` / `send` calls instead of io_uring.

    python3.15t example/bench/epoll_bench.py [port=12345]
    zig-out/bin/load 12345 64 5 100     # `zig build load`: port, connections, seconds, requests/connection

One thread, level-triggered epoll. `--threads=N`: N threads, each this server with its own epoll and listening
socket (`SO_REUSEPORT`), pinned to the process's CPUs in order, as `liburing_bench.py --threads=N`. Each connection: recv, send the response, recv again. Closes
the connection when recv or send returns 0 or an error. A partial send waits for `EPOLLOUT`.
'''

import os
import select
import socket
import sys
import threading

LISTEN = 1024
MAXEVENTS = 4096
BUFSIZE = 1024
RESPONSE = b'HTTP/1.1 200 OK\r\n'
RESPONSE += b'Content-Type: text/html\r\n'
RESPONSE += b'Content-Length: 131\r\n'
RESPONSE += b'Connection:close\r\n\r\n'
RESPONSE += b'<!DOCTYPE html><html><head><title>Hello</title></head>'
RESPONSE += b'<body style="background-color:#151515;color:#ccc;">'
RESPONSE += b'Hello world!</body></html>'


class Conn:
    '''One client: its socket, receive buffer and the unsent part of the response.'''

    __slots__ = ('buf', 'out', 'sock')

    def __init__(self, sock):
        self.sock = sock
        self.buf = bytearray(BUFSIZE)
        self.out = None  # the unsent part of `RESPONSE`, while waiting for `EPOLLOUT`


def main(port):
    ep = select.epoll()
    conns = {}  # fd -> Conn
    EPOLLIN, EPOLLOUT = select.EPOLLIN, select.EPOLLOUT

    def close_conn(fd):
        ep.unregister(fd)
        conns.pop(fd).sock.close()

    def send(fd, c, data):
        '''Send `data`; `True` if the connection is still open.'''
        try:
            sent = c.sock.send(data)
        except BlockingIOError:
            sent = 0
        except OSError:
            close_conn(fd)
            return False
        if sent < len(data):  # partial: wait for `EPOLLOUT`
            c.out = data[sent:]
            ep.modify(fd, EPOLLOUT)
        return True

    listen = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listen.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)  # `--threads`: one listening socket per thread
    listen.bind(('127.0.0.1', port))
    listen.listen(LISTEN)
    listen.setblocking(False)
    lfd = listen.fileno()
    ep.register(lfd, EPOLLIN)
    print(f'Starting epoll server on 127.0.0.1:{port}', flush=True)

    while True:
        for fd, events in ep.poll(-1, MAXEVENTS):
            if fd == lfd:
                while True:
                    try:
                        sock, _ = listen.accept()
                    except BlockingIOError:
                        break
                    sock.setblocking(False)
                    conns[sock.fileno()] = Conn(sock)
                    ep.register(sock.fileno(), EPOLLIN)
                continue
            c = conns[fd]
            if events & EPOLLOUT:
                data, c.out = c.out, None
                ep.modify(fd, EPOLLIN)
                send(fd, c, data)
                continue
            try:
                n = c.sock.recv_into(c.buf)
            except BlockingIOError:
                continue
            except OSError:
                n = 0
            if n == 0:
                close_conn(fd)
            else:
                send(fd, c, RESPONSE)


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
    threads = next((int(a[len('--threads=') :]) for a in sys.argv[1:] if a.startswith('--threads=')), 1)
    args = [a for a in sys.argv[1:] if not a.startswith('--threads=')]
    run(main, int(args[0]) if args else 12345, threads)
