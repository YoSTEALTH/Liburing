/* Submit/complete micro benchmark on C liburing (lib/liburing): the same cases, counts and output as
 * `loop_bench.py`, written with the same calls, for the C numbers under Liburing's.
 *
 *     zig build   # runs lib/liburing's ./configure (compat.h, io_uring_version.h)
 *     zig cc -O2 -D_GNU_SOURCE -Ilib/liburing/src/include -o zig-out/bin/loop_bench_c example/bench/loop_bench.c \
 *         lib/liburing/src/{setup,queue,register,syscall,version}.c
 *     zig-out/bin/loop_bench_c
 */
#include <liburing.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ROUNDS 5
#define BATCH 1024

static void check(int res, const char *what)
{
    if (res < 0) {
        fprintf(stderr, "%s: %s\n", what, strerror(-res));
        exit(1);
    }
}

/* Keeps the compiler from dropping a value it can see is unused. */
static void keep(uint64_t v)
{
    __asm__ volatile("" : : "r"(v) : "memory");
}

/* one NOP, submitted and reaped `n` times back to back (per-round-trip overhead) */
static void nop_serial(struct io_uring *ring, uint64_t n)
{
    struct io_uring_cqe *cqe;
    for (uint64_t i = 0; i < n; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
        io_uring_prep_nop(sqe);
        io_uring_sqe_set_data64(sqe, i);
        check(io_uring_submit_and_wait(ring, 1), "submit_and_wait");
        check(io_uring_wait_cqe(ring, &cqe), "wait_cqe");
        io_uring_cqe_seen(ring, cqe);
    }
}

static void fill_nops(struct io_uring *ring)
{
    for (uint64_t i = 0; i < BATCH; i++) {
        struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
        io_uring_prep_nop(sqe);
        io_uring_sqe_set_data64(sqe, i);
    }
}

/* `BATCH` NOPs from `io_uring_get_sqe` per submit, `n` in total (per-op overhead) */
static void nop_batch(struct io_uring *ring, uint64_t n)
{
    struct io_uring_cqe *cqe;
    for (uint64_t r = 0; r < n / BATCH; r++) {
        fill_nops(ring);
        check(io_uring_submit(ring), "submit");
        check(io_uring_wait_cqe_nr(ring, &cqe, BATCH), "wait_cqe_nr");
        io_uring_cq_advance(ring, BATCH);
    }
}

/* `nop_batch`, plus reading every completion's `user_data` and `res` (what a server does) */
static void nop_batch_read(struct io_uring *ring, uint64_t n)
{
    struct io_uring_cqe *cqe;
    uint64_t sum = 0;
    for (uint64_t r = 0; r < n / BATCH; r++) {
        fill_nops(ring);
        check(io_uring_submit(ring), "submit");
        check(io_uring_wait_cqe_nr(ring, &cqe, BATCH), "wait_cqe_nr");
        unsigned head, count = 0;
        io_uring_for_each_cqe(ring, head, cqe) {
            sum += cqe->user_data + (uint64_t)(int64_t)cqe->res;
            if (++count == BATCH)
                break;
        }
        io_uring_cq_advance(ring, BATCH);
    }
    keep(sum);
}

/* `BATCH` NOPs prepared once in an array and copied into the ring per submit (what `put_sqe` does) */
static void put_batch(struct io_uring *ring, uint64_t n)
{
    static struct io_uring_sqe sqes[BATCH];
    struct io_uring_cqe *cqe;
    for (uint64_t i = 0; i < BATCH; i++) {
        io_uring_prep_nop(&sqes[i]);
        io_uring_sqe_set_data64(&sqes[i], i);
    }
    for (uint64_t r = 0; r < n / BATCH; r++) {
        for (int i = 0; i < BATCH; i++)
            *io_uring_get_sqe(ring) = sqes[i];
        check(io_uring_submit(ring), "submit");
        check(io_uring_wait_cqe_nr(ring, &cqe, BATCH), "wait_cqe_nr");
        io_uring_cq_advance(ring, BATCH);
    }
}

struct bench_case {
    const char *name;
    uint64_t n;
    void (*run)(struct io_uring *, uint64_t);
};

static const struct bench_case cases[] = {
    {"nop serial", 100000, nop_serial},
    {"nop batch x1024", 1024000, nop_batch},
    {"nop batch x1024 + read", 1024000, nop_batch_read},
    {"put_sqe batch x1024", 1024000, put_batch},
};

static double now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

/* one run of `c` on a fresh ring of `2 * BATCH` entries (as `loop_bench.py`); seconds */
static double run_once(const struct bench_case *c)
{
    struct io_uring ring;
    check(io_uring_queue_init(BATCH * 2, &ring, 0), "queue_init");
    double start = now();
    c->run(&ring, c->n);
    double took = now() - start;
    io_uring_queue_exit(&ring);
    return took;
}

int main(void)
{
    printf("C liburing %d.%d, best of %d\n\n", io_uring_major_version(), io_uring_minor_version(), ROUNDS);
    printf("%-26s%10s%11s%9s\n", "case", "ops", "total ms", "ns/op");
    for (size_t k = 0; k < sizeof(cases) / sizeof(cases[0]); k++) {
        double best = 1e30;
        for (int r = 0; r < ROUNDS; r++) {
            double t = run_once(&cases[k]);
            if (t < best)
                best = t;
        }
        printf("%-26s%10llu%11.1f%9.0f\n", cases[k].name, (unsigned long long)cases[k].n, best * 1e3,
               best / cases[k].n * 1e9);
    }
    return 0;
}
