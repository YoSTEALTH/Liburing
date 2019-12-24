import enum
import ctypes


# sqe->flags
# ----------
IOSQE_FIXED_FILE = 1 << 0   # use fixed fileset
IOSQE_IO_DRAIN = 1 << 1     # issue after inflight IO
IOSQE_IO_LINK = 1 << 2      # links next sqe
IOSQE_IO_HARDLINK = 1 << 3  # like LINK, but stronger
IOSQE_ASYNC = 1 << 4        # always go async

# io_uring_setup() flags
# ----------------------
IORING_SETUP_IOPOLL = 1 << 0   # io_context is polled
IORING_SETUP_SQPOLL = 1 << 1   # SQ poll thread
IORING_SETUP_SQ_AFF = 1 << 2   # sq_thread_cpu is valid
IORING_SETUP_CQSIZE = 1 << 3   # app defines CQ size

# sqe->fsync_flags
# ----------------
IORING_FSYNC_DATASYNC = 1 << 0

# sqe->timeout_flags
# ------------------
IORING_TIMEOUT_ABS = 1 << 0

# Magic offsets for the application to mmap the data it needs
# -----------------------------------------------------------
IORING_OFF_SQ_RING = 0          # 0ULL
IORING_OFF_CQ_RING = 0x8000000  # 0x8000000ULL
IORING_OFF_SQES = 0x10000000    # 0x10000000ULL

# sq_ring->flags
# --------------
IORING_SQ_NEED_WAKEUP = 1 << 0  # needs `io_uring_enter` wakeup

# io_uring_enter(2) flags
# -----------------------
IORING_ENTER_GETEVENTS = 1 << 0
IORING_ENTER_SQ_WAKEUP = 1 << 1

# io_uring_params->features flags
# -------------------------------
IORING_FEAT_SINGLE_MMAP = 1 << 0
IORING_FEAT_NODROP = 1 << 1
IORING_FEAT_SUBMIT_STABLE = 1 << 2

# io_uring_register(2) opcodes and arguments
# ------------------------------------------
IORING_REGISTER_BUFFERS = 0
IORING_UNREGISTER_BUFFERS = 1
IORING_REGISTER_FILES = 2
IORING_UNREGISTER_FILES = 3
IORING_REGISTER_EVENTFD = 4
IORING_UNREGISTER_EVENTFD = 5
IORING_REGISTER_FILES_UPDATE = 6


class OP(enum.IntEnum):
    IORING_OP_NOP = enum.auto()
    IORING_OP_READV = enum.auto()
    IORING_OP_WRITEV = enum.auto()
    IORING_OP_FSYNC = enum.auto()
    IORING_OP_READ_FIXED = enum.auto()
    IORING_OP_WRITE_FIXED = enum.auto()
    IORING_OP_POLL_ADD = enum.auto()
    IORING_OP_POLL_REMOVE = enum.auto()
    IORING_OP_SYNC_FILE_RANGE = enum.auto()
    IORING_OP_SENDMSG = enum.auto()
    IORING_OP_RECVMSG = enum.auto()
    IORING_OP_TIMEOUT = enum.auto()
    IORING_OP_TIMEOUT_REMOVE = enum.auto()
    IORING_OP_ACCEPT = enum.auto()
    IORING_OP_ASYNC_CANCEL = enum.auto()
    IORING_OP_LINK_TIMEOUT = enum.auto()
    IORING_OP_CONNECT = enum.auto()
    IORING_OP_FALLOCATE = enum.auto()
    IORING_OP_OPENAT = enum.auto()
    IORING_OP_CLOSE = enum.auto()
    IORING_OP_FILES_UPDATE = enum.auto()
    IORING_OP_STATX = enum.auto()

    # this goes last = , obviously
    IORING_OP_LAST = enum.auto()


globals().update(OP.__members__)


# Internally used
# ---------------
class _union_one(ctypes.Union):
    _fields_ = [('off',   ctypes.c_uint64),  # __u64 - offset into file
                ('addr2', ctypes.c_uint64)]  # __u64


class _union_two(ctypes.Union):
    _fields_ = [('rw_flags',         ctypes.c_int),     # typedef int __kernel_rwf_t
                ('fsync_flags',      ctypes.c_uint32),  # __u32
                ('poll_events',      ctypes.c_uint16),  # __u16
                ('sync_range_flags', ctypes.c_uint32),  # __u32
                ('msg_flags',        ctypes.c_uint32),  # __u32
                ('timeout_flags',    ctypes.c_uint32),  # __u32
                ('accept_flags',     ctypes.c_uint32),  # __u32
                ('cancel_flags',     ctypes.c_uint32),  # __u32
                ('open_flags',       ctypes.c_uint32),  # __u32
                ('statx_flags',      ctypes.c_uint32)]  # __u32


class _union_three(ctypes.Union):
    _fields_ = [('buf_index', ctypes.c_uint16),      # __u16 - index into fixed buffers, if used
                ('__pad2',    ctypes.c_uint64 * 3)]  # __u64  __pad2[3]


# IO submission data structure (Submission Queue Entry)
# -----------------------------------------------------
class io_uring_sqe(ctypes.Structure):
    _anonymous_ = ('_union_one', '_union_two', '_union_three')
    _fileds_ = [
        ('opcode',        ctypes.c_uint8),   # __u8  - type of operation for this sqe
        ('flags',         ctypes.c_uint8),   # __u8  - IOSQE_ flags
        ('ioprio',        ctypes.c_uint16),  # __u16 - ioprio for the request
        ('fd',            ctypes.c_int32),   # __s32 - file descriptor to do IO on
        ('_union_one',    _union_one),       # union
        ('addr',          ctypes.c_uint64),  # __u64 - pointer to buffer or iovecs
        ('len',           ctypes.c_uint32),  # __u32 - buffer size or number of iovecs
        ('_union_two',    _union_two),       # union
        ('user_data',     ctypes.c_uint64),  # __u64 - data to be passed back at completion time
        ('_union_three',  _union_three)      # union
    ]


# IO completion data structure (Completion Queue Entry)
# -----------------------------------------------------
class io_uring_cqe(ctypes.Structure):
    _fileds_ = [('user_data',   ctypes.c_uint64),  # __u64  - sqe->data submission passed back
                ('res',         ctypes.c_int32),   # __s32  - result code for this event
                ('flags',       ctypes.c_uint32)]  # __u32


# Filled with the offset for mmap(2)
# ----------------------------------
class io_sqring_offsets(ctypes.Structure):
    _fileds_ = [('head',         ctypes.c_uint32),  # __u32
                ('tail',         ctypes.c_uint32),  # __u32
                ('ring_mask',    ctypes.c_uint32),  # __u32
                ('ring_entries', ctypes.c_uint32),  # __u32
                ('flags',        ctypes.c_uint32),  # __u32
                ('dropped',      ctypes.c_uint32),  # __u32
                ('array',        ctypes.c_uint32),  # __u32
                ('resv1',        ctypes.c_uint32),  # __u32
                ('resv2',        ctypes.c_uint64)]  # __u64


class io_cqring_offsets(ctypes.Structure):
    _fileds_ = [('head',         ctypes.c_uint32),     # __u32
                ('tail',         ctypes.c_uint32),     # __u32
                ('ring_mask',    ctypes.c_uint32),     # __u32
                ('ring_entries', ctypes.c_uint32),     # __u32
                ('overflow',     ctypes.c_uint32),     # __u32
                ('cqes',         ctypes.c_uint32),     # __u32
                ('resv',         ctypes.c_uint64 * 2)]  # __u64 resv[2]


# Passed in for io_uring_setup(2). Copied back with updated info on success
# -------------------------------------------------------------------------
class io_uring_params(ctypes.Structure):
    _fileds_ = [('sq_entries',      ctypes.c_uint32),      # __u32
                ('cq_entries',      ctypes.c_uint32),      # __u32
                ('flags',           ctypes.c_uint32),      # __u32
                ('sq_thread_cpu',   ctypes.c_uint32),      # __u32
                ('sq_thread_idle',  ctypes.c_uint32),      # __u32
                ('features',        ctypes.c_uint32),      # __u32
                ('resv',            ctypes.c_uint32 * 4),  # __u32 resv[4]
                ('sq_off',          io_sqring_offsets),    # struct io_sqring_offsets
                ('cq_off',          io_cqring_offsets)]    # struct io_cqring_offsets


class io_uring_files_update(ctypes.Structure):
    _fileds_ = [('offset', ctypes.c_uint32),                 # __u32
                ('fds',    ctypes.POINTER(ctypes.c_int32))]  # __s32 *
