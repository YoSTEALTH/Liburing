// HTTP keep-alive echo server on io_uring (C liburing), the same server, response and load as
// `liburing_bench.py`.
//
//   zig cc -O2 -D_GNU_SOURCE -Ilib/liburing/src/include -o zig-out/bin/liburing_bench_c example/bench/liburing_bench.c lib/liburing/src/{setup,queue,register,syscall,version}.c
//   zig-out/bin/liburing_bench_c 12345 [--defer] [--tmpl]
//
// One thread, one ring, default flags. Each connection: recv, send the response, recv again.
// Closes the connection when recv or send returns 0 or an error. `--defer` sets the ring up with
// `IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN` (default: no flags). `--tmpl` prepares each
// connection's recv and send once and copies them into the ring per request (`liburing_bench.py --tmpl`).

#include <arpa/inet.h>
#include <liburing.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define LISTEN 1024
#define ENTRIES 4096
#define BUFSIZE 1024

// user_data tags, in the low 3 bits (connections are 8-byte aligned)
enum { OP_ACCEPT = 0, OP_RECV = 1, OP_SEND = 2, OP_MASK = 7 };

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
    size_t sent;
    char buf[BUFSIZE];
    struct io_uring_sqe recv_tmpl, send_tmpl;  // `--tmpl`: prepared once
};

static struct io_uring ring;
static int listen_fd;
static int use_tmpl;

static struct io_uring_sqe *get_sqe(void) {
    struct io_uring_sqe *sqe = io_uring_get_sqe(&ring);
    if (!sqe) {  // SQ full: flush and retry
        io_uring_submit(&ring);
        sqe = io_uring_get_sqe(&ring);
    }
    return sqe;
}

static void arm_accept(void) {
    struct io_uring_sqe *sqe = get_sqe();
    io_uring_prep_accept(sqe, listen_fd, NULL, NULL, SOCK_CLOEXEC);
    io_uring_sqe_set_data64(sqe, OP_ACCEPT);
}

static void arm_recv(struct conn *c) {
    if (use_tmpl) {
        *get_sqe() = c->recv_tmpl;
        return;
    }
    struct io_uring_sqe *sqe = get_sqe();
    io_uring_prep_recv(sqe, c->fd, c->buf, BUFSIZE, 0);
    io_uring_sqe_set_data64(sqe, (uint64_t)(uintptr_t)c | OP_RECV);
}

static void arm_send(struct conn *c) {
    if (use_tmpl && !c->sent) {
        *get_sqe() = c->send_tmpl;
        return;
    }
    struct io_uring_sqe *sqe = get_sqe();
    io_uring_prep_send(sqe, c->fd, RESPONSE + c->sent, RESPONSE_LEN - c->sent, 0);
    io_uring_sqe_set_data64(sqe, (uint64_t)(uintptr_t)c | OP_SEND);
}

static void close_conn(struct conn *c) {
    close(c->fd);
    free(c);
}

static void handle(struct io_uring_cqe *cqe) {
    int op = (int)(cqe->user_data & OP_MASK);
    struct conn *c = (struct conn *)(uintptr_t)(cqe->user_data & ~(uint64_t)OP_MASK);

    switch (op) {
    case OP_ACCEPT:
        if (cqe->res >= 0) {
            c = calloc(1, sizeof *c);
            c->fd = cqe->res;
            if (use_tmpl) {
                io_uring_prep_recv(&c->recv_tmpl, c->fd, c->buf, BUFSIZE, 0);
                io_uring_sqe_set_data64(&c->recv_tmpl, (uint64_t)(uintptr_t)c | OP_RECV);
                io_uring_prep_send(&c->send_tmpl, c->fd, RESPONSE, RESPONSE_LEN, 0);
                io_uring_sqe_set_data64(&c->send_tmpl, (uint64_t)(uintptr_t)c | OP_SEND);
            }
            arm_recv(c);
        }
        arm_accept();
        break;
    case OP_RECV:
        if (cqe->res <= 0) {
            close_conn(c);
        } else {
            c->sent = 0;
            arm_send(c);
        }
        break;
    case OP_SEND:
        if (cqe->res <= 0) {
            close_conn(c);
        } else {
            c->sent += (size_t)cqe->res;
            if (c->sent < RESPONSE_LEN) {
                arm_send(c);
            } else {
                arm_recv(c);
            }
        }
        break;
    }
}

int main(int argc, char **argv) {
    int port = 12345;
    unsigned flags = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--defer") == 0)
            flags = IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN;
        else if (strcmp(argv[i], "--tmpl") == 0)
            use_tmpl = 1;
        else
            port = atoi(argv[i]);
    }

    signal(SIGPIPE, SIG_IGN);

    listen_fd = socket(AF_INET, SOCK_STREAM | SOCK_CLOEXEC, 0);
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

    if (io_uring_queue_init(ENTRIES, &ring, flags) < 0) {
        perror("io_uring_queue_init");
        return 1;
    }

    printf("Starting liburing server on 127.0.0.1:%d\n", port);
    fflush(stdout);
    arm_accept();

    for (;;) {
        io_uring_submit_and_wait(&ring, 1);

        struct io_uring_cqe *cqe;
        unsigned head, n = 0;
        io_uring_for_each_cqe(&ring, head, cqe) {
            handle(cqe);
            n++;
        }
        io_uring_cq_advance(&ring, n);
    }
}
