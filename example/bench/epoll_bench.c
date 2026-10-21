// HTTP keep-alive echo server on epoll, the same server, response and load as `liburing_bench.c` and
// `epoll_bench.py` (a line by line translation of it).
//
//   zig cc -O2 -o zig-out/bin/epoll_bench_c example/bench/epoll_bench.c
//   zig-out/bin/epoll_bench_c 12345
//
// One thread, level-triggered epoll. Each connection: recv, send the response, recv again. Closes
// the connection when recv or send returns 0 or an error. A partial send waits for `EPOLLOUT`.

#define _GNU_SOURCE  // accept4
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <unistd.h>

#define LISTEN 1024
#define MAXEVENTS 4096
#define BUFSIZE 1024

static const char RESPONSE[] =
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: text/html\r\n"
    "Content-Length: 131\r\n"
    "Connection:close\r\n\r\n"
    "<!DOCTYPE html><html><head><title>Hello</title></head>"
    "<body style=\"background-color:#151515;color:#ccc;\">"
    "Hello world!</body></html>";
#define RESPONSE_LEN (sizeof RESPONSE - 1)

struct conn {
    int fd;
    size_t sent;  // of `RESPONSE`, while waiting for `EPOLLOUT`
    char buf[BUFSIZE];
};

static int ep;

static void close_conn(struct conn *c) {
    epoll_ctl(ep, EPOLL_CTL_DEL, c->fd, NULL);
    close(c->fd);
    free(c);
}

// Send the rest of `RESPONSE` from `c->sent`; a partial send waits for `EPOLLOUT`.
static void send_rest(struct conn *c) {
    ssize_t n = send(c->fd, RESPONSE + c->sent, RESPONSE_LEN - c->sent, MSG_NOSIGNAL);
    if (n < 0 && errno != EAGAIN) {
        close_conn(c);
        return;
    }
    c->sent += n > 0 ? (size_t)n : 0;
    if (c->sent < RESPONSE_LEN) {
        struct epoll_event ev = {.events = EPOLLOUT, .data.ptr = c};
        epoll_ctl(ep, EPOLL_CTL_MOD, c->fd, &ev);
    }
}

int main(int argc, char **argv) {
    int port = argc > 1 ? atoi(argv[1]) : 12345;

    signal(SIGPIPE, SIG_IGN);

    int listen_fd = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0);
    int one = 1;
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);

    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)port);
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);
    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof addr) < 0 || listen(listen_fd, LISTEN) < 0) {
        perror("bind/listen");
        return 1;
    }

    ep = epoll_create1(EPOLL_CLOEXEC);
    struct epoll_event ev = {.events = EPOLLIN, .data.ptr = NULL};  // NULL: the listening socket
    epoll_ctl(ep, EPOLL_CTL_ADD, listen_fd, &ev);

    printf("Starting epoll server on 127.0.0.1:%d\n", port);
    fflush(stdout);

    static struct epoll_event events[MAXEVENTS];
    for (;;) {
        int n = epoll_wait(ep, events, MAXEVENTS, -1);
        for (int i = 0; i < n; i++) {
            struct conn *c = events[i].data.ptr;
            if (!c) {
                int fd;
                while ((fd = accept4(listen_fd, NULL, NULL, SOCK_CLOEXEC | SOCK_NONBLOCK)) >= 0) {
                    c = calloc(1, sizeof *c);
                    c->fd = fd;
                    struct epoll_event cev = {.events = EPOLLIN, .data.ptr = c};
                    epoll_ctl(ep, EPOLL_CTL_ADD, fd, &cev);
                }
                continue;
            }
            if (events[i].events & EPOLLOUT) {
                struct epoll_event cev = {.events = EPOLLIN, .data.ptr = c};
                epoll_ctl(ep, EPOLL_CTL_MOD, c->fd, &cev);
                send_rest(c);
                continue;
            }
            ssize_t r = recv(c->fd, c->buf, BUFSIZE, 0);
            if (r < 0 && errno == EAGAIN)
                continue;
            if (r <= 0) {
                close_conn(c);
            } else {
                c->sent = 0;
                send_rest(c);
            }
        }
    }
}
