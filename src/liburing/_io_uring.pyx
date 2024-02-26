from cython cimport boundscheck
from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .error cimport memory_error, index_error


IORING_FILE_INDEX_ALLOC = __IORING_FILE_INDEX_ALLOC

# sqe.flags
IOSQE_FIXED_FILE = __IOSQE_FIXED_FILE
IOSQE_IO_DRAIN = __IOSQE_IO_DRAIN
IOSQE_IO_LINK = __IOSQE_IO_LINK
IOSQE_IO_HARDLINK = __IOSQE_IO_HARDLINK
IOSQE_ASYNC = __IOSQE_ASYNC
IOSQE_BUFFER_SELECT = __IOSQE_BUFFER_SELECT
IOSQE_CQE_SKIP_SUCCESS = __IOSQE_CQE_SKIP_SUCCESS

# io_uring_setup() flags
IORING_SETUP_IOPOLL = __IORING_SETUP_IOPOLL
IORING_SETUP_SQPOLL = __IORING_SETUP_SQPOLL
IORING_SETUP_SQ_AFF = __IORING_SETUP_SQ_AFF
IORING_SETUP_CQSIZE = __IORING_SETUP_CQSIZE
IORING_SETUP_CLAMP = __IORING_SETUP_CLAMP
IORING_SETUP_ATTACH_WQ = __IORING_SETUP_ATTACH_WQ
IORING_SETUP_R_DISABLED = __IORING_SETUP_R_DISABLED
IORING_SETUP_SUBMIT_ALL = __IORING_SETUP_SUBMIT_ALL

IORING_SETUP_COOP_TASKRUN = __IORING_SETUP_COOP_TASKRUN

IORING_SETUP_TASKRUN_FLAG = __IORING_SETUP_TASKRUN_FLAG
IORING_SETUP_SQE128 = __IORING_SETUP_SQE128
IORING_SETUP_CQE32 = __IORING_SETUP_CQE32

IORING_SETUP_SINGLE_ISSUER = __IORING_SETUP_SINGLE_ISSUER
IORING_SETUP_DEFER_TASKRUN = __IORING_SETUP_DEFER_TASKRUN
IORING_SETUP_NO_MMAP = __IORING_SETUP_NO_MMAP
IORING_SETUP_REGISTERED_FD_ONLY = __IORING_SETUP_REGISTERED_FD_ONLY
IORING_SETUP_NO_SQARRAY = __IORING_SETUP_NO_SQARRAY

cpdef enum io_uring_op:
    IORING_OP_NOP = __IORING_OP_NOP
    IORING_OP_READV = __IORING_OP_READV
    IORING_OP_WRITEV = __IORING_OP_WRITEV
    IORING_OP_FSYNC = __IORING_OP_FSYNC
    IORING_OP_READ_FIXED = __IORING_OP_READ_FIXED
    IORING_OP_WRITE_FIXED = __IORING_OP_WRITE_FIXED
    IORING_OP_POLL_ADD = __IORING_OP_POLL_ADD
    IORING_OP_POLL_REMOVE = __IORING_OP_POLL_REMOVE
    IORING_OP_SYNC_FILE_RANGE = __IORING_OP_SYNC_FILE_RANGE
    IORING_OP_SENDMSG = __IORING_OP_SENDMSG
    IORING_OP_RECVMSG = __IORING_OP_RECVMSG
    IORING_OP_TIMEOUT = __IORING_OP_TIMEOUT
    IORING_OP_TIMEOUT_REMOVE = __IORING_OP_TIMEOUT_REMOVE
    IORING_OP_ACCEPT = __IORING_OP_ACCEPT
    IORING_OP_ASYNC_CANCEL = __IORING_OP_ASYNC_CANCEL
    IORING_OP_LINK_TIMEOUT = __IORING_OP_LINK_TIMEOUT
    IORING_OP_CONNECT = __IORING_OP_CONNECT
    IORING_OP_FALLOCATE = __IORING_OP_FALLOCATE
    IORING_OP_OPENAT = __IORING_OP_OPENAT
    IORING_OP_CLOSE = __IORING_OP_CLOSE
    IORING_OP_FILES_UPDATE = __IORING_OP_FILES_UPDATE
    IORING_OP_STATX = __IORING_OP_STATX
    IORING_OP_READ = __IORING_OP_READ
    IORING_OP_WRITE = __IORING_OP_WRITE
    IORING_OP_FADVISE = __IORING_OP_FADVISE
    IORING_OP_MADVISE = __IORING_OP_MADVISE
    IORING_OP_SEND = __IORING_OP_SEND
    IORING_OP_RECV = __IORING_OP_RECV
    IORING_OP_OPENAT2 = __IORING_OP_OPENAT2
    IORING_OP_EPOLL_CTL = __IORING_OP_EPOLL_CTL
    IORING_OP_SPLICE = __IORING_OP_SPLICE
    IORING_OP_PROVIDE_BUFFERS = __IORING_OP_PROVIDE_BUFFERS
    IORING_OP_REMOVE_BUFFERS = __IORING_OP_REMOVE_BUFFERS
    IORING_OP_TEE = __IORING_OP_TEE
    IORING_OP_SHUTDOWN = __IORING_OP_SHUTDOWN
    IORING_OP_RENAMEAT = __IORING_OP_RENAMEAT
    IORING_OP_UNLINKAT = __IORING_OP_UNLINKAT
    IORING_OP_MKDIRAT = __IORING_OP_MKDIRAT
    IORING_OP_SYMLINKAT = __IORING_OP_SYMLINKAT
    IORING_OP_LINKAT = __IORING_OP_LINKAT
    IORING_OP_MSG_RING = __IORING_OP_MSG_RING
    IORING_OP_FSETXATTR = __IORING_OP_FSETXATTR
    IORING_OP_SETXATTR = __IORING_OP_SETXATTR
    IORING_OP_FGETXATTR = __IORING_OP_FGETXATTR
    IORING_OP_GETXATTR = __IORING_OP_GETXATTR
    IORING_OP_SOCKET = __IORING_OP_SOCKET
    IORING_OP_URING_CMD = __IORING_OP_URING_CMD
    IORING_OP_SEND_ZC = __IORING_OP_SEND_ZC
    IORING_OP_SENDMSG_ZC = __IORING_OP_SENDMSG_ZC
    IORING_OP_READ_MULTISHOT = __IORING_OP_READ_MULTISHOT
    IORING_OP_WAITID = __IORING_OP_WAITID
    IORING_OP_FUTEX_WAIT = __IORING_OP_FUTEX_WAIT
    IORING_OP_FUTEX_WAKE = __IORING_OP_FUTEX_WAKE
    IORING_OP_FUTEX_WAITV = __IORING_OP_FUTEX_WAITV
    IORING_OP_FIXED_FD_INSTALL = __IORING_OP_FIXED_FD_INSTALL
    IORING_OP_FTRUNCATE = __IORING_OP_FTRUNCATE
    # this goes last, obviously
    IORING_OP_LAST = __IORING_OP_LAST

IORING_URING_CMD_FIXED = __IORING_URING_CMD_FIXED
IORING_FSYNC_DATASYNC = __IORING_FSYNC_DATASYNC

IORING_TIMEOUT_ABS = __IORING_TIMEOUT_ABS
IORING_TIMEOUT_UPDATE = __IORING_TIMEOUT_UPDATE
IORING_TIMEOUT_BOOTTIME = __IORING_TIMEOUT_BOOTTIME
IORING_TIMEOUT_REALTIME = __IORING_TIMEOUT_REALTIME
IORING_LINK_TIMEOUT_UPDATE = __IORING_LINK_TIMEOUT_UPDATE
IORING_TIMEOUT_ETIME_SUCCESS = __IORING_TIMEOUT_ETIME_SUCCESS
IORING_TIMEOUT_MULTISHOT = __IORING_TIMEOUT_MULTISHOT
IORING_TIMEOUT_CLOCK_MASK = __IORING_TIMEOUT_CLOCK_MASK
IORING_TIMEOUT_UPDATE_MASK = __IORING_TIMEOUT_UPDATE_MASK

SPLICE_F_FD_IN_FIXED = __SPLICE_F_FD_IN_FIXED

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

cpdef enum io_uring_msg_op:
    IORING_MSG_DATA = __IORING_MSG_DATA
    IORING_MSG_SEND_FD = __IORING_MSG_SEND_FD

IORING_MSG_RING_CQE_SKIP = __IORING_MSG_RING_CQE_SKIP
IORING_MSG_RING_FLAGS_PASS = __IORING_MSG_RING_FLAGS_PASS
IORING_FIXED_FD_NO_CLOEXEC = __IORING_FIXED_FD_NO_CLOEXEC

IORING_CQE_F_BUFFER = __IORING_CQE_F_BUFFER
IORING_CQE_F_MORE = __IORING_CQE_F_MORE
IORING_CQE_F_SOCK_NONEMPTY = __IORING_CQE_F_SOCK_NONEMPTY
IORING_CQE_F_NOTIF = __IORING_CQE_F_NOTIF

cpdef enum io_uring_cqe_op:
    IORING_CQE_BUFFER_SHIFT = __IORING_CQE_BUFFER_SHIFT

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

IORING_ENTER_GETEVENTS = __IORING_ENTER_GETEVENTS
IORING_ENTER_SQ_WAKEUP = __IORING_ENTER_SQ_WAKEUP
IORING_ENTER_SQ_WAIT = __IORING_ENTER_SQ_WAIT
IORING_ENTER_EXT_ARG = __IORING_ENTER_EXT_ARG
IORING_ENTER_REGISTERED_RING = __IORING_ENTER_REGISTERED_RING

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

cpdef enum io_uring_register_op:
    IORING_REGISTER_BUFFERS = __IORING_REGISTER_BUFFERS
    IORING_UNREGISTER_BUFFERS = __IORING_UNREGISTER_BUFFERS
    IORING_REGISTER_FILES = __IORING_REGISTER_FILES
    IORING_UNREGISTER_FILES = __IORING_UNREGISTER_FILES
    IORING_REGISTER_EVENTFD = __IORING_REGISTER_EVENTFD
    IORING_UNREGISTER_EVENTFD = __IORING_UNREGISTER_EVENTFD
    IORING_REGISTER_FILES_UPDATE = __IORING_REGISTER_FILES_UPDATE
    IORING_REGISTER_EVENTFD_ASYNC = __IORING_REGISTER_EVENTFD_ASYNC
    IORING_REGISTER_PROBE = __IORING_REGISTER_PROBE
    IORING_REGISTER_PERSONALITY = __IORING_REGISTER_PERSONALITY
    IORING_UNREGISTER_PERSONALITY = __IORING_UNREGISTER_PERSONALITY
    IORING_REGISTER_RESTRICTIONS = __IORING_REGISTER_RESTRICTIONS
    IORING_REGISTER_ENABLE_RINGS = __IORING_REGISTER_ENABLE_RINGS
    IORING_REGISTER_FILES2 = __IORING_REGISTER_FILES2
    IORING_REGISTER_FILES_UPDATE2 = __IORING_REGISTER_FILES_UPDATE2
    IORING_REGISTER_BUFFERS2 = __IORING_REGISTER_BUFFERS2
    IORING_REGISTER_BUFFERS_UPDATE = __IORING_REGISTER_BUFFERS_UPDATE
    IORING_REGISTER_IOWQ_AFF = __IORING_REGISTER_IOWQ_AFF
    IORING_UNREGISTER_IOWQ_AFF = __IORING_UNREGISTER_IOWQ_AFF
    IORING_REGISTER_IOWQ_MAX_WORKERS = __IORING_REGISTER_IOWQ_MAX_WORKERS
    IORING_REGISTER_RING_FDS = __IORING_REGISTER_RING_FDS
    IORING_UNREGISTER_RING_FDS = __IORING_UNREGISTER_RING_FDS
    IORING_REGISTER_PBUF_RING = __IORING_REGISTER_PBUF_RING
    IORING_UNREGISTER_PBUF_RING = __IORING_UNREGISTER_PBUF_RING
    IORING_REGISTER_SYNC_CANCEL = __IORING_REGISTER_SYNC_CANCEL
    IORING_REGISTER_FILE_ALLOC_RANGE = __IORING_REGISTER_FILE_ALLOC_RANGE
    IORING_REGISTER_PBUF_STATUS = __IORING_REGISTER_PBUF_STATUS
    IORING_REGISTER_NAPI = __IORING_REGISTER_NAPI
    IORING_UNREGISTER_NAPI = __IORING_UNREGISTER_NAPI
    IORING_REGISTER_LAST = __IORING_REGISTER_LAST
    IORING_REGISTER_USE_REGISTERED_RING = __IORING_REGISTER_USE_REGISTERED_RING

cpdef enum io_uring_wq_op:
    IO_WQ_BOUND = __IO_WQ_BOUND
    IO_WQ_UNBOUND = __IO_WQ_UNBOUND

IORING_RSRC_REGISTER_SPARSE = __IORING_RSRC_REGISTER_SPARSE

IORING_REGISTER_FILES_SKIP = __IORING_REGISTER_FILES_SKIP
IO_URING_OP_SUPPORTED = __IO_URING_OP_SUPPORTED

cpdef enum io_uring_buf_op:
    IOU_PBUF_RING_MMAP = __IOU_PBUF_RING_MMAP

cpdef enum io_uring_restriction_op:
    IORING_RESTRICTION_REGISTER_OP = __IORING_RESTRICTION_REGISTER_OP
    IORING_RESTRICTION_SQE_OP = __IORING_RESTRICTION_SQE_OP
    IORING_RESTRICTION_SQE_FLAGS_ALLOWED = __IORING_RESTRICTION_SQE_FLAGS_ALLOWED
    IORING_RESTRICTION_SQE_FLAGS_REQUIRED = __IORING_RESTRICTION_SQE_FLAGS_REQUIRED
    IORING_RESTRICTION_LAST = __IORING_RESTRICTION_LAST

cpdef enum io_uring_socket_op:
    SOCKET_URING_OP_SIOCINQ = __SOCKET_URING_OP_SIOCINQ
    SOCKET_URING_OP_SIOCOUTQ = __SOCKET_URING_OP_SIOCOUTQ
    SOCKET_URING_OP_GETSOCKOPT = __SOCKET_URING_OP_GETSOCKOPT
    SOCKET_URING_OP_SETSOCKOPT = __SOCKET_URING_OP_SETSOCKOPT


cdef class io_uring:
    ''' I/O URing

        Example
            >>> ring = io_uring()
            >>> io_uring_queue_init(123, ring, 0)
            >>> io_uring_queue_exit(ring)
    '''
    def __cinit__(self):
        self.ptr = <__io_uring*>PyMem_RawCalloc(1, sizeof(__io_uring))
        if self.ptr is NULL:
            memory_error(self)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def flags(self):
        return self.ptr.flags

    @property
    def ring_fd(self):
        return self.ptr.ring_fd

    @property
    def features(self):
        return self.ptr.features

    @property
    def enter_ring_fd(self):
        return self.ptr.enter_ring_fd

    @property
    def int_flags(self):
        return self.ptr.int_flags

    def __repr__(self):
        return f'{self.__class__.__name__}(flags={self.ptr.flags!r}, ' \
               f'ring_fd={self.ptr.ring_fd!r}, features={self.ptr.features!r}, ' \
               f'enter_ring_fd={self.ptr.enter_ring_fd!r}, int_flags={self.ptr.int_flags!r}) '


cdef class io_uring_sqe:
    ''' IO submission data structure (Submission Queue Entry)

        Example
            # single
            >>> sqe = io_uring_sqe()
            >>> io_uring_prep_read(sqe, ...)

            # multiple
            >>> sqe = io_uring_sqe(2)
            >>> io_uring_prep_write(sqe[0], ...)
            >>> io_uring_prep_read(sqe[1], ...)

            # *** MUST DO ***
            >>> if io_uring_put_sqe(ring, sqe):
            ...     io_uring_submit(ring)

        Note
            - `io_uring_sqe` is not the same as `io_uring_get_sqe()`.
            - This class has multiple uses:
                1. It works as a base class for `io_uring_get_sqe()` return.
                2. It can also be used as `sqe = io_uring_sqe(<int>)`, rather than "get" sqe(s)
                you are going to "put" pre-made sqe(s) into the ring later.
            - Refer to `help(io_uring_put_sqe)` to see more detail.
    '''
    def __cinit__(self, unsigned int num=1):
        cdef str error
        if num:
            self.ptr = <__io_uring_sqe*>PyMem_RawCalloc(num, sizeof(__io_uring_sqe))
            if self.ptr is NULL:
                memory_error(self)
            if num > 1:
                self.ref = [None]*(num-1)  # do not hold `0` reference.
        else:
            self.ptr = NULL
        self.len = num
        # note: if `self.len` is not set it means its for internally `ptr` reference use.

    def __dealloc__(self):
        if self.len and self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __bool__(self):
        return self.ptr is not NULL

    def __len__(self):
        return self.len
        
    @boundscheck(True)
    def __getitem__(self, unsigned int index):
        cdef io_uring_sqe sqe
        if self.ptr is not NULL:
            if index == 0:
                return self
            elif self.len and index < self.len:
                if (sqe := self.ref[index-1]) is not None:
                    return sqe  # from reference cache

                # create new reference class
                sqe = io_uring_sqe(0)  # `0` is set to indicated `ptr` is being set for internal use
                sqe.ptr = &self.ptr[index]
                if sqe.ptr is not NULL:
                    # cache sqe as this class attribute
                    self.ref[index-1] = sqe
                    return sqe
                
        index_error(self, index, 'out of `sqe`')

    @property
    def flags(self) -> __u8:
        return self.ptr.flags

    @flags.setter
    def flags(self, __u8 flags):
        __io_uring_sqe_set_flags(self.ptr, flags)

    @property
    def user_data(self) -> __u64:
        return self.ptr.user_data

    @user_data.setter
    def user_data(self, __u64 data):
        __io_uring_sqe_set_data64(self.ptr, data)


cdef class io_uring_cqe:
    ''' IO completion data structure (Completion Queue Entry)

        Example
            >>> cqes = io_uring_cqe()

            # single
            # ------
            >>> cqe = cqes  # same as `cqes[0]`
            >>> cqe.res
            0
            >>> cqe.flags
            0
            >>> cqe.user_data
            123

            # get item
            # --------
            >>> cqes[0].user_data
            123

            # iter
            # ----
            >>> ready = io_uring_cq_ready(ring)
            >>> for i in range(ready):
            ...     cqe = cqes[i]
            ...     cqe.user_data
            ...     io_uring_cq_advance(ring, 1)
            123

        Note
            - `cqes = io_uring_cqe()` only needs to be defined once, and reused.
            - Use `io_uring_cq_ready(ring)` to figure out how many cqe's are ready.
    '''
    @boundscheck(True)
    def __getitem__(self, unsigned int index):
        cdef io_uring_cqe cqe
        if self.ptr is NULL:
            index_error(self, index, 'out of `cqe`')
        if index:
            cqe = io_uring_cqe()
            cqe.ptr = &self.ptr[index]
            if cqe.ptr is not NULL:
                return cqe
            index_error(self, index, 'out of `cqe`')
        return self
        # note: no need to cache items since `cqe` is normally called once or passed around.

    def __bool__(self):
        return self.ptr is not NULL

    def __repr__(self):
        if self.ptr is not NULL:
            return f'{self.__class__.__name__}(user_data={self.ptr.user_data!r}, ' \
                   f'res={self.ptr.res!r}, flags={self.ptr.flags!r})'
        memory_error(self, 'out of `cqe`')

    @property
    def user_data(self) -> __u64:
        if self.ptr is not NULL:
            return self.ptr.user_data
        memory_error(self, 'out of `cqe`')

    @property
    def res(self) -> __s32:
        if self.ptr is not NULL:
            return self.ptr.res
        memory_error(self, 'out of `cqe`')

    @property
    def flags(self) -> __u32:
        if self.ptr is not NULL:
            return self.ptr.flags
        memory_error(self, 'out of `cqe`')
