# Liburing Benchmarks

The latest benchmark run, with each run's raw numbers.

## Setup

- AMD Ryzen 9 9900X (12 cores / 24 threads, 2 CCDs: CPUs 0-5 + 12-17 and 6-11 + 18-23), Linux 7.2.11
- Zig 0.17.0, Python 3.15.0 / 3.15t, 3.14.8 / 3.14t, C liburing 2.15 (the `lib/liburing` submodule)
- Liburing built with `zig build develop -Drelease`; C with `zig cc -O2`; Zig servers `-OReleaseFast`
- HTTP load: `tools/load.zig` (from Shakti), `zig-out/bin/load PORT 64 5 100`: 64 threads, each one connection
  after another, 100 keep-alive requests per connection, for 5 seconds
- HTTP server: one thread, pinned to CPU 2 (`taskset -c 2`); load on the same CCD:
  `taskset -c 0,1,3,4,5,12,13,15,16,17` (CCD0 without CPU 2 and its SMT sibling 14)
- `net.netfilter.nf_conntrack_max = 1048576` since 2026-10-22 (was 262,144, which back-to-back runs fill up: see
  the note under "Every run" below)

## HTTP keep-alive server, 2026-10-22

The same server (accept, recv, send the 214-byte response, recv again; close on 0 or error) written several ways:
`liburing_bench.c` (C liburing), `epoll_bench.c` (C epoll), `liburing_bench.py` (Liburing), `epoll_bench.py`
(`select.epoll`, written the same way as the Liburing one) and `asyncio_bench.py` (asyncio `sock_recv` /
`sock_sendall`, from Shakti). Liburing arms each request three ways:

- default: a normal SQE, as the C API does. `io_uring_get_sqe(ring)`, the prep, `sqe.user_data = ...`: 3 calls and
  a new `SQE` object per request.
- `--ring`: `Sqe(ring)`, one object for the ring's lifetime. Each prep takes the ring's next free entry: the prep
  and `sqe.user_data = ...`, 2 calls and no object per request.
- `--tmpl`: `Sqe(no)` templates. Each connection's recv and send are prepared once, in an `Sqe()` each, and copied
  into the ring with `put_sqe`: 1 call and no object per request (a partial send still preps the rest).
  `liburing_bench.c` uses `get_sqe` + prep, as the default does.

Every server reads completions as before (`cqe[i]`, then `io_uring_cq_advance`). 5 runs each, all servers
interleaved, `-Drelease`. `--defer` (C only here): the ring is set up with
`IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN`.

| server | req/s |
|:--|--:|
| C liburing | **634k** |
| C epoll | **597k** |
| Liburing `Sqe(n)`, 3.15 | **498k** |
| epoll, Python 3.15 | **494k** |
| Liburing `Sqe(ring)`, 3.15 | **478k** |
| Liburing `get_sqe`, 3.15 | **448k** |
| asyncio, Python 3.15 | **139k** |

### Summary: req/s, median, best first

| server | req/s | |
|:--|--:|:--|
| C liburing `--defer` | 634,383 | `███████████████████████████████████████` |
| C liburing | 633,614 | `███████████████████████████████████████` |
| C epoll | 597,375 | `████████████████████████████████████▊` |
| Liburing, 3.15 `--tmpl` | 497,850 | `██████████████████████████████▋` |
| epoll, 3.15 | 494,098 | `██████████████████████████████▍` |
| Liburing, 3.14 `--tmpl` | 492,350 | `██████████████████████████████▎` |
| epoll, 3.15t | 490,817 | `██████████████████████████████▎` |
| epoll, 3.14 | 484,224 | `█████████████████████████████▊` |
| Liburing, 3.15t `--tmpl` | 483,630 | `█████████████████████████████▊` |
| epoll, 3.14t | 482,725 | `█████████████████████████████▊` |
| Liburing, 3.14t `--tmpl` | 480,615 | `█████████████████████████████▋` |
| Liburing, 3.15 `--ring` | 478,123 | `█████████████████████████████▍` |
| Liburing, 3.14 `--ring` | 470,077 | `████████████████████████████▉` |
| Liburing, 3.15t `--ring` | 451,656 | `███████████████████████████▊` |
| Liburing, 3.14t `--ring` | 449,273 | `███████████████████████████▋` |
| Liburing, 3.15 | 448,454 | `███████████████████████████▋` |
| Liburing, 3.14 | 440,786 | `███████████████████████████▏` |
| Liburing, 3.15t | 427,378 | `██████████████████████████▎` |
| Liburing, 3.14t | 415,696 | `█████████████████████████▋` |
| asyncio, 3.15 | 138,831 | `████████▌` |
| asyncio, 3.14 | 134,417 | `████████▎` |
| asyncio, 3.15t | 129,882 | `████████` |
| asyncio, 3.14t | 127,505 | `███████▉` |

### Every run, req/s

| server | run 1 | run 2 | run 3 | run 4 | run 5 | low - max (used) |
|:--|--:|--:|--:|--:|--:|--:|
| C liburing | 634,646 | 630,049 | 633,614 | 634,270 | 631,815 | 630,049 - 634,646 |
| C liburing `--defer` | 634,922 | 635,241 | 632,394 | 634,383 | 629,649 | 629,649 - 635,241 |
| C epoll | 594,138 | 599,987 | 597,375 | 599,014 | 596,489 | 594,138 - 599,987 |
| Liburing, 3.15 | 448,537 | 448,454 | 451,617 | 448,444 | 446,563 | 446,563 - 451,617 |
| Liburing, 3.15 `--ring` | 478,123 | 478,248 | 475,821 | 478,172 | 474,760 | 474,760 - 478,248 |
| Liburing, 3.15t | 426,876 | 426,594 | 431,152 | 429,647 | 427,378 | 426,594 - 431,152 |
| Liburing, 3.15t `--ring` | 451,656 | 451,345 | 454,619 | 455,701 | 449,953 | 449,953 - 455,701 |
| Liburing, 3.14 | 440,963 | 440,786 | 440,746 | 439,202 | 445,697 | 439,202 - 445,697 |
| Liburing, 3.14 `--ring` | 468,863 | 472,127 | 470,077 | 470,584 | 470,054 | 468,863 - 472,127 |
| Liburing, 3.14t | 405,293 | 418,366 | 415,696 | 413,856 | 418,200 | 405,293 - 418,366 |
| Liburing, 3.14t `--ring` | 450,422 | 446,422 | 449,061 | 452,081 | 449,273 | 446,422 - 452,081 |
| Liburing, 3.15 `--tmpl` | 497,771 | 487,052 | 499,107 | 499,754 | 497,850 | 487,052 - 499,754 |
| Liburing, 3.15t `--tmpl` | 483,059 | 483,630 | 481,794 | 484,992 | 485,888 | 481,794 - 485,888 |
| Liburing, 3.14 `--tmpl` | 492,088 | 496,450 | 493,324 | 490,787 | 492,350 | 490,787 - 496,450 |
| Liburing, 3.14t `--tmpl` | 474,213 | 483,554 | 482,474 | 479,339 | 480,615 | 474,213 - 483,554 |
| epoll, 3.15 | 493,265 | 499,050 | 497,024 | 494,098 | 491,476 | 491,476 - 499,050 |
| epoll, 3.15t | 492,956 | 484,976 | 490,817 | 487,887 | 492,281 | 484,976 - 492,956 |
| epoll, 3.14 | 480,610 | 488,199 | 486,310 | 484,224 | 484,114 | 480,610 - 488,199 |
| epoll, 3.14t | 482,373 | 483,451 | 483,267 | 479,529 | 482,725 | 479,529 - 483,451 |
| asyncio, 3.15 | 139,052 | 138,831 | 138,704 | 139,078 | 138,152 | 138,152 - 139,078 |
| asyncio, 3.15t | 129,044 | 129,990 | 130,473 | 129,037 | 129,882 | 129,037 - 130,473 |
| asyncio, 3.14 | 133,788 | 132,493 | 134,436 | 134,982 | 134,417 | 132,493 - 134,982 |
| asyncio, 3.14t | 128,103 | 126,790 | 128,528 | 127,505 | 126,643 | 126,643 - 128,528 |

115 runs, no failed request, no run longer than 5.04 s, every set within 5%. An earlier run of this set had runs
far below the rest (11 of 145): the kernel's conntrack table (`net.netfilter.nf_conntrack_max`, 262,144 then)
filled up, since each run opens ~30,000 connections and a closed one stays in the table for 120 s. A full table
drops new connections, loopback included, so `connect` waits for its retries (1, 3, 7, ... s; up to 68 s seen) and
the server sits idle. These runs are with `nf_conntrack_max` at 1,048,576 (the table peaked at 364,075).

### Server CPU per request

Server CPU time (user + kernel, from `/proc/PID/stat`) over each 5 s run, the runs above.

| server | server CPU | µs/req (median) | low - high | runs |
|:--|--:|--:|--:|--:|
| C liburing | 53% | 0.84 | 0.83 - 0.84 | 5 |
| C liburing `--defer` | 53% | 0.84 | 0.83 - 0.84 | 5 |
| C epoll | 56-57% | 0.95 | 0.94 - 0.95 | 5 |
| Liburing, 3.15 | 66% | 1.47 | 1.46 - 1.49 | 5 |
| Liburing, 3.15 `--ring` | 64% | 1.35 | 1.34 - 1.35 | 5 |
| Liburing, 3.15t | 67-68% | 1.59 | 1.56 - 1.60 | 5 |
| Liburing, 3.15t `--ring` | 66% | 1.46 | 1.44 - 1.48 | 5 |
| Liburing, 3.14 | 67% | 1.52 | 1.50 - 1.53 | 5 |
| Liburing, 3.14 `--ring` | 65% | 1.38 | 1.37 - 1.38 | 5 |
| Liburing, 3.14t | 68-69% | 1.65 | 1.63 - 1.71 | 5 |
| Liburing, 3.14t `--ring` | 66% | 1.48 | 1.46 - 1.48 | 5 |
| Liburing, 3.15 `--tmpl` | 62-64% | 1.26 | 1.25 - 1.31 | 5 |
| Liburing, 3.15t `--tmpl` | 64% | 1.32 | 1.31 - 1.33 | 5 |
| Liburing, 3.14 `--tmpl` | 63% | 1.28 | 1.27 - 1.29 | 5 |
| Liburing, 3.14t `--tmpl` | 64% | 1.33 | 1.32 - 1.36 | 5 |
| epoll, 3.15 | 62% | 1.26 | 1.24 - 1.27 | 5 |
| epoll, 3.15t | 62-63% | 1.28 | 1.27 - 1.29 | 5 |
| epoll, 3.14 | 62-63% | 1.30 | 1.29 - 1.30 | 5 |
| epoll, 3.14t | 62-63% | 1.30 | 1.29 - 1.31 | 5 |
| asyncio, 3.15 | 87-88% | 6.31 | 6.31 - 6.34 | 5 |
| asyncio, 3.15t | 89% | 6.83 | 6.80 - 6.88 | 5 |
| asyncio, 3.14 | 88% | 6.58 | 6.54 - 6.67 | 5 |
| asyncio, 3.14t | 89% | 6.95 | 6.92 - 7.02 | 5 |

No server uses its whole core: req/s is limited by the round trip (64 connections, one request in flight each), so
CPU per request is the better measure. Per request on 3.15: `get_sqe` 1.47 µs, `Sqe(ring)` 1.35, `Sqe(no)` 1.26,
epoll 1.26. `Sqe(ring)` saves 0.12-0.17 µs/req over `get_sqe`, and templates another 0.09-0.15. With templates
Liburing ties `select.epoll` on 3.15 (1.26 vs 1.26) and beats it on 3.14 (1.28 vs 1.30); free-threaded it is
0.03-0.04 behind (1.32 vs 1.28 on 3.15t, 1.33 vs 1.30 on 3.14t). Without templates it is ~0.08-0.09 µs/req behind
with the GIL and ~0.18 free-threaded. In C, io_uring costs ~12% less than epoll (0.84 vs 0.95 µs).

### Where the Python cost goes

- Per request, epoll makes ~2 Python calls (`recv_into`, `send`) plus one `(fd, events)` tuple from `poll()`: 2
  cheap syscalls.
- Liburing arms each request with 3 calls (`get_sqe`), 2 (`Sqe(ring)`) or 1 (`Sqe(no)`), then reads `cqe[i]`,
  `.user_data`, `.res`, twice per request (recv + send). Each call costs ~15-25 ns, and an object costs more.
- asyncio is ~3.5x slower than Liburing, mostly from its own machinery (a task per connection, a future per
  `sock_recv` / `sock_sendall`, a new `bytes` per recv), not from epoll.
- Left to try: `--at` (`cqe.user_data_at(i)` / `res_at(i)`, no `CQE` objects: ~0.01-0.05 µs/req),
  multishot recv with a provided buffer ring (one SQE for many recvs), and the free-threaded extra cost.

## How to run

```sh
zig build develop -Drelease
zig build load

# HTTP: start one server on CPU 2, then the load on the same CCD
taskset -c 2 zig-out/bin/liburing_bench_c 12345   # or --defer
taskset -c 2 zig-out/bin/epoll_bench_c 12345
PYTHONPATH=src taskset -c 2 python3.15 example/bench/liburing_bench.py 12345   # or --at, --defer, --tmpl, --ring
taskset -c 2 python3.15 example/bench/epoll_bench.py 12345
taskset -c 2 python3.15 example/bench/asyncio_bench.py 12345
taskset -c 0,1,3,4,5,12,13,15,16,17 zig-out/bin/load 12345 64 5 100

# C servers
zig cc -O2 -D_GNU_SOURCE -Ilib/liburing/src/include -o zig-out/bin/liburing_bench_c \
    example/bench/liburing_bench.c lib/liburing/src/{setup,queue,register,syscall,version}.c
zig cc -O2 -o zig-out/bin/epoll_bench_c example/bench/epoll_bench.c
```
