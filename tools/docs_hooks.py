'''Fixtures for the docstring examples on the docs site (`hooks` in `pyproject.toml`'s `[tool.setu_docs]`): what an
example reads but does not make itself (`ring`, `sqe`, `cqe`, `fd`, ...). `python3 tools/setu_docs.py check` runs
every example, each in a new temporary directory; `fd`s it leaves open are closed after it.'''

import array
import contextlib
import mmap
import os
import select
import signal
import socket
import struct
import time
from liburing import *

FIXTURES = {}
NAMESPACE = {
    'array': array, 'mmap': mmap, 'os': os, 'select': select, 'signal': signal, 'socket': socket, 'struct': struct,
    'time': time,
}  # fmt: skip
NO_DEVICE = 'needs a network device with zero-copy receive (and root)'
SKIP = {
    ('ZcrxIfqReg', 'reg.if_idx = socket.if_nametoindex("eth0")'): NO_DEVICE,
    ('ZcrxIfqReg', 'io_uring_register_ifq(ring, reg)'): NO_DEVICE,
    ('ZcrxCtrl', 'io_uring_register_zcrx_ctrl(ring, ctrl)'): NO_DEVICE,
    ('ZcrxCtrl', 'ctrl.zcrx_fd'): NO_DEVICE,
    (
        'UnsupportedError',
        'try:\n    io_uring_register_query(Query())\nexcept UnsupportedError as e:\n    e.errno, str(e)',
    ): 'shows a kernel without `IORING_REGISTER_QUERY` (6.12)',
}
LOOSE = {  # the kernel's answer: differs between kernels
    ('probe', 'probe()'),
    ('Probe', 'probe.last_op, probe.ops_len'),
    ('Query', 'query.data["nr_request_opcodes"]  # the kernel\'s count'),
    ('Query', 'query.data'),
    ('io_uring_register_iowq_max_workers', 'io_uring_register_iowq_max_workers(ring, 0, 0)  # (bounded, unbounded)'),
}  # fmt: skip


def fixture(*names):
    '''Register an `[async] def setup(ns)` for the examples of `names`.'''

    def register(fn):
        for name in names:
            FIXTURES[name] = fn
        return fn

    return register


def pinned():
    '''The memory the process has pinned, in kB (`VmPin`): what registered buffers lock, counted against
    `RLIMIT_MEMLOCK`.'''
    with open('/proc/self/status') as f:
        return next(int(line.split()[1]) for line in f if line.startswith('VmPin:'))


def exit_rings(rings, before):
    '''Exit `rings`, then wait (up to a second) until the kernel has released what they pinned, back to
    `before` kB. It frees an exited ring later, from a workqueue; a registered buffer in a huge page pins all
    2 MiB of it, so a few examples in a row would reach an 8 MiB `RLIMIT_MEMLOCK` (GitHub's runners), and every
    ring after them would fail with `OSError: ENOMEM`.'''
    for ring in rings:
        with contextlib.suppress(RuntimeError):  # the example may have exited it already
            io_uring_queue_exit(ring)
    deadline = time.monotonic() + 1
    while pinned() > before and time.monotonic() < deadline:
        time.sleep(0.001)


def make_ring(ns, name='ring', entries=1024, flags=0):
    '''`ns[name]`: a `Ring` of `entries` set up with `flags`, exited after the example.'''
    if '_rings' not in ns:  # the first ring of the example: one cleanup exits them all
        ns['_rings'] = []
        before = pinned()
        ns['_cleanup'].append(lambda: exit_rings(ns['_rings'], before))
    ring = Ring()
    param = Param()
    param.flags = flags
    io_uring_queue_init_params(entries, ring, param)
    ns[name] = ring
    ns['_rings'].append(ring)
    return ring


def queue_nops(ring, *user_data):
    '''Prep a NOP for each `user_data` (not submitted).'''
    for data in user_data:
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_nop(sqe)
        sqe.user_data = data


def make_file(ns, name='fd', data=b'hi... bye!'):
    '''`ns[name]`: an fd of `./file.txt` holding `data`, open for reading and writing.'''
    with open('file.txt', 'wb') as f:
        f.write(data)
    ns[name] = fd = os.open('file.txt', os.O_RDWR)
    return fd


def keep(ns, sock):
    '''`sock` is closed after the example.'''
    ns['_keep'].append(sock)
    return sock


@fixture(
    'io_uring_get_probe_ring', 'io_uring_ring_dontfork', 'io_uring_queue_exit', 'io_uring_register',
    'io_uring_set_iowait', 'io_uring_sq_ready', 'io_uring_sq_space_left', 'io_uring_sqring_wait', 'io_uring_get_sqe',
    'io_uring_get_events', 'io_uring_close_ring_fd', 'io_uring_register_ring_fd', 'io_uring_unregister_ring_fd',
    'io_uring_register_personality', 'io_uring_unregister_personality', 'io_uring_unregister_files',
    'io_uring_register_eventfd', 'io_uring_unregister_eventfd', 'io_uring_register_buffers', 'io_uring_buf_ring_head',
    'io_uring_register_iowq_aff', 'io_uring_register_iowq_max_workers', 'io_uring_cq_has_overflow',
    'io_uring_cq_eventfd_enabled', 'io_uring_cq_eventfd_toggle', 'BufReg', 'Napi', 'ClockRegister', 'Bpf', 'SQE',
    'SiginfoT', 'io_uring_prep_waitid', 'io_uring_prep_cancel', 'io_uring_prep_cancel64', 'ZcrxIfqReg',
)  # fmt: skip
def ring(ns):
    make_ring(ns)


@fixture(
    'io_uring_sqe_set_data', 'io_uring_sqe_set_data64', 'io_uring_sqe_set_flags', 'io_uring_sqe_set_buf_group',
    'io_uring_prep_nop', 'io_uring_prep_provide_buffers', 'Futex', 'timespec',
)  # fmt: skip
def sqe(ns):
    ns['sqe'] = io_uring_get_sqe(make_ring(ns))


@fixture('ZcrxCtrl')
def zcrx(ns):
    make_ring(ns)
    ns['zcrx_id'] = 0  # what `io_uring_register_ifq` gave (`ZcrxIfqReg.zcrx_id`)


@fixture('io_uring_enter', 'io_uring_enter2')
def ring_with_completion(ns):
    ring = make_ring(ns)
    queue_nops(ring, 1)
    io_uring_submit_and_wait(ring, 1)


@fixture('io_uring_resize_rings')
def ring_defer_taskrun(ns):
    make_ring(ns, flags=IORING_SETUP_SINGLE_ISSUER | IORING_SETUP_DEFER_TASKRUN)


@fixture('io_uring_get_sqe128')
def ring_sqe_mixed(ns):
    make_ring(ns, flags=IORING_SETUP_SQE_MIXED)


@fixture('io_uring_prep_nop128')
def sqe128(ns):
    ns['sqe'] = io_uring_get_sqe128(make_ring(ns, flags=IORING_SETUP_SQE_MIXED))


@fixture('io_uring_clone_buffers')
def two_rings(ns):
    make_ring(ns, 'src', 8)
    make_ring(ns, 'dst', 8)


@fixture('io_uring_prep_msg_ring')
def message_rings(ns):
    make_ring(ns, entries=8)
    make_ring(ns, 'other', 8)
    ns['cqe'] = Cqe()


@fixture('RegWait', 'MemRegionReg', 'Restriction')
def ring_disabled(ns):
    make_ring(ns, entries=8, flags=IORING_SETUP_R_DISABLED)
    ns['cqe'] = Cqe()


@fixture('io_uring_submit', 'io_uring_submit_and_wait', 'io_uring_submit_and_wait_timeout',
         'io_uring_submit_and_wait_min_timeout', 'io_uring_submit_and_get_events')  # fmt: skip
def queued(ns):
    '''Two NOPs (user_data 1, 2) queued, not submitted; an empty `cqe`.'''
    queue_nops(make_ring(ns), 1, 2)
    ns['cqe'] = Cqe()


@fixture('io_uring_submit_and_wait_reg')
def queued_reg(ns):
    '''A ring with a registered wait region (entry 0: wait up to a second), one NOP queued.'''
    ring = make_ring(ns, entries=8, flags=IORING_SETUP_R_DISABLED)
    mem = mmap.mmap(-1, 4096)
    region = MemRegionReg()
    region.flags = IORING_MEM_REGION_REG_WAIT_ARG
    region.region = mem
    io_uring_register_region(ring, region)
    io_uring_enable_rings(ring)
    wait = RegWait()
    wait.timeout = 1.0
    wait.flags = IORING_REG_WAIT_TS
    mem[0 : RegWait.SIZE] = wait.to_bytes()
    queue_nops(ring, 1)
    ns['cqe'] = Cqe()


@fixture(
    'Cqe', 'CqeBatch', 'CqeBatchIter', 'CqeIter', 'io_uring_peek_batch_cqe', 'io_uring_wait_cqes',
    'io_uring_wait_cqes_min_timeout', 'io_uring_wait_cqe_timeout', 'io_uring_cqe_iter_init', 'io_uring_cqe_iter_next',
    'io_uring_cq_advance', 'io_uring_cq_ready', 'io_uring_wait_cqe_nr', 'io_uring_peek_cqe', 'io_uring_wait_cqe',
)  # fmt: skip
def done(ns, flags=0):
    '''Two NOPs (user_data 1, 2) completed, still in the completion queue; an empty `cqe`.'''
    ring = make_ring(ns, flags=flags)
    queue_nops(ring, 1, 2)
    io_uring_submit_and_wait(ring, 2)
    ns['cqe'] = Cqe()
    return ring


@fixture(
    'CQE', 'Cqe.res_at', 'Cqe.user_data_at', 'io_uring_cqe_seen', 'io_uring_cqe_get_data', 'io_uring_cqe_get_data64',
    'io_uring_cqe_nr',
)  # fmt: skip
def done_seen(ns):
    '''`done`, with `cqe[0]` the first completion (user_data 1).'''
    io_uring_wait_cqe(done(ns), ns['cqe'])


@fixture('CQE.big_cqe')
def done_cqe32(ns):
    io_uring_wait_cqe(done(ns, IORING_SETUP_CQE32), ns['cqe'])


@fixture(
    'Sqe', 'put_sqe', 'io_uring_prep_open', 'io_uring_prep_open_direct', 'io_uring_prep_read', 'io_uring_prep_write',
    'io_uring_prep_statx', 'Statx', 'io_uring_register_files', 'io_uring_register_files_tags',
)  # fmt: skip
def file_ring(ns):
    '''A ring (2 entries for `put_sqe`, to show a full one), an empty `cqe` and `fd` of `./file.txt`
    (`hi... bye!`).'''
    make_ring(ns, entries=2 if ns['_name'] == 'put_sqe' else 1024)
    ns['cqe'] = Cqe()
    make_file(ns)


@fixture(
    'io_uring_prep_readv', 'io_uring_prep_read_fixed', 'io_uring_prep_readv_fixed', 'io_uring_prep_writev',
    'io_uring_prep_write_fixed', 'io_uring_prep_writev_fixed', 'io_uring_prep_close', 'io_uring_prep_close_direct',
    'io_uring_prep_madvise', 'io_uring_prep_madvise64', 'io_uring_prep_pipe', 'OpenHow',
)  # fmt: skip
def file_io(ns):
    '''`file_ring`, with an `sqe` of the ring.'''
    file_ring(ns)
    ns['sqe'] = io_uring_get_sqe(ns['ring'])


@fixture('io_uring_prep_cmd_getsockname', 'setsockopt', 'getsockopt', 'getsockname')
def net_ring(ns):
    '''A ring, `sockfd` (a TCP socket, `SO_KEEPALIVE` on) and `fd` (a listening one).'''
    make_ring(ns)
    sock = keep(ns, socket.socket())
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
    ns['sockfd'] = sock.fileno()
    ns['fd'] = keep(ns, socket.create_server(('127.0.0.1', 0))).fileno()


@fixture('io_uring_prep_accept', 'io_uring_prep_cmd_sock', 'Msghdr', 'Sockaddr')
def net(ns):
    '''`net_ring`, with an `sqe` of the ring.'''
    net_ring(ns)
    ns['sqe'] = io_uring_get_sqe(ns['ring'])


@fixture('EpollEvent')
def epoll(ns):
    '''A ring, `epfd` (an epoll instance) and `fd` (the read end of a pipe with data in it).'''
    make_ring(ns)
    ns['epfd'] = keep(ns, select.epoll()).fileno()
    r, w = os.pipe()
    os.write(w, b'x')
    ns['fd'] = r


@fixture('SyncCancelReg')
def pending_read(ns):
    '''A ring with a read (user_data 123) waiting on an empty pipe.'''
    ring = make_ring(ns)
    r, _w = os.pipe()
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, r, bytearray(1))
    sqe.user_data = 123
    io_uring_submit(ring)


@fixture('RecvmsgOut')
def received(ns):
    '''`buf` and `msg` of a multishot receive (`Msghdr(namelen=16, controllen=0)`) of `b'hello'` over UDP.'''
    ring = make_ring(ns, entries=8)
    cqe = Cqe()
    rx = keep(ns, socket.socket(socket.AF_INET, socket.SOCK_DGRAM))
    tx = keep(ns, socket.socket(socket.AF_INET, socket.SOCK_DGRAM))
    rx.bind(('127.0.0.1', 0))
    area = bytearray(256)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_provide_buffers(sqe, area, 1, 1, 0)  # one buffer of 256: group 1, id 0
    io_uring_submit_and_wait(ring, 1)
    io_uring_cq_advance(ring, 1)
    ns['msg'] = msg = Msghdr(namelen=16, controllen=0)
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_recvmsg_multishot(sqe, rx.fileno(), msg)
    sqe.flags = IOSQE_BUFFER_SELECT
    io_uring_sqe_set_buf_group(sqe, 1)
    io_uring_submit(ring)
    tx.sendto(b'hello', rx.getsockname())
    io_uring_wait_cqe_timeout(ring, cqe, timespec(2))
    io_uring_cqe_seen(ring, cqe[0])
    ns['buf'] = area


@fixture('Cmsghdr')
def received_fd(ns):
    '''`out` and `msg` of a received message with one `SCM_RIGHTS` control message (fd `7`), as the kernel lays it
    out in a provided buffer: `[header][name][control][payload]`.'''
    name = bytes(16)
    cmsg = struct.pack('=QII', struct.calcsize('=QII') + 4, socket.SOL_SOCKET, socket.SCM_RIGHTS)
    cmsg += struct.pack('=i', 7) + bytes(4)
    header = struct.pack('=IIII', len(name), len(cmsg), 3, 0)
    ns['msg'] = msg = Msghdr(namelen=len(name), controllen=len(cmsg))
    ns['out'] = io_uring_recvmsg_validate(bytearray(header + name + cmsg + b'abc'), msg)


# What the running kernel lacks (CI runs an older one than the examples show): its examples do not run.


def _setup_works(flags):
    '''Whether the kernel sets up a ring with `flags`.'''
    ring = Ring()
    try:
        io_uring_queue_init(8, ring, flags)
    except OSError:
        return False
    io_uring_queue_exit(ring)
    return True


def _register_works(call):
    '''Whether the kernel has the `io_uring_register` opcode `call(ring)` uses (`UnsupportedError` if not).'''
    ring = Ring()
    io_uring_queue_init(8, ring)
    try:
        call(ring)
    except UnsupportedError:
        return False
    except OSError:
        pass  # it has it: the arguments are what it refused
    finally:
        io_uring_queue_exit(ring)
    return True


def _bpf_filter(ring):
    bpf = Bpf()
    bpf.opcode = io_uring_op.IORING_OP_OPENAT
    bpf.filter = struct.pack('HBBI', 0x06, 0, 0, 0)
    io_uring_register_bpf_filter(ring, bpf)


if not _setup_works(IORING_SETUP_SQE_MIXED):  # no fixture: the examples are listed as not run
    del FIXTURES['io_uring_get_sqe128'], FIXTURES['io_uring_prep_nop128']
if not _register_works(lambda ring: io_uring_register_query(Query())):
    for step in (
        ('Query', 'io_uring_register_query(query)'),
        ('io_uring_register_query', 'io_uring_register_query(Query(IO_URING_QUERY_SCQ))'),
    ):
        SKIP[step] = 'needs `IORING_REGISTER_QUERY`, which this kernel lacks'
if not _register_works(_bpf_filter):
    SKIP[('Bpf', 'io_uring_register_bpf_filter(ring, bpf)')] = (
        'needs `IORING_REGISTER_BPF_FILTER`, which this kernel lacks'
    )
