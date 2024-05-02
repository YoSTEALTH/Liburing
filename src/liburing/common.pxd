from posix.unistd cimport _SC_IOV_MAX
from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .lib.uring cimport *
from .error cimport memory_error, index_error
from .queue cimport io_uring_sqe


cdef class iovec:
    cdef:
        __iovec *ptr
        list ref  # TODO: replace this with array() ?
        unsigned int len


cpdef void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil
cpdef void io_uring_prep_close_direct(io_uring_sqe sqe, unsigned int file_index) noexcept nogil

cpdef void io_uring_prep_provide_buffers(io_uring_sqe sqe,
                                         unsigned char[:] addr,
                                         int len,
                                         int nr,
                                         int bgid,
                                         int bid=?) noexcept nogil
cpdef void io_uring_prep_remove_buffers(io_uring_sqe sqe, int nr, int bgid) noexcept nogil


cpdef enum io_uring_msg_ring_flags:
    IORING_MSG_DATA = __IORING_MSG_DATA
    IORING_MSG_SEND_FD = __IORING_MSG_SEND_FD


cpdef enum io_wq_type:
    IO_WQ_BOUND = __IO_WQ_BOUND
    IO_WQ_UNBOUND = __IO_WQ_UNBOUND

cpdef enum io_uring_register_pbuf_ring_flags:
    IOU_PBUF_RING_MMAP = __IOU_PBUF_RING_MMAP

cpdef enum io_uring_restriction_op:
    IORING_RESTRICTION_REGISTER_OP = __IORING_RESTRICTION_REGISTER_OP
    IORING_RESTRICTION_SQE_OP = __IORING_RESTRICTION_SQE_OP
    IORING_RESTRICTION_SQE_FLAGS_ALLOWED = __IORING_RESTRICTION_SQE_FLAGS_ALLOWED
    IORING_RESTRICTION_SQE_FLAGS_REQUIRED = __IORING_RESTRICTION_SQE_FLAGS_REQUIRED
    IORING_RESTRICTION_LAST = __IORING_RESTRICTION_LAST

cpdef enum __common_define__:
    IORING_CQE_BUFFER_SHIFT = __IORING_CQE_BUFFER_SHIFT

    # openat, openat2, accept, ...
    IORING_FILE_INDEX_ALLOC = __IORING_FILE_INDEX_ALLOC

    # TODO: need to move bellow content to other files

    SC_IOV_MAX = _SC_IOV_MAX

    AT_FDCWD = __AT_FDCWD
    AT_SYMLINK_FOLLOW = __AT_SYMLINK_FOLLOW
    AT_SYMLINK_NOFOLLOW = __AT_SYMLINK_NOFOLLOW
    AT_REMOVEDIR = __AT_REMOVEDIR
    AT_NO_AUTOMOUNT = __AT_NO_AUTOMOUNT
    AT_EMPTY_PATH = __AT_EMPTY_PATH
    AT_RECURSIVE = __AT_RECURSIVE

    # fsync flags
    IORING_FSYNC_DATASYNC = __IORING_FSYNC_DATASYNC

    IORING_URING_CMD_FIXED = __IORING_URING_CMD_FIXED

    IORING_POLL_ADD_MULTI = __IORING_POLL_ADD_MULTI
    IORING_POLL_UPDATE_EVENTS = __IORING_POLL_UPDATE_EVENTS
    IORING_POLL_UPDATE_USER_DATA = __IORING_POLL_UPDATE_USER_DATA
    IORING_POLL_ADD_LEVEL = __IORING_POLL_ADD_LEVEL

    IORING_ASYNC_CANCEL_ALL = __IORING_ASYNC_CANCEL_ALL
    IORING_ASYNC_CANCEL_FD = __IORING_ASYNC_CANCEL_FD
    IORING_ASYNC_CANCEL_ANY = __IORING_ASYNC_CANCEL_ANY
    IORING_ASYNC_CANCEL_FD_FIXED = __IORING_ASYNC_CANCEL_FD_FIXED

    IORING_RECVSEND_POLL_FIRST = __IORING_RECVSEND_POLL_FIRST
    IORING_RECV_MULTISHOT = __IORING_RECV_MULTISHOT
    IORING_RECVSEND_FIXED_BUF = __IORING_RECVSEND_FIXED_BUF
    IORING_SEND_ZC_REPORT_USAGE = __IORING_SEND_ZC_REPORT_USAGE

    IORING_NOTIF_USAGE_ZC_COPIED = __IORING_NOTIF_USAGE_ZC_COPIED

    IORING_ACCEPT_MULTISHOT = __IORING_ACCEPT_MULTISHOT

    IORING_MSG_RING_CQE_SKIP = __IORING_MSG_RING_CQE_SKIP
    IORING_MSG_RING_FLAGS_PASS = __IORING_MSG_RING_FLAGS_PASS
    IORING_FIXED_FD_NO_CLOEXEC = __IORING_FIXED_FD_NO_CLOEXEC

    IORING_CQE_F_BUFFER = __IORING_CQE_F_BUFFER
    IORING_CQE_F_MORE = __IORING_CQE_F_MORE
    IORING_CQE_F_SOCK_NONEMPTY = __IORING_CQE_F_SOCK_NONEMPTY
    IORING_CQE_F_NOTIF = __IORING_CQE_F_NOTIF

    IORING_OFF_SQ_RING = __IORING_OFF_SQ_RING
    IORING_OFF_CQ_RING = __IORING_OFF_CQ_RING
    IORING_OFF_SQES = __IORING_OFF_SQES
    IORING_OFF_PBUF_RING = __IORING_OFF_PBUF_RING
    IORING_OFF_PBUF_SHIFT = __IORING_OFF_PBUF_SHIFT
    IORING_OFF_MMAP_MASK = __IORING_OFF_MMAP_MASK

    IORING_SQ_NEED_WAKEUP = __IORING_SQ_NEED_WAKEUP
    IORING_SQ_CQ_OVERFLOW = __IORING_SQ_CQ_OVERFLOW
    IORING_SQ_TASKRUN = __IORING_SQ_TASKRUN

    IORING_CQ_EVENTFD_DISABLED = __IORING_CQ_EVENTFD_DISABLED

    IORING_FEAT_SINGLE_MMAP = __IORING_FEAT_SINGLE_MMAP
    IORING_FEAT_NODROP = __IORING_FEAT_NODROP
    IORING_FEAT_SUBMIT_STABLE = __IORING_FEAT_SUBMIT_STABLE
    IORING_FEAT_RW_CUR_POS = __IORING_FEAT_RW_CUR_POS
    IORING_FEAT_CUR_PERSONALITY = __IORING_FEAT_CUR_PERSONALITY
    IORING_FEAT_FAST_POLL = __IORING_FEAT_FAST_POLL
    IORING_FEAT_POLL_32BITS = __IORING_FEAT_POLL_32BITS
    IORING_FEAT_SQPOLL_NONFIXED = __IORING_FEAT_SQPOLL_NONFIXED
    IORING_FEAT_EXT_ARG = __IORING_FEAT_EXT_ARG
    IORING_FEAT_NATIVE_WORKERS = __IORING_FEAT_NATIVE_WORKERS
    IORING_FEAT_RSRC_TAGS = __IORING_FEAT_RSRC_TAGS
    IORING_FEAT_CQE_SKIP = __IORING_FEAT_CQE_SKIP
    IORING_FEAT_LINKED_FILE = __IORING_FEAT_LINKED_FILE
    IORING_FEAT_REG_REG_RING = __IORING_FEAT_REG_REG_RING

    IORING_RSRC_REGISTER_SPARSE = __IORING_RSRC_REGISTER_SPARSE

    IORING_REGISTER_FILES_SKIP = __IORING_REGISTER_FILES_SKIP
    IO_URING_OP_SUPPORTED = __IO_URING_OP_SUPPORTED
