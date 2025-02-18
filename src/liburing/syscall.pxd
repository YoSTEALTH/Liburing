from .lib.uring cimport *
from .error cimport trap_error
from .queue cimport sigset, io_uring_params


#  `io_uring` syscalls.
cpdef int io_uring_enter(unsigned int fd,
                         unsigned int to_submit,
                         unsigned int min_complete,
                         unsigned int flags,
                         sigset sig) nogil
cpdef int io_uring_enter2(unsigned int fd,
                          unsigned int to_submit,
                          unsigned int min_complete,
                          unsigned int flags,
                          sigset sig,
                          size_t sz) nogil
cpdef int io_uring_setup(unsigned int entries, io_uring_params p) nogil
cpdef int io_uring_register(unsigned int fd,
                            unsigned int opcode,
                            const unsigned char[:] arg,
                            unsigned int nr_args) nogil


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
    IORING_OP_BIND =  __IORING_OP_BIND
    IORING_OP_LISTEN =  __IORING_OP_LISTEN
    # this goes last, obviously
    IORING_OP_LAST = __IORING_OP_LAST

#  `io_uring` register, used by `io_uring_register()`.
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
    IORING_REGISTER_CLOCK = __IORING_REGISTER_CLOCK
    IORING_REGISTER_CLONE_BUFFERS = __IORING_REGISTER_CLONE_BUFFERS
    IORING_REGISTER_RESIZE_RINGS = __IORING_REGISTER_RESIZE_RINGS
    IORING_REGISTER_MEM_REGION = __IORING_REGISTER_MEM_REGION
    IORING_REGISTER_LAST = __IORING_REGISTER_LAST
    IORING_REGISTER_USE_REGISTERED_RING = __IORING_REGISTER_USE_REGISTERED_RING


cpdef enum __syscall_define__:
    # io_uring_enter(2) flags
    IORING_ENTER_GETEVENTS = __IORING_ENTER_GETEVENTS
    IORING_ENTER_SQ_WAKEUP = __IORING_ENTER_SQ_WAKEUP
    IORING_ENTER_SQ_WAIT = __IORING_ENTER_SQ_WAIT
    IORING_ENTER_EXT_ARG = __IORING_ENTER_EXT_ARG
    IORING_ENTER_REGISTERED_RING = __IORING_ENTER_REGISTERED_RING
    IORING_ENTER_ABS_TIMER = __IORING_ENTER_ABS_TIMER
    IORING_ENTER_EXT_ARG_REG = __IORING_ENTER_EXT_ARG_REG

    # `io_uring_setup()` flags
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
    IORING_SETUP_HYBRID_IOPOLL = __IORING_SETUP_HYBRID_IOPOLL
