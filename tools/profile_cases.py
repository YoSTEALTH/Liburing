'''The cases `zig build profile` measures: Liburing's hot path, one statement each, run under callgrind by Setu's
`tools/check_profile.py` (instructions per call, in total and per line of the Zig code; the docs' Profile page).

    zig build profile -Drelease -Dcpu=x86_64_v3                  # the table; zig-out/profile.json
    zig build profile -Drelease -Dcpu=x86_64_v3 -- -k prep --lines 8
    zig build profile -Drelease -Dcpu=x86_64_v3 -- --python /opt/python/3.15t/bin/python3

Note
    - `CASES` is a list of `(label, statement)`; `namespace(m)` the names the statements use, with `m` the
      extension as built for the run (each case runs in a process of its own).
    - The round trips are NOPs (no sockets): the same three ways `example/bench/liburing_bench.py` arms a request;
      and a read of `/dev/zero` into a `bytearray` (held until its completion), as a server's `recv`.
      The preps fill a `Sqe()` template that is never submitted, so `fd` 0 is never read or written.
'''

import os

# a round trip's second half: submit the one SQE, wait for its completion, consume it
REAP = '; io_uring_submit_and_wait(ring, 1); io_uring_wait_cqe(ring, cqe); io_uring_cqe_seen(ring, cqe[0])'
# the same, reading the completion's object and `res` (`io_uring_sqe_set_data`, then `cqe.data_res`)
DATA = '; io_uring_submit_and_wait(ring, 1); io_uring_wait_cqe(ring, cqe); o, r = cqe.data_res(0)'
DATA += '; io_uring_cqe_seen(ring, cqe[0])'

# (label, statement); names from `namespace` below
CASES = [
    (
        'round trip: io_uring_get_sqe',
        'sqe = io_uring_get_sqe(ring); io_uring_prep_nop(sqe); sqe.user_data = 1' + REAP,
    ),
    ('round trip: Sqe(ring)', 'io_uring_prep_nop(next_sqe); next_sqe.user_data = 1' + REAP),
    ('round trip: put_sqe', 'put_sqe(ring, nop)' + REAP),
    (
        'round trip: Sqe(ring), set_data(obj)',
        'io_uring_prep_nop(next_sqe); io_uring_sqe_set_data(next_sqe, obj)' + DATA,
    ),
    (
        'round trip: io_uring_get_sqe, read(bytearray)',
        'sqe = io_uring_get_sqe(ring); io_uring_prep_read(sqe, zero, ba); sqe.user_data = 1' + REAP,
    ),
    ('round trip: Sqe(ring), read(bytearray)', 'io_uring_prep_read(next_sqe, zero, ba); next_sqe.user_data = 1' + REAP),
    ('io_uring_prep_nop(sqe)', 'io_uring_prep_nop(sqe)'),
    ('io_uring_prep_recv(sqe, 0)', 'io_uring_prep_recv(sqe, 0)'),
    ('io_uring_prep_recv(sqe, 0, bytearray)', 'io_uring_prep_recv(sqe, 0, ba)'),
    ('io_uring_prep_send(sqe, 0, bytes)', 'io_uring_prep_send(sqe, 0, by)'),
    ('sqe.user_data = 1', 'sqe.user_data = 1'),
    ('sqe.user_data', 'sqe.user_data'),
    ('io_uring_sqe_set_data(sqe, obj)', 'io_uring_sqe_set_data(sqe, obj)'),
    ('io_uring_peek_cqe(ring, cqe)', 'io_uring_peek_cqe(done, done_cqe)'),
    ('cqe[0]', 'done_cqe[0]'),
    ('cqe[0].res', 'done_cqe[0].res'),
    ('cqe.user_data_at(0)', 'done_cqe.user_data_at(0)'),
    ('cqe.res_at(0)', 'done_cqe.res_at(0)'),
    ('u, r = cqe.user_data_res(0)', 'u, r = done_cqe.user_data_res(0)'),
    ('o, r = cqe.data_res(0)', 'o, r = done_cqe.data_res(0)'),
]


def namespace(m):
    '''The names the statements use, from the extension `m`: `ring` (empty), `done` (one NOP completed, never seen,
    read through `done_cqe`), `sqe` (a template), `nop` (a template with a NOP), `next_sqe` (`Sqe(ring)`), `zero`
    (`/dev/zero`, open for the process' life), `obj` (any object, for `io_uring_sqe_set_data`).'''
    ns = {name: getattr(m, name) for name in dir(m) if not name.startswith('_')}
    ring, done, cqe, done_cqe = m.Ring(), m.Ring(), m.Cqe(), m.Cqe()
    m.io_uring_queue_init(8, ring)
    m.io_uring_queue_init(8, done)
    sqe = m.io_uring_get_sqe(done)
    m.io_uring_prep_nop(sqe)
    sqe.user_data = 7
    m.io_uring_submit_and_wait(done, 1)
    m.io_uring_wait_cqe(done, done_cqe)
    nop = m.Sqe()
    m.io_uring_prep_nop(nop)
    ns.update(
        ring=ring,
        cqe=cqe,
        done=done,
        done_cqe=done_cqe,
        sqe=m.Sqe(),
        nop=nop,
        next_sqe=m.Sqe(ring),
        ba=bytearray(64),
        by=b'x' * 64,
        zero=os.open('/dev/zero', os.O_RDONLY),
        obj=object(),
    )
    return ns
