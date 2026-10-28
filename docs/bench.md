# Liburing Benchmarks

The latest benchmark runs, with each run's raw numbers: one server thread (Liburing against C, `select.epoll` and asyncio), then several (Liburing against `select.epoll`, with and without the GIL).

## Setup

- AMD Ryzen 9 9900X (12 cores / 24 threads, 2 CCDs: CPUs 0-5 + 12-17 and 6-11 + 18-23), Linux 7.3.0
- Zig 0.17.0, Python 3.15.0 / 3.15t, 3.14.8 / 3.14t, C liburing 2.15 (the `lib/liburing` submodule)
- Liburing built with `zig build develop -Drelease`; C with `zig cc -O2`; Zig servers `-OReleaseFast`
- HTTP load: `tools/load.zig`, `zig-out/bin/load PORT CONNECTIONS 5 100`: a thread per connection, each one connection after another, 100 keep-alive requests per connection, for 5 seconds
- `net.netfilter.nf_conntrack_max = 262144` (back-to-back runs fill it up: see the note under "Every run" below)

## Single-threaded, 2026-10-24

One server thread, pinned to CPU 2 (`taskset -c 2`); the load, 64 connections, on the same CCD: `taskset -c 0,1,3,4,5,12,13,15,16,17` (CCD0 without CPU 2 and its SMT sibling 14).

The same server (accept, recv, send the 214-byte response, recv again; close on 0 or error) written several ways:
`liburing_bench.c` (C liburing), `epoll_bench.c` (C epoll), `liburing_bench.py` (Liburing), `epoll_bench.py`
(`select.epoll`, written the same way as the Liburing one) and `asyncio_bench.py` (asyncio `sock_recv` /
`sock_sendall`). Liburing arms each request three ways:

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
| C liburing | **627k** |
| C epoll | **593k** |
| Liburing `Sqe(n)`, 3.15 | **501k** |
| epoll, Python 3.15 | **499k** |
| Liburing `Sqe(ring)`, 3.15 | **476k** |
| Liburing `get_sqe`, 3.15 | **446k** |
| asyncio, Python 3.15 | **140k** |

### Summary: req/s, median, best first

<!-- chart group="^(C \w+|\w+)" -->
| server | req/s | |
|:--|--:|:--|
| C liburing | 627,427 | `███████████████████████████████████████` |
| C liburing `--defer` | 623,016 | `██████████████████████████████████████▊` |
| C epoll | 592,691 | `████████████████████████████████████▉` |
| Liburing, 3.15 `--tmpl` | 500,999 | `███████████████████████████████▏` |
| epoll, 3.15 | 499,194 | `███████████████████████████████` |
| epoll, 3.15t | 488,873 | `██████████████████████████████▍` |
| Liburing, 3.14 `--tmpl` | 487,520 | `██████████████████████████████▎` |
| Liburing, 3.15t `--tmpl` | 486,087 | `██████████████████████████████▎` |
| epoll, 3.14t | 481,487 | `█████████████████████████████▉` |
| epoll, 3.14 | 479,860 | `█████████████████████████████▉` |
| Liburing, 3.14t `--tmpl` | 478,660 | `█████████████████████████████▊` |
| Liburing, 3.15 `--ring` | 475,821 | `█████████████████████████████▋` |
| Liburing, 3.14 `--ring` | 465,683 | `█████████████████████████████` |
| Liburing, 3.15t `--ring` | 453,713 | `████████████████████████████▎` |
| Liburing, 3.14t `--ring` | 448,088 | `███████████████████████████▉` |
| Liburing, 3.15 | 446,145 | `███████████████████████████▊` |
| Liburing, 3.14 | 440,987 | `███████████████████████████▍` |
| Liburing, 3.14t | 423,244 | `██████████████████████████▎` |
| Liburing, 3.15t | 423,016 | `██████████████████████████▎` |
| asyncio, 3.15 | 139,738 | `████████▋` |
| asyncio, 3.14 | 133,654 | `████████▎` |
| asyncio, 3.15t | 130,463 | `████████▏` |
| asyncio, 3.14t | 126,796 | `███████▉` |

### Every run, req/s

| server | run 1 | run 2 | run 3 | run 4 | run 5 | low - max (used) |
|:--|--:|--:|--:|--:|--:|--:|
| C liburing | 627,427 | 631,626 | 628,526 | 566,305 | 564,340 | 564,340 - 631,626 |
| C liburing `--defer` | 627,539 | 625,438 | 623,016 | 566,887 | 559,275 | 559,275 - 627,539 |
| C epoll | 592,691 | 592,975 | 594,404 | 540,816 | 537,331 | 537,331 - 594,404 |
| Liburing, 3.15 | 453,833 | 448,629 | 443,676 | 446,145 | 413,010 | 413,010 - 453,833 |
| Liburing, 3.15 `--ring` | 476,744 | 475,821 | 470,441 | 476,984 | 435,829 | 435,829 - 476,984 |
| Liburing, 3.15t | 431,540 | 423,016 | 395,022 | 429,467 | 393,761 | 393,761 - 431,540 |
| Liburing, 3.15t `--ring` | 453,713 | 454,413 | 451,145 | 455,107 | 414,402 | 414,402 - 455,107 |
| Liburing, 3.14 | 440,987 | 442,219 | 441,052 | 408,908 | 405,129 | 405,129 - 442,219 |
| Liburing, 3.14 `--ring` | 465,683 | 468,446 | 469,318 | 432,806 | 429,873 | 429,873 - 469,318 |
| Liburing, 3.14t | 423,665 | 423,244 | 433,545 | 397,743 | 391,917 | 391,917 - 433,545 |
| Liburing, 3.14t `--ring` | 452,101 | 448,088 | 453,505 | 421,768 | 416,956 | 416,956 - 453,505 |
| Liburing, 3.15 `--tmpl` | 506,054 | 501,616 | 496,519 | 500,999 | 454,749 | 454,749 - 506,054 |
| Liburing, 3.15t `--tmpl` | 486,087 | 489,863 | 480,952 | 489,859 | 444,886 | 444,886 - 489,863 |
| Liburing, 3.14 `--tmpl` | 489,486 | 489,506 | 487,520 | 447,864 | 450,910 | 447,864 - 489,506 |
| Liburing, 3.14t `--tmpl` | 483,902 | 484,789 | 478,660 | 443,128 | 440,792 | 440,792 - 484,789 |
| epoll, 3.15 | 506,282 | 505,375 | 499,194 | 498,575 | 444,488 | 444,488 - 506,282 |
| epoll, 3.15t | 488,873 | 489,360 | 493,021 | 487,316 | 446,039 | 446,039 - 493,021 |
| epoll, 3.14 | 479,860 | 482,855 | 486,838 | 435,905 | 437,990 | 435,905 - 486,838 |
| epoll, 3.14t | 481,958 | 481,487 | 482,791 | 432,109 | 434,015 | 432,109 - 482,791 |
| asyncio, 3.15 | 140,349 | 140,942 | 138,827 | 139,738 | 134,956 | 134,956 - 140,942 |
| asyncio, 3.15t | 130,463 | 130,701 | 130,953 | 126,637 | 126,071 | 126,071 - 130,953 |
| asyncio, 3.14 | 133,654 | 135,057 | 135,001 | 130,423 | 131,614 | 130,423 - 135,057 |
| asyncio, 3.14t | 127,378 | 126,796 | 127,056 | 124,442 | 122,285 | 122,285 - 127,378 |

115 runs, no failed request, no run longer than 5.04 s. The runs in each set spread 4-14%: round 5 (and
round 4 for a few) came out ~9% lower on every server, C included, so the dip is the machine, not a server; the
median of 5 is unaffected. The kernel's conntrack table (`net.netfilter.nf_conntrack_max`, 262,144 again after a
reboot) fills up if runs go back to back: each run opens ~30,000 connections and a closed one stays in the table
for 120 s. A full table drops new connections, loopback included, so `connect` waits for its retries (1, 3, 7, ... s)
and the server sits idle (11 of 145 runs in an earlier set). The runner waited while the table held more than
200,000 entries (peak 212,556).

### Server CPU per request

Server CPU time (user + kernel, from `/proc/PID/stat`) over each 5 s run, the runs above.

| server | server CPU | µs/req (median) | low - high | runs |
|:--|--:|--:|--:|--:|
| C liburing | 53-55% | 0.85 | 0.84 - 0.97 | 5 |
| C liburing `--defer` | 53-55% | 0.85 | 0.85 - 0.97 | 5 |
| C epoll | 56-58% | 0.95 | 0.95 - 1.07 | 5 |
| Liburing, 3.15 | 66-67% | 1.49 | 1.47 - 1.61 | 5 |
| Liburing, 3.15 `--ring` | 64-65% | 1.36 | 1.35 - 1.49 | 5 |
| Liburing, 3.15t | 68-69% | 1.62 | 1.57 - 1.73 | 5 |
| Liburing, 3.15t `--ring` | 66% | 1.46 | 1.46 - 1.59 | 5 |
| Liburing, 3.14 | 67% | 1.52 | 1.51 - 1.65 | 5 |
| Liburing, 3.14 `--ring` | 65% | 1.39 | 1.38 - 1.51 | 5 |
| Liburing, 3.14t | 68% | 1.61 | 1.56 - 1.74 | 5 |
| Liburing, 3.14t `--ring` | 66% | 1.47 | 1.46 - 1.59 | 5 |
| Liburing, 3.15 `--tmpl` | 63% | 1.25 | 1.24 - 1.39 | 5 |
| Liburing, 3.15t `--tmpl` | 63-64% | 1.30 | 1.30 - 1.44 | 5 |
| Liburing, 3.14 `--tmpl` | 63-64% | 1.30 | 1.28 - 1.42 | 5 |
| Liburing, 3.14t `--tmpl` | 63-64% | 1.33 | 1.31 - 1.45 | 5 |
| epoll, 3.15 | 62-63% | 1.25 | 1.24 - 1.41 | 5 |
| epoll, 3.15t | 62-63% | 1.28 | 1.27 - 1.40 | 5 |
| epoll, 3.14 | 63% | 1.31 | 1.29 - 1.45 | 5 |
| epoll, 3.14t | 63-64% | 1.31 | 1.31 - 1.48 | 5 |
| asyncio, 3.15 | 87-88% | 6.24 | 6.21 - 6.44 | 5 |
| asyncio, 3.15t | 88-89% | 6.79 | 6.75 - 6.99 | 5 |
| asyncio, 3.14 | 87-88% | 6.59 | 6.50 - 6.71 | 5 |
| asyncio, 3.14t | 88-89% | 6.99 | 6.98 - 7.24 | 5 |

No server uses its whole core: req/s is limited by the round trip (64 connections, one request in flight each), so
CPU per request is the better measure. Per request on 3.15: `get_sqe` 1.49 µs, `Sqe(ring)` 1.36, `Sqe(no)` 1.25,
epoll 1.25. `Sqe(ring)` saves 0.12-0.16 µs/req over `get_sqe`, and templates another 0.10-0.16. With templates
Liburing ties `select.epoll` on 3.15 (1.25 vs 1.25) and is 0.01 ahead on 3.14 (1.30 vs 1.31); free-threaded it is
0.02 behind (1.30 vs 1.28 on 3.15t, 1.33 vs 1.31 on 3.14t). Without templates it is ~0.08-0.11 µs/req behind
with the GIL and ~0.16-0.18 free-threaded (`Sqe(ring)`). In C, io_uring costs ~11% less than epoll (0.85 vs 0.95 µs).

### Where the Python cost goes

- Per request, epoll makes ~2 Python calls (`recv_into`, `send`) plus one `(fd, events)` tuple from `poll()`: 2
  cheap syscalls.
- Liburing arms each request with 3 calls (`get_sqe`), 2 (`Sqe(ring)`) or 1 (`Sqe(no)`), then reads `cqe[i]`,
  `.user_data`, `.res`, twice per request (recv + send). Each call costs ~15-25 ns, and an object costs more.
- asyncio is ~3.2-3.6x slower than Liburing, mostly from its own machinery (a task per connection, a future per
  `sock_recv` / `sock_sendall`, a new `bytes` per recv), not from epoll.
- Left to try: `--at` (`cqe.user_data_at(i)` / `res_at(i)`, no `CQE` objects: ~0.01-0.05 µs/req),
  multishot recv with a provided buffer ring (one SQE for many recvs), and the free-threaded extra cost.

## Multi-threaded, 2026-10-28

The same Liburing and `select.epoll` servers, run by N threads in one process (`--threads=N`): each thread is the single-threaded server, with its own ring or epoll and its own listening socket on the port (`SO_REUSEPORT`: the kernel spreads the connections), pinned to one CPU. Liburing arms with `Sqe(ring)` and reads each completion with `cqe.user_data_res(i)` (`--ring --at`). With the GIL (3.15, 3.14) the threads take turns in Python; free-threaded (3.15t, 3.14t) they run at once.

- Server threads on CPUs 2, 2-3 or 2-5 (`taskset -c`, one thread each); the load, 256 connections, on the rest of CCD0 without their SMT siblings, and on CCD1: `taskset -c 0,1,12,13,6-11,18-23`
- 5 runs each, all servers interleaved; the runner waited while the conntrack table held more than 200,000 entries
- Server CPU: every server thread's run time (`/proc/PID/task/*/schedstat`) over 4 s of each run, per request

### Summary: req/s with 4 threads, median, best first

<!-- chart group="^(\w+)" -->
| server | req/s | |
|:--|--:|:--|
| epoll, 3.15t | 1,153,363 | `███████████████████████████████████████` |
| Liburing `--ring --at`, 3.15t | 1,132,961 | `██████████████████████████████████████▎` |
| epoll, 3.14t | 1,124,762 | `██████████████████████████████████████` |
| Liburing `--ring --at`, 3.14t | 1,107,196 | `█████████████████████████████████████▍` |
| Liburing `--ring --at`, 3.15 | 1,055,800 | `███████████████████████████████████▋` |
| Liburing `--ring --at`, 3.14 | 1,053,398 | `███████████████████████████████████▌` |
| epoll, 3.15 | 685,031 | `███████████████████████▏` |
| epoll, 3.14 | 665,726 | `██████████████████████▌` |

### Scaling: req/s by server threads, median

| server | 1 thread | 2 threads | 4 threads | 4 vs 1 |
|:--|--:|--:|--:|--:|
| Liburing `--ring --at`, 3.15 | 262,252 | 510,754 | 1,055,800 | 4.03x |
| epoll, 3.15 | 269,053 | 482,785 | 685,031 | 2.55x |
| Liburing `--ring --at`, 3.15t | 257,451 | 509,294 | 1,132,961 | 4.40x |
| epoll, 3.15t | 263,594 | 519,942 | 1,153,363 | 4.38x |
| Liburing `--ring --at`, 3.14 | 262,336 | 508,401 | 1,053,398 | 4.02x |
| epoll, 3.14 | 261,658 | 476,091 | 665,726 | 2.54x |
| Liburing `--ring --at`, 3.14t | 253,185 | 502,415 | 1,107,196 | 4.37x |
| epoll, 3.14t | 259,212 | 501,762 | 1,124,762 | 4.34x |

### Server CPU per request, µs, median

| server | 1 thread | 2 threads | 4 threads |
|:--|--:|--:|--:|
| Liburing `--ring --at`, 3.15 | 2.08 | 2.09 | 1.91 |
| epoll, 3.15 | 2.09 | 2.36 | 3.39 |
| Liburing `--ring --at`, 3.15t | 2.17 | 2.17 | 2.03 |
| epoll, 3.15t | 2.14 | 2.16 | 1.97 |
| Liburing `--ring --at`, 3.14 | 2.08 | 2.10 | 1.91 |
| epoll, 3.14 | 2.19 | 2.41 | 3.48 |
| Liburing `--ring --at`, 3.14t | 2.19 | 2.21 | 2.10 |
| epoll, 3.14t | 2.20 | 2.26 | 2.02 |

### Every run, req/s

| server | threads | run 1 | run 2 | run 3 | run 4 | run 5 | low - max |
|:--|--:|--:|--:|--:|--:|--:|--:|
| Liburing `--ring --at`, 3.15 | 1 | 254,797 | 263,088 | 260,746 | 262,252 | 263,774 | 254,797 - 263,774 |
| Liburing `--ring --at`, 3.15 | 2 | 489,474 | 517,307 | 514,403 | 510,754 | 508,315 | 489,474 - 517,307 |
| Liburing `--ring --at`, 3.15 | 4 | 996,446 | 1,073,692 | 1,074,873 | 1,055,800 | 1,022,754 | 996,446 - 1,074,873 |
| epoll, 3.15 | 1 | 254,028 | 269,685 | 263,622 | 269,053 | 270,458 | 254,028 - 270,458 |
| epoll, 3.15 | 2 | 471,524 | 486,527 | 490,072 | 482,030 | 482,785 | 471,524 - 490,072 |
| epoll, 3.15 | 4 | 679,189 | 685,031 | 693,220 | 679,589 | 686,898 | 679,189 - 693,220 |
| Liburing `--ring --at`, 3.15t | 1 | 258,194 | 254,256 | 254,129 | 257,451 | 257,718 | 254,129 - 258,194 |
| Liburing `--ring --at`, 3.15t | 2 | 502,550 | 510,335 | 515,414 | 503,071 | 509,294 | 502,550 - 515,414 |
| Liburing `--ring --at`, 3.15t | 4 | 1,070,807 | 1,151,227 | 1,159,011 | 1,116,232 | 1,132,961 | 1,070,807 - 1,159,011 |
| epoll, 3.15t | 1 | 256,491 | 262,876 | 263,594 | 267,461 | 269,380 | 256,491 - 269,380 |
| epoll, 3.15t | 2 | 509,183 | 604,732 | 519,942 | 514,944 | 557,981 | 509,183 - 604,732 |
| epoll, 3.15t | 4 | 1,123,675 | 1,185,414 | 1,125,787 | 1,167,434 | 1,153,363 | 1,123,675 - 1,185,414 |
| Liburing `--ring --at`, 3.14 | 1 | 262,372 | 263,829 | 254,720 | 262,336 | 261,572 | 254,720 - 263,829 |
| Liburing `--ring --at`, 3.14 | 2 | 507,212 | 522,091 | 506,991 | 508,401 | 513,591 | 506,991 - 522,091 |
| Liburing `--ring --at`, 3.14 | 4 | 1,033,852 | 1,070,356 | 1,053,398 | 1,035,112 | 1,061,035 | 1,033,852 - 1,070,356 |
| epoll, 3.14 | 1 | 262,356 | 255,919 | 254,611 | 261,658 | 262,172 | 254,611 - 262,356 |
| epoll, 3.14 | 2 | 472,611 | 478,790 | 453,822 | 476,091 | 479,799 | 453,822 - 479,799 |
| epoll, 3.14 | 4 | 665,251 | 665,726 | 678,963 | 650,402 | 677,859 | 650,402 - 678,963 |
| Liburing `--ring --at`, 3.14t | 1 | 255,773 | 253,185 | 252,854 | 251,871 | 254,430 | 251,871 - 255,773 |
| Liburing `--ring --at`, 3.14t | 2 | 491,455 | 513,045 | 507,645 | 491,624 | 502,415 | 491,455 - 513,045 |
| Liburing `--ring --at`, 3.14t | 4 | 1,125,434 | 1,108,750 | 1,107,196 | 1,083,673 | 1,060,345 | 1,060,345 - 1,125,434 |
| epoll, 3.14t | 1 | 259,886 | 259,236 | 258,580 | 257,477 | 259,212 | 257,477 - 259,886 |
| epoll, 3.14t | 2 | 500,274 | 511,455 | 501,762 | 506,883 | 498,053 | 498,053 - 511,455 |
| epoll, 3.14t | 4 | 1,124,762 | 1,161,509 | 1,127,654 | 1,122,555 | 1,095,239 | 1,095,239 - 1,161,509 |

120 runs, no failed request. The server threads are only ~50% busy at any thread count (about 250k req/s each): the load generator, a blocking thread per connection on another CCD, sets the pace, so req/s here shows how the servers scale, and CPU per request what each request costs them.

- With the GIL Liburing scales and epoll does not: 4 threads give Liburing 1.06M req/s (4.0x one thread), epoll 685k (2.5x). A Liburing thread does its kernel work (the sends and receives) inside `io_uring_submit_and_wait`, with the GIL released, once per batch of completions; an epoll thread releases and retakes the GIL around every `recv_into` and `send`, and the threads queue for it: epoll's CPU per request rises from 2.09 µs (one thread) to 3.39 (four), Liburing's stays at ~2.
- Free-threaded both scale (4.4x), and epoll is ~2% ahead (1.15M vs 1.13M req/s on 3.15t; 1.97 vs 2.03 µs per request): the free-threaded extra cost of the single-threaded Liburing server, not a threading one.
- One thread: Liburing and epoll within ~3% of each other on every Python, as in the single-threaded results (this load is lighter per server thread, so the numbers differ from those).

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

# Multi-threaded: N server threads on CPUs 2.. (one each), the load on the rest of CCD0 (not their SMT siblings)
# and on CCD1
PYTHONPATH=src taskset -c 2-5 python3.15t example/bench/liburing_bench.py 12345 --ring --at --threads=4
taskset -c 2-5 python3.15t example/bench/epoll_bench.py 12345 --threads=4
taskset -c 0,1,12,13,6-11,18-23 zig-out/bin/load 12345 256 5 100

# C servers
zig cc -O2 -D_GNU_SOURCE -Ilib/liburing/src/include -o zig-out/bin/liburing_bench_c \
    example/bench/liburing_bench.c lib/liburing/src/{setup,queue,register,syscall,version}.c
zig cc -O2 -o zig-out/bin/epoll_bench_c example/bench/epoll_bench.c
```
