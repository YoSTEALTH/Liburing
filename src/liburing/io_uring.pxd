# distutils: language=c
from .type cimport *


cdef extern from 'liburing.h' nogil:
    # IO submission data structure (Submission Queue Entry)
    struct io_uring_sqe_t "io_uring_sqe":
        pass    

    cpdef enum:
        # If `sqe->file_index` is set to this for opcodes that instantiate a new
        # direct descriptor (like openat/openat2/accept), then `io_uring` will allocate
        # an available direct descriptor instead of having the application pass one
        # in. The picked direct descriptor will be returned in `cqe->res`, or `-ENFILE`
        # if the space is full.
        IORING_FILE_INDEX_ALLOC 

        # NOTE: Do NOT need this, its for internal `liburing` use
        # IOSQE_FIXED_FILE_BIT
        # IOSQE_IO_DRAIN_BIT
        # IOSQE_IO_LINK_BIT
        # IOSQE_IO_HARDLINK_BIT
        # IOSQE_ASYNC_BIT
        # IOSQE_BUFFER_SELECT_BIT
        # IOSQE_CQE_SKIP_SUCCESS_BIT

        # sqe.flags
        IOSQE_FIXED_FILE           # use fixed fileset
        IOSQE_IO_DRAIN             # issue after inflight IO
        IOSQE_IO_LINK              # links next sqe
        IOSQE_IO_HARDLINK          # like LINK, but stronger
        IOSQE_ASYNC                # always go async
        IOSQE_BUFFER_SELECT        # select buffer from sqe->buf_group
        IOSQE_CQE_SKIP_SUCCESS     # don't post CQE if request succeeded

        # io_uring_setup() flags
        IORING_SETUP_IOPOLL        # io_context is polled
        IORING_SETUP_SQPOLL        # SQ poll thread
        IORING_SETUP_SQ_AFF        # sq_thread_cpu is valid
        IORING_SETUP_CQSIZE        # app defines CQ size
        IORING_SETUP_CLAMP         # clamp SQ/CQ ring sizes
        IORING_SETUP_ATTACH_WQ     # attach to existing wq
        IORING_SETUP_R_DISABLED    # start with ring disabled
        IORING_SETUP_SUBMIT_ALL    # continue submit on error

        # Cooperative task running. When requests complete, they often require
        # forcing the submitter to transition to the kernel to complete. If this
        # flag is set, work will be done when the task transitions anyway, rather
        # than force an inter-processor interrupt reschedule. This avoids interrupting
        # a task running in userspace, and saves an IPI.
        IORING_SETUP_COOP_TASKRUN

        # If COOP_TASKRUN is set, get notified if task work is available for
        # running and a kernel transition would be needed to run it. This sets
        # IORING_SQ_TASKRUN in the sq ring flags. Not valid with COOP_TASKRUN.
        IORING_SETUP_TASKRUN_FLAG
        IORING_SETUP_SQE128         # SQEs are 128 byte
        IORING_SETUP_CQE32          # CQEs are 32 byte

        # Only one task is allowed to submit requests
        IORING_SETUP_SINGLE_ISSUER

        # Defer running task work to get events.
        # Rather than running bits of task work whenever the task transitions
        # try to do it just before it is needed.
        IORING_SETUP_DEFER_TASKRUN

        # Application provides ring memory
        IORING_SETUP_NO_MMAP

        # Register the ring fd in itself for use with
        # IORING_REGISTER_USE_REGISTERED_RING; return a registered fd index rather
        # than an fd.
        IORING_SETUP_REGISTERED_FD_ONLY

        # Removes indirection through the SQ index array.
        IORING_SETUP_NO_SQARRAY

    cpdef enum io_uring_op:
        IORING_OP_NOP
        IORING_OP_READV
        IORING_OP_WRITEV
        IORING_OP_FSYNC
        IORING_OP_READ_FIXED
        IORING_OP_WRITE_FIXED
        IORING_OP_POLL_ADD
        IORING_OP_POLL_REMOVE
        IORING_OP_SYNC_FILE_RANGE
        IORING_OP_SENDMSG
        IORING_OP_RECVMSG
        IORING_OP_TIMEOUT
        IORING_OP_TIMEOUT_REMOVE
        IORING_OP_ACCEPT
        IORING_OP_ASYNC_CANCEL
        IORING_OP_LINK_TIMEOUT
        IORING_OP_CONNECT
        IORING_OP_FALLOCATE
        IORING_OP_OPENAT
        IORING_OP_CLOSE
        IORING_OP_FILES_UPDATE
        IORING_OP_STATX
        IORING_OP_READ
        IORING_OP_WRITE
        IORING_OP_FADVISE
        IORING_OP_MADVISE
        IORING_OP_SEND
        IORING_OP_RECV
        IORING_OP_OPENAT2
        IORING_OP_EPOLL_CTL
        IORING_OP_SPLICE
        IORING_OP_PROVIDE_BUFFERS
        IORING_OP_REMOVE_BUFFERS
        IORING_OP_TEE
        IORING_OP_SHUTDOWN
        IORING_OP_RENAMEAT
        IORING_OP_UNLINKAT
        IORING_OP_MKDIRAT
        IORING_OP_SYMLINKAT
        IORING_OP_LINKAT
        IORING_OP_MSG_RING
        IORING_OP_FSETXATTR
        IORING_OP_SETXATTR
        IORING_OP_FGETXATTR
        IORING_OP_GETXATTR
        IORING_OP_SOCKET
        IORING_OP_URING_CMD
        IORING_OP_SEND_ZC
        IORING_OP_SENDMSG_ZC
        IORING_OP_READ_MULTISHOT
        IORING_OP_WAITID
        IORING_OP_FUTEX_WAIT
        IORING_OP_FUTEX_WAKE
        IORING_OP_FUTEX_WAITV
        IORING_OP_FIXED_FD_INSTALL
        # this goes last, obviously
        IORING_OP_LAST

    cpdef enum:
        # `sqe->uring_cmd_flags`
        # `IORING_URING_CMD_FIXED` use registered buffer;
        # pass this flag along with setting `sqe->buf_index`.
        IORING_URING_CMD_FIXED

        # `sqe->fsync_flags`
        IORING_FSYNC_DATASYNC

        # `sqe->timeout_flags`
        IORING_TIMEOUT_ABS
        IORING_TIMEOUT_UPDATE
        IORING_TIMEOUT_BOOTTIME
        IORING_TIMEOUT_REALTIME
        IORING_LINK_TIMEOUT_UPDATE
        IORING_TIMEOUT_ETIME_SUCCESS
        IORING_TIMEOUT_MULTISHOT
        IORING_TIMEOUT_CLOCK_MASK
        IORING_TIMEOUT_UPDATE_MASK

        # `sqe->splice_flags`
        # extends splice(2) flags
        SPLICE_F_FD_IN_FIXED
 
        # POLL_ADD flags. Note that since `sqe->poll_events` is the flag space, the
        # command flags for POLL_ADD are stored in `sqe->len`.
        #
        # `IORING_POLL_ADD_MULTI`   Multishot poll. Sets `IORING_CQE_F_MORE` if
        #                           the poll handler will continue to report
        #                           CQEs on behalf of the same SQE.
        #
        # `IORING_POLL_UPDATE`      Update existing poll request, matching
        #                           `sqe->addr` as the old `user_data` field.
        #
        # `IORING_POLL_ADD_LEVEL`   Level triggered poll.
        IORING_POLL_ADD_MULTI
        IORING_POLL_UPDATE_EVENTS
        IORING_POLL_UPDATE_USER_DATA
        IORING_POLL_ADD_LEVEL

        # ASYNC_CANCEL flags.
        IORING_ASYNC_CANCEL_ALL       # Cancel all requests that match the given key
        IORING_ASYNC_CANCEL_FD        # Key off `fd` for cancelation rather than the request `user_data`
        IORING_ASYNC_CANCEL_ANY       # Match any request
        IORING_ASYNC_CANCEL_FD_FIXED  # 'fd' passed in is a fixed descriptor

        # send/sendmsg and recv/recvmsg flags (sqe->ioprio)
        #
        # `IORING_RECVSEND_POLL_FIRST`  If set, instead of first attempting to send
        #                               or receive and arm poll if that yields an
        #                               `-EAGAIN` result, arm poll upfront and skip
        #                               the initial transfer attempt.
        #
        # `IORING_RECV_MULTISHOT`       Multishot recv. Sets `IORING_CQE_F_MORE` if
        #                               the handler will continue to report
        #                               CQEs on behalf of the same SQE.
        #
        # `IORING_RECVSEND_FIXED_BUF`   Use registered buffers,
        #                               the index is stored in the buf_index field.
        #
        # `IORING_SEND_ZC_REPORT_USAGE` If set, SEND[MSG]_ZC should report
        #                               the zerocopy usage in cqe.res
        #                               for the `IORING_CQE_F_NOTIF` cqe.
        #                               `0` is reported if zerocopy was actually possible.
        #                               `IORING_NOTIF_USAGE_ZC_COPIED` if data was copied
        #                               (at least partially).
        IORING_RECVSEND_POLL_FIRST
        IORING_RECV_MULTISHOT
        IORING_RECVSEND_FIXED_BUF
        IORING_SEND_ZC_REPORT_USAGE

        # `cqe.res` for `IORING_CQE_F_NOTIF` if
        # `IORING_SEND_ZC_REPORT_USAGE` was requested
        #
        # It should be treated as a flag, all other
        # bits of `cqe.res` should be treated as reserved!
        IORING_NOTIF_USAGE_ZC_COPIED

        # accept flags stored in `sqe->ioprio`
        IORING_ACCEPT_MULTISHOT

        # IORING_OP_MSG_RING command types, stored in sqe->addr
        # enum:
        IORING_MSG_DATA    # pass `sqe->len` as `res` and `off` as `user_data`
        IORING_MSG_SEND_FD # send a registered `fd` to another ring

        # `IORING_OP_MSG_RING` flags (`sqe->msg_ring_flags`)
        #
        # `IORING_MSG_RING_CQE_SKIP`    Don't post a CQE to the target ring. Not
        #                               applicable for `IORING_MSG_DATA`, obviously.
        IORING_MSG_RING_CQE_SKIP
        # Pass through the flags from `sqe->file_index` to `cqe->flags`
        IORING_MSG_RING_FLAGS_PASS

        # `IORING_OP_FIXED_FD_INSTALL` flags (`sqe->install_fd_flags`)
        #
        # `IORING_FIXED_FD_NO_CLOEXEC`   Don't mark the `fd` as `O_CLOEXEC`
        IORING_FIXED_FD_NO_CLOEXEC

    # IO completion data structure (Completion Queue Entry)
    struct io_uring_cqe_t "io_uring_cqe":
        __u64   user_data  # `sqe->data` submission passed back
        __s32   res        # result code for this event
        __u32   flags
        # If the ring is initialized with `IORING_SETUP_CQE32`, then this field
        # contains 16-bytes of padding, doubling the size of the CQE.
        __u64   big_cqe[]
        # __u64   big_cqe[16] ???

    cpdef enum:
        # cqe->flags
        IORING_CQE_F_BUFFER         # If set, the upper 16 bits are the buffer ID
        IORING_CQE_F_MORE           # If set, parent SQE will generate more CQE entries
        IORING_CQE_F_SOCK_NONEMPTY  # If set, more data to read after socket recv
        IORING_CQE_F_NOTIF          # Set for notification CQEs. Can be used to distinct
                                    # them from sends.
        # enum:
        IORING_CQE_BUFFER_SHIFT
        # Magic offsets for the application to mmap the data it needs
        IORING_OFF_SQ_RING
        IORING_OFF_CQ_RING
        IORING_OFF_SQES
        IORING_OFF_PBUF_RING
        IORING_OFF_PBUF_SHIFT
        IORING_OFF_MMAP_MASK

    # Filled with the offset for mmap(2)
    struct io_sqring_offsets_t "io_sqring_offsets":
        __u32 head
        __u32 tail
        __u32 ring_mask
        __u32 ring_entries
        __u32 flags
        __u32 dropped
        __u32 array
        __u32 resv1
        __u64 user_addr

    # sq_ring->flags
    cpdef enum:
        IORING_SQ_NEED_WAKEUP   # needs io_uring_enter wakeup
        IORING_SQ_CQ_OVERFLOW   # CQ ring is overflown
        IORING_SQ_TASKRUN       # task should enter the kernel

    struct io_cqring_offsets_t "io_cqring_offsets":
        __u32 head
        __u32 tail
        __u32 ring_mask
        __u32 ring_entries
        __u32 overflow
        __u32 cqes
        __u32 flags
        __u32 resv1
        __u64 user_addr

    # cq_ring->flags
    cpdef enum:
        # disable eventfd notifications
        IORING_CQ_EVENTFD_DISABLED

        # io_uring_enter(2) flags
        IORING_ENTER_GETEVENTS
        IORING_ENTER_SQ_WAKEUP
        IORING_ENTER_SQ_WAIT
        IORING_ENTER_EXT_ARG
        IORING_ENTER_REGISTERED_RING

    # Passed in for io_uring_setup(2). Copied back with updated info on success
    struct io_uring_params_t "io_uring_params":
        __u32   sq_entries
        __u32   cq_entries
        __u32   flags
        __u32   sq_thread_cpu
        __u32   sq_thread_idle
        __u32   features
        __u32   wq_fd
        __u32   resv[3]
        io_sqring_offsets_t   sq_off
        io_cqring_offsets_t   cq_off

    cpdef enum:
        # io_uring_params->features flags
        IORING_FEAT_SINGLE_MMAP
        IORING_FEAT_NODROP
        IORING_FEAT_SUBMIT_STABLE
        IORING_FEAT_RW_CUR_POS
        IORING_FEAT_CUR_PERSONALITY
        IORING_FEAT_FAST_POLL
        IORING_FEAT_POLL_32BITS
        IORING_FEAT_SQPOLL_NONFIXED
        IORING_FEAT_EXT_ARG
        IORING_FEAT_NATIVE_WORKERS
        IORING_FEAT_RSRC_TAGS
        IORING_FEAT_CQE_SKIP
        IORING_FEAT_LINKED_FILE
        IORING_FEAT_REG_REG_RING

        # enum:
        # io_uring_register(2) opcodes and arguments
        IORING_REGISTER_BUFFERS
        IORING_UNREGISTER_BUFFERS
        IORING_REGISTER_FILES
        IORING_UNREGISTER_FILES
        IORING_REGISTER_EVENTFD
        IORING_UNREGISTER_EVENTFD
        IORING_REGISTER_FILES_UPDATE
        IORING_REGISTER_EVENTFD_ASYNC
        IORING_REGISTER_PROBE
        IORING_REGISTER_PERSONALITY
        IORING_UNREGISTER_PERSONALITY
        IORING_REGISTER_RESTRICTIONS
        IORING_REGISTER_ENABLE_RINGS

        # extended with tagging
        IORING_REGISTER_FILES2
        IORING_REGISTER_FILES_UPDATE2
        IORING_REGISTER_BUFFERS2
        IORING_REGISTER_BUFFERS_UPDATE

        # set/clear io-wq thread affinities
        IORING_REGISTER_IOWQ_AFF
        IORING_UNREGISTER_IOWQ_AFF

        # set/get max number of io-wq workers
        IORING_REGISTER_IOWQ_MAX_WORKERS

        # register ring based provide buffer group
        IORING_REGISTER_PBUF_RING
        IORING_UNREGISTER_PBUF_RING

        # sync cancelation API
        IORING_REGISTER_SYNC_CANCEL

        # register a range of fixed file slots for automatic slot allocation
        IORING_REGISTER_FILE_ALLOC_RANGE

        # this goes last
        IORING_REGISTER_LAST

        # flag added to the opcode to use a registered ring fd
        IORING_REGISTER_USE_REGISTERED_RING

        # enum:
        # io-wq worker categories
        IO_WQ_BOUND
        IO_WQ_UNBOUND

        # NOTE: skipping `io_uring_files_update` deprecated

        # Register a fully sparse file space, rather than pass in an array of all
        # `-1` file descriptors.
        IORING_RSRC_REGISTER_SPARSE

    struct io_uring_rsrc_register_t "io_uring_rsrc_register":
        __u32           nr
        __u32           flags
        __u64           resv2
        __aligned_u64   data
        __aligned_u64   tags

    struct io_uring_rsrc_update_t "io_uring_rsrc_update":
        __u32           offset
        __u32           resv
        __aligned_u64   data

    struct io_uring_rsrc_update2_t "io_uring_rsrc_update2":
        __u32           offset
        __u32           resv
        __aligned_u64   data
        __aligned_u64   tags
        __u32           nr
        __u32           resv2

    cpdef enum:
        # Skip updating fd indexes set to this value in the fd table
        IORING_REGISTER_FILES_SKIP

        IO_URING_OP_SUPPORTED

    struct io_uring_probe_op_t "io_uring_probe_op":
        __u8    op
        __u8    resv
        __u16   flags   # IO_URING_OP_* flags
        __u32   resv2

    struct io_uring_probe_t "io_uring_probe":
        __u8    last_op   # last opcode supported
        __u8    ops_len   # length of ops[] array below
        __u16   resv
        __u32   resv2[3]
        io_uring_probe_op_t   ops[]

    struct io_uring_restriction_t "io_uring_restriction":
        pass # TODO:
        # __u16   opcode
        # union:
        #     __u8    register_op     # IORING_RESTRICTION_REGISTER_OP
        #     __u8    sqe_op          # IORING_RESTRICTION_SQE_OP
        #     __u8    sqe_flags       # IORING_RESTRICTION_SQE_FLAGS_*
        # __u8    resv
        # __u32   resv2[3]

    struct io_uring_buf_t "io_uring_buf":
        __u64   addr
        __u32   len
        __u16   bid
        __u16   resv

    struct io_uring_buf_ring_t "io_uring_buf_ring":
        pass # TODO:
        # union:
        #     # To avoid spilling into more pages than we need to, the
        #     # ring tail is overlaid with the `io_uring_buf->resv` field.
        #     struct:
        #         __u64   resv1
        #         __u32   resv2
        #         __u16   resv3
        #         __u16   tail
        #     struct io_uring_buf bufs[0]

    # Flags for `IORING_REGISTER_PBUF_RING`.
    #
    # `IOU_PBUF_RING_MMAP`:     If set, kernel will allocate the memory for the ring.
    #                           The application must not set a ring_addr in struct
    #                           `io_uring_buf_reg`, instead it must subsequently call
    #                           `mmap(2)` with the `offset` set as:
    #                           `IORING_OFF_PBUF_RING` | (`bgid << IORING_OFF_PBUF_SHIFT`)
    #                           to get a virtual mapping for the ring.
    cpdef enum:
        IOU_PBUF_RING_MMAP

    # argument for IORING_(UN)REGISTER_PBUF_RING
    struct io_uring_buf_reg_t "io_uring_buf_reg":
        __u64   ring_addr
        __u32   ring_entries
        __u16   bgid
        __u16   flags
        __u64   resv[3]

    # io_uring_restriction->opcode values
    cpdef enum:
        IORING_RESTRICTION_REGISTER_OP          # Allow an io_uring_register(2) opcode
        IORING_RESTRICTION_SQE_OP               # Allow an sqe opcode
        IORING_RESTRICTION_SQE_FLAGS_ALLOWED    # Allow sqe flags
        # Require sqe flags (these flags must be set on each submission)
        IORING_RESTRICTION_SQE_FLAGS_REQUIRED
        IORING_RESTRICTION_LAST

    struct io_uring_getevents_arg_t "io_uring_getevents_arg":
        __u64   sigmask
        __u32   sigmask_sz
        __u32   pad
        __u64   ts

    # Argument for IORING_REGISTER_SYNC_CANCEL
    struct io_uring_sync_cancel_reg_t "io_uring_sync_cancel_reg":
        __u64               addr
        __s32               fd
        __u32               flags
        __kernel_timespec   timeout
        __u64               pad[4]

    # Argument for `IORING_REGISTER_FILE_ALLOC_RANGE`
    # The range is specified as [off, off + len)
    struct io_uring_file_index_range_t "io_uring_file_index_range":
        __u32   off
        __u32   len
        __u64   resv

    struct io_uring_recvmsg_out_t "io_uring_recvmsg_out":
        __u32   namelen
        __u32   controllen
        __u32   payloadlen
        __u32   flags

    # Argument for IORING_OP_URING_CMD when file is a socket
    cpdef enum:
        SOCKET_URING_OP_SIOCINQ
        SOCKET_URING_OP_SIOCOUTQ
        SOCKET_URING_OP_GETSOCKOPT
        SOCKET_URING_OP_SETSOCKOPT


cdef class io_uring_sqe:
    cdef:
        io_uring_sqe_t  *   ptr
        unsigned int        len
        list                ref  # index object reference holder

cdef class io_uring_cqe:
    cdef io_uring_cqe_t * ptr

# TODO:
# cdef class io_uring_params:
#     cdef io_uring_params_t * ptr

# cdef class io_uring_restriction:
#     cdef io_uring_restriction_t * ptr

# cdef class io_uring_buf_reg:
#     cdef io_uring_buf_reg_t * ptr

# cdef class io_uring_sync_cancel_reg:
#     cdef io_uring_sync_cancel_reg_t * ptr

# cdef class io_uring_buf_ring:
#     cdef io_uring_buf_ring_t * ptr
