from .type cimport *


cdef extern from 'liburing/io_uring.h' nogil:
    # IO submission data structure (Submission Queue Entry)
    struct __io_uring_sqe "io_uring_sqe":
        __u8 flags       # IOSQE_ flags
        __u64 user_data  # data to be passed back at completion time
        # note: other values, embedded union & struct are ignored.
        #   - will add more if someone needs it.

    # If `sqe->file_index` is set to this for opcodes that instantiate a new
    # direct descriptor (like openat/openat2/accept), then `io_uring` will allocate
    # an available direct descriptor instead of having the application pass one
    # in. The picked direct descriptor will be returned in `cqe->res`, or `-ENFILE`
    # if the space is full.
    unsigned int __IORING_FILE_INDEX_ALLOC 'IORING_FILE_INDEX_ALLOC'

    # note: do not need this, its for internal `liburing` use
    # enum:
    #     IOSQE_FIXED_FILE_BIT, ...

    # sqe.flags
    # use fixed file-set
    unsigned int __IOSQE_FIXED_FILE 'IOSQE_FIXED_FILE'
    # issue after inflight IO
    unsigned int __IOSQE_IO_DRAIN 'IOSQE_IO_DRAIN'
    # links next `sqe`
    unsigned int __IOSQE_IO_LINK 'IOSQE_IO_LINK'
    # like LINK, but stronger
    unsigned int __IOSQE_IO_HARDLINK 'IOSQE_IO_HARDLINK'
    # always go async
    unsigned int __IOSQE_ASYNC 'IOSQE_ASYNC'
    # select buffer from `sqe->buf_group`
    unsigned int __IOSQE_BUFFER_SELECT 'IOSQE_BUFFER_SELECT'
    # don't post CQE if request succeeded
    unsigned int __IOSQE_CQE_SKIP_SUCCESS 'IOSQE_CQE_SKIP_SUCCESS'

    # io_uring_setup() flags
    unsigned int __IORING_SETUP_IOPOLL 'IORING_SETUP_IOPOLL'  # io_context is polled
    unsigned int __IORING_SETUP_SQPOLL 'IORING_SETUP_SQPOLL'  # SQ poll thread
    unsigned int __IORING_SETUP_SQ_AFF 'IORING_SETUP_SQ_AFF'  # sq_thread_cpu is valid
    unsigned int __IORING_SETUP_CQSIZE 'IORING_SETUP_CQSIZE'  # app defines CQ size
    unsigned int __IORING_SETUP_CLAMP 'IORING_SETUP_CLAMP'  # clamp SQ/CQ ring sizes
    unsigned int __IORING_SETUP_ATTACH_WQ 'IORING_SETUP_ATTACH_WQ'  # attach to existing wq
    unsigned int __IORING_SETUP_R_DISABLED 'IORING_SETUP_R_DISABLED'  # start with ring disabled
    unsigned int __IORING_SETUP_SUBMIT_ALL 'IORING_SETUP_SUBMIT_ALL'  # continue submit on error

    # Cooperative task running. When requests complete, they often require
    # forcing the submitter to transition to the kernel to complete. If this
    # flag is set, work will be done when the task transitions anyway, rather
    # than force an inter-processor interrupt reschedule. This avoids interrupting
    # a task running in userspace, and saves an IPI.
    unsigned int __IORING_SETUP_COOP_TASKRUN 'IORING_SETUP_COOP_TASKRUN'

    # If `COOP_TASKRUN` is set, get notified if task work is available for
    # running and a kernel transition would be needed to run it. This sets
    # `IORING_SQ_TASKRUN` in the sq ring flags. Not valid with `COOP_TASKRUN`.
    unsigned int __IORING_SETUP_TASKRUN_FLAG 'IORING_SETUP_TASKRUN_FLAG'
    unsigned int __IORING_SETUP_SQE128 'IORING_SETUP_SQE128'
    unsigned int __IORING_SETUP_CQE32 'IORING_SETUP_CQE32'

    # Only one task is allowed to submit requests
    unsigned int __IORING_SETUP_SINGLE_ISSUER 'IORING_SETUP_SINGLE_ISSUER'

    # Defer running task work to get events.
    # Rather than running bits of task work whenever the task transitions
    # try to do it just before it is needed.
    unsigned int __IORING_SETUP_DEFER_TASKRUN 'IORING_SETUP_DEFER_TASKRUN'

    # Application provides ring memory
    unsigned int __IORING_SETUP_NO_MMAP 'IORING_SETUP_NO_MMAP'

    # Register the ring fd in itself for use with
    # IORING_REGISTER_USE_REGISTERED_RING; return a registered fd index rather
    # than an fd.
    unsigned int __IORING_SETUP_REGISTERED_FD_ONLY 'IORING_SETUP_REGISTERED_FD_ONLY'

    # Removes indirection through the SQ index array.
    unsigned int __IORING_SETUP_NO_SQARRAY 'IORING_SETUP_NO_SQARRAY'

    enum __io_uring_op 'io_uring_op':
        __IORING_OP_NOP 'IORING_OP_NOP'
        __IORING_OP_READV 'IORING_OP_READV'
        __IORING_OP_WRITEV 'IORING_OP_WRITEV'
        __IORING_OP_FSYNC 'IORING_OP_FSYNC'
        __IORING_OP_READ_FIXED 'IORING_OP_READ_FIXED'
        __IORING_OP_WRITE_FIXED 'IORING_OP_WRITE_FIXED'
        __IORING_OP_POLL_ADD 'IORING_OP_POLL_ADD'
        __IORING_OP_POLL_REMOVE 'IORING_OP_POLL_REMOVE'
        __IORING_OP_SYNC_FILE_RANGE 'IORING_OP_SYNC_FILE_RANGE'
        __IORING_OP_SENDMSG 'IORING_OP_SENDMSG'
        __IORING_OP_RECVMSG 'IORING_OP_RECVMSG'
        __IORING_OP_TIMEOUT 'IORING_OP_TIMEOUT'
        __IORING_OP_TIMEOUT_REMOVE 'IORING_OP_TIMEOUT_REMOVE'
        __IORING_OP_ACCEPT 'IORING_OP_ACCEPT'
        __IORING_OP_ASYNC_CANCEL 'IORING_OP_ASYNC_CANCEL'
        __IORING_OP_LINK_TIMEOUT 'IORING_OP_LINK_TIMEOUT'
        __IORING_OP_CONNECT 'IORING_OP_CONNECT'
        __IORING_OP_FALLOCATE 'IORING_OP_FALLOCATE'
        __IORING_OP_OPENAT 'IORING_OP_OPENAT'
        __IORING_OP_CLOSE 'IORING_OP_CLOSE'
        __IORING_OP_FILES_UPDATE 'IORING_OP_FILES_UPDATE'
        __IORING_OP_STATX 'IORING_OP_STATX'
        __IORING_OP_READ 'IORING_OP_READ'
        __IORING_OP_WRITE 'IORING_OP_WRITE'
        __IORING_OP_FADVISE 'IORING_OP_FADVISE'
        __IORING_OP_MADVISE 'IORING_OP_MADVISE'
        __IORING_OP_SEND 'IORING_OP_SEND'
        __IORING_OP_RECV 'IORING_OP_RECV'
        __IORING_OP_OPENAT2 'IORING_OP_OPENAT2'
        __IORING_OP_EPOLL_CTL 'IORING_OP_EPOLL_CTL'
        __IORING_OP_SPLICE 'IORING_OP_SPLICE'
        __IORING_OP_PROVIDE_BUFFERS 'IORING_OP_PROVIDE_BUFFERS'
        __IORING_OP_REMOVE_BUFFERS 'IORING_OP_REMOVE_BUFFERS'
        __IORING_OP_TEE 'IORING_OP_TEE'
        __IORING_OP_SHUTDOWN 'IORING_OP_SHUTDOWN'
        __IORING_OP_RENAMEAT 'IORING_OP_RENAMEAT'
        __IORING_OP_UNLINKAT 'IORING_OP_UNLINKAT'
        __IORING_OP_MKDIRAT 'IORING_OP_MKDIRAT'
        __IORING_OP_SYMLINKAT 'IORING_OP_SYMLINKAT'
        __IORING_OP_LINKAT 'IORING_OP_LINKAT'
        __IORING_OP_MSG_RING 'IORING_OP_MSG_RING'
        __IORING_OP_FSETXATTR 'IORING_OP_FSETXATTR'
        __IORING_OP_SETXATTR 'IORING_OP_SETXATTR'
        __IORING_OP_FGETXATTR 'IORING_OP_FGETXATTR'
        __IORING_OP_GETXATTR 'IORING_OP_GETXATTR'
        __IORING_OP_SOCKET 'IORING_OP_SOCKET'
        __IORING_OP_URING_CMD 'IORING_OP_URING_CMD'
        __IORING_OP_SEND_ZC 'IORING_OP_SEND_ZC'
        __IORING_OP_SENDMSG_ZC 'IORING_OP_SENDMSG_ZC'
        __IORING_OP_READ_MULTISHOT 'IORING_OP_READ_MULTISHOT'
        __IORING_OP_WAITID 'IORING_OP_WAITID'
        __IORING_OP_FUTEX_WAIT 'IORING_OP_FUTEX_WAIT'
        __IORING_OP_FUTEX_WAKE 'IORING_OP_FUTEX_WAKE'
        __IORING_OP_FUTEX_WAITV 'IORING_OP_FUTEX_WAITV'
        __IORING_OP_FIXED_FD_INSTALL 'IORING_OP_FIXED_FD_INSTALL'
        __IORING_OP_FTRUNCATE 'IORING_OP_FTRUNCATE'
        # this goes last, obviously
        __IORING_OP_LAST 'IORING_OP_LAST'

    # `sqe->uring_cmd_flags`
    # `IORING_URING_CMD_FIXED` use registered buffer;
    # pass this flag along with setting `sqe->buf_index`.
    unsigned int __IORING_URING_CMD_FIXED 'IORING_URING_CMD_FIXED'

    # `sqe->fsync_flags`
    unsigned int __IORING_FSYNC_DATASYNC 'IORING_FSYNC_DATASYNC'

    # `sqe->timeout_flags`
    unsigned int __IORING_TIMEOUT_ABS 'IORING_TIMEOUT_ABS'
    unsigned int __IORING_TIMEOUT_UPDATE 'IORING_TIMEOUT_UPDATE'
    unsigned int __IORING_TIMEOUT_BOOTTIME 'IORING_TIMEOUT_BOOTTIME'
    unsigned int __IORING_TIMEOUT_REALTIME 'IORING_TIMEOUT_REALTIME'
    unsigned int __IORING_LINK_TIMEOUT_UPDATE 'IORING_LINK_TIMEOUT_UPDATE'
    unsigned int __IORING_TIMEOUT_ETIME_SUCCESS 'IORING_TIMEOUT_ETIME_SUCCESS'
    unsigned int __IORING_TIMEOUT_MULTISHOT 'IORING_TIMEOUT_MULTISHOT'
    unsigned int __IORING_TIMEOUT_CLOCK_MASK 'IORING_TIMEOUT_CLOCK_MASK'
    unsigned int __IORING_TIMEOUT_UPDATE_MASK 'IORING_TIMEOUT_UPDATE_MASK'

    # `sqe->splice_flags`
    # extends splice(2) flags
    __u32 __SPLICE_F_FD_IN_FIXED 'SPLICE_F_FD_IN_FIXED'

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
    unsigned int __IORING_POLL_ADD_MULTI 'IORING_POLL_ADD_MULTI'
    unsigned int __IORING_POLL_UPDATE_EVENTS 'IORING_POLL_UPDATE_EVENTS'
    unsigned int __IORING_POLL_UPDATE_USER_DATA 'IORING_POLL_UPDATE_USER_DATA'
    unsigned int __IORING_POLL_ADD_LEVEL 'IORING_POLL_ADD_LEVEL'

    # ASYNC_CANCEL flags.
    # Cancel all requests that match the given key
    unsigned int __IORING_ASYNC_CANCEL_ALL 'IORING_ASYNC_CANCEL_ALL'
    # Key off `fd` for cancellation rather than the request `user_data`
    unsigned int __IORING_ASYNC_CANCEL_FD 'IORING_ASYNC_CANCEL_FD'
    # Match any request
    unsigned int __IORING_ASYNC_CANCEL_ANY 'IORING_ASYNC_CANCEL_ANY'
    # 'fd' passed in is a fixed descriptor
    unsigned int __IORING_ASYNC_CANCEL_FD_FIXED 'IORING_ASYNC_CANCEL_FD_FIXED'

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
    unsigned int __IORING_RECVSEND_POLL_FIRST 'IORING_RECVSEND_POLL_FIRST'
    unsigned int __IORING_RECV_MULTISHOT 'IORING_RECV_MULTISHOT'
    unsigned int __IORING_RECVSEND_FIXED_BUF 'IORING_RECVSEND_FIXED_BUF'
    unsigned int __IORING_SEND_ZC_REPORT_USAGE 'IORING_SEND_ZC_REPORT_USAGE'

    # `cqe.res` for `IORING_CQE_F_NOTIF` if
    # `IORING_SEND_ZC_REPORT_USAGE` was requested
    #
    # It should be treated as a flag, all other
    # bits of `cqe.res` should be treated as reserved!
    __u32 __IORING_NOTIF_USAGE_ZC_COPIED 'IORING_NOTIF_USAGE_ZC_COPIED'

    # accept flags stored in `sqe->ioprio`
    unsigned int __IORING_ACCEPT_MULTISHOT 'IORING_ACCEPT_MULTISHOT'

    # `IORING_OP_MSG_RING` command types, stored in `sqe->addr`
    # TODO: enum __io_uring_msg 'io_uring_msg':
    enum __io_uring_msg_op 'io_uring_msg_op':
        __IORING_MSG_DATA 'IORING_MSG_DATA'  # pass `sqe->len` as `res` and `off` as `user_data`
        __IORING_MSG_SEND_FD 'IORING_MSG_SEND_FD'  # send a registered `fd` to another ring

    # `IORING_OP_MSG_RING` flags (`sqe->msg_ring_flags`)
    #
    # `IORING_MSG_RING_CQE_SKIP`    Don't post a CQE to the target ring. Not
    #                               applicable for `IORING_MSG_DATA`, obviously.
    unsigned int __IORING_MSG_RING_CQE_SKIP 'IORING_MSG_RING_CQE_SKIP'
    # Pass through the flags from `sqe->file_index` to `cqe->flags`
    unsigned int __IORING_MSG_RING_FLAGS_PASS 'IORING_MSG_RING_FLAGS_PASS'

    # `IORING_OP_FIXED_FD_INSTALL` flags (`sqe->install_fd_flags`)
    #
    # `IORING_FIXED_FD_NO_CLOEXEC`   Don't mark the `fd` as `O_CLOEXEC`
    unsigned int __IORING_FIXED_FD_NO_CLOEXEC 'IORING_FIXED_FD_NO_CLOEXEC'

    # IO completion data structure (Completion Queue Entry)
    struct __io_uring_cqe "io_uring_cqe":
        __u64 user_data  # `sqe->data` submission passed back
        __s32 res        # result code for this event
        __u32 flags
        # If the ring is initialized with `IORING_SETUP_CQE32`, then this field
        # contains 16-bytes of padding, doubling the size of the CQE.
        __u64 big_cqe[]
        # __u64   big_cqe[16] ???

    # cqe->flags
    # If set, the upper 16 bits are the buffer ID
    unsigned int __IORING_CQE_F_BUFFER 'IORING_CQE_F_BUFFER'
    # If set, parent SQE will generate more CQE entries
    unsigned int __IORING_CQE_F_MORE 'IORING_CQE_F_MORE'
    # If set, more data to read after socket recv
    unsigned int __IORING_CQE_F_SOCK_NONEMPTY 'IORING_CQE_F_SOCK_NONEMPTY'
    # Set for notification CQEs. Can be used to distinct them from sends.
    unsigned int __IORING_CQE_F_NOTIF 'IORING_CQE_F_NOTIF'

    enum __io_uring_cqe_op 'io_uring_cqe_op':
        __IORING_CQE_BUFFER_SHIFT 'IORING_CQE_BUFFER_SHIFT'

    # Magic offsets for the application to mmap the data it needs
    unsigned long long __IORING_OFF_SQ_RING 'IORING_OFF_SQ_RING'
    unsigned long long __IORING_OFF_CQ_RING 'IORING_OFF_CQ_RING'
    unsigned long long __IORING_OFF_SQES 'IORING_OFF_SQES'
    unsigned long long __IORING_OFF_PBUF_RING 'IORING_OFF_PBUF_RING'
    unsigned int       __IORING_OFF_PBUF_SHIFT 'IORING_OFF_PBUF_SHIFT'
    unsigned long long __IORING_OFF_MMAP_MASK 'IORING_OFF_MMAP_MASK'

    # Filled with the offset for mmap(2)
    struct __io_sqring_offsets "io_sqring_offsets":
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
    unsigned int __IORING_SQ_NEED_WAKEUP 'IORING_SQ_NEED_WAKEUP'  # needs `io_uring_enter` wake-up
    unsigned int __IORING_SQ_CQ_OVERFLOW 'IORING_SQ_CQ_OVERFLOW'  # CQ ring is overflown
    unsigned int __IORING_SQ_TASKRUN 'IORING_SQ_TASKRUN'  # task should enter the kernel

    struct __io_cqring_offsets "io_cqring_offsets":
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
    # disable eventfd notifications
    unsigned int __IORING_CQ_EVENTFD_DISABLED 'IORING_CQ_EVENTFD_DISABLED'

    # io_uring_enter(2) flags
    unsigned int __IORING_ENTER_GETEVENTS 'IORING_ENTER_GETEVENTS'
    unsigned int __IORING_ENTER_SQ_WAKEUP 'IORING_ENTER_SQ_WAKEUP'
    unsigned int __IORING_ENTER_SQ_WAIT 'IORING_ENTER_SQ_WAIT'
    unsigned int __IORING_ENTER_EXT_ARG 'IORING_ENTER_EXT_ARG'
    unsigned int __IORING_ENTER_REGISTERED_RING 'IORING_ENTER_REGISTERED_RING'

    # Passed in for io_uring_setup(2). Copied back with updated info on success
    struct __io_uring_params "io_uring_params":
        __u32   sq_entries
        __u32   cq_entries
        __u32   flags
        __u32   sq_thread_cpu
        __u32   sq_thread_idle
        __u32   features
        __u32   wq_fd
        __u32   resv[3]
        __io_sqring_offsets   sq_off
        __io_cqring_offsets   cq_off

    # io_uring_params->features flags
    unsigned int __IORING_FEAT_SINGLE_MMAP 'IORING_FEAT_SINGLE_MMAP'
    unsigned int __IORING_FEAT_NODROP 'IORING_FEAT_NODROP'
    unsigned int __IORING_FEAT_SUBMIT_STABLE 'IORING_FEAT_SUBMIT_STABLE'
    unsigned int __IORING_FEAT_RW_CUR_POS 'IORING_FEAT_RW_CUR_POS'
    unsigned int __IORING_FEAT_CUR_PERSONALITY 'IORING_FEAT_CUR_PERSONALITY'
    unsigned int __IORING_FEAT_FAST_POLL 'IORING_FEAT_FAST_POLL'
    unsigned int __IORING_FEAT_POLL_32BITS 'IORING_FEAT_POLL_32BITS'
    unsigned int __IORING_FEAT_SQPOLL_NONFIXED 'IORING_FEAT_SQPOLL_NONFIXED'
    unsigned int __IORING_FEAT_EXT_ARG 'IORING_FEAT_EXT_ARG'
    unsigned int __IORING_FEAT_NATIVE_WORKERS 'IORING_FEAT_NATIVE_WORKERS'
    unsigned int __IORING_FEAT_RSRC_TAGS 'IORING_FEAT_RSRC_TAGS'
    unsigned int __IORING_FEAT_CQE_SKIP 'IORING_FEAT_CQE_SKIP'
    unsigned int __IORING_FEAT_LINKED_FILE 'IORING_FEAT_LINKED_FILE'
    unsigned int __IORING_FEAT_REG_REG_RING 'IORING_FEAT_REG_REG_RING'

    # io_uring_register(2) opcodes and arguments
    enum __io_uring_register_op 'io_uring_register_op':
        __IORING_REGISTER_BUFFERS 'IORING_REGISTER_BUFFERS'
        __IORING_UNREGISTER_BUFFERS 'IORING_UNREGISTER_BUFFERS'
        __IORING_REGISTER_FILES 'IORING_REGISTER_FILES'
        __IORING_UNREGISTER_FILES 'IORING_UNREGISTER_FILES'
        __IORING_REGISTER_EVENTFD 'IORING_REGISTER_EVENTFD'
        __IORING_UNREGISTER_EVENTFD 'IORING_UNREGISTER_EVENTFD'
        __IORING_REGISTER_FILES_UPDATE 'IORING_REGISTER_FILES_UPDATE'
        __IORING_REGISTER_EVENTFD_ASYNC 'IORING_REGISTER_EVENTFD_ASYNC'
        __IORING_REGISTER_PROBE 'IORING_REGISTER_PROBE'
        __IORING_REGISTER_PERSONALITY 'IORING_REGISTER_PERSONALITY'
        __IORING_UNREGISTER_PERSONALITY 'IORING_UNREGISTER_PERSONALITY'
        __IORING_REGISTER_RESTRICTIONS 'IORING_REGISTER_RESTRICTIONS'
        __IORING_REGISTER_ENABLE_RINGS 'IORING_REGISTER_ENABLE_RINGS'

        # extended with tagging
        __IORING_REGISTER_FILES2 'IORING_REGISTER_FILES2'
        __IORING_REGISTER_FILES_UPDATE2 'IORING_REGISTER_FILES_UPDATE2'
        __IORING_REGISTER_BUFFERS2 'IORING_REGISTER_BUFFERS2'
        __IORING_REGISTER_BUFFERS_UPDATE 'IORING_REGISTER_BUFFERS_UPDATE'

        # set/clear io-wq thread affinities
        __IORING_REGISTER_IOWQ_AFF 'IORING_REGISTER_IOWQ_AFF'
        __IORING_UNREGISTER_IOWQ_AFF 'IORING_UNREGISTER_IOWQ_AFF'

        # set/get max number of io-wq workers
        __IORING_REGISTER_IOWQ_MAX_WORKERS 'IORING_REGISTER_IOWQ_MAX_WORKERS'

        #  register/unregister io_uring fd with the ring
        __IORING_REGISTER_RING_FDS 'IORING_REGISTER_RING_FDS'
        __IORING_UNREGISTER_RING_FDS 'IORING_UNREGISTER_RING_FDS'

        # register ring based provide buffer group
        __IORING_REGISTER_PBUF_RING 'IORING_REGISTER_PBUF_RING'
        __IORING_UNREGISTER_PBUF_RING 'IORING_UNREGISTER_PBUF_RING'

        # sync cancellation API
        __IORING_REGISTER_SYNC_CANCEL 'IORING_REGISTER_SYNC_CANCEL'

        # register a range of fixed file slots for automatic slot allocation
        __IORING_REGISTER_FILE_ALLOC_RANGE 'IORING_REGISTER_FILE_ALLOC_RANGE'

        # return status information for a buffer group
        __IORING_REGISTER_PBUF_STATUS 'IORING_REGISTER_PBUF_STATUS'

        # set/clear busy poll settings
        __IORING_REGISTER_NAPI 'IORING_REGISTER_NAPI'
        __IORING_UNREGISTER_NAPI 'IORING_UNREGISTER_NAPI'

        # this goes last
        __IORING_REGISTER_LAST 'IORING_REGISTER_LAST'

        # flag added to the opcode to use a registered ring fd
        __IORING_REGISTER_USE_REGISTERED_RING 'IORING_REGISTER_USE_REGISTERED_RING'

    # io-wq worker categories
    enum __io_uring_wq_op 'io_uring_wq_op':
        __IO_WQ_BOUND 'IO_WQ_BOUND'
        __IO_WQ_UNBOUND 'IO_WQ_UNBOUND'

    # NOTE: skipping `io_uring_files_update` deprecated

    # Register a fully sparse file space, rather than pass in an array of all
    # `-1` file descriptors.
    unsigned int __IORING_RSRC_REGISTER_SPARSE 'IORING_RSRC_REGISTER_SPARSE'

    struct __io_uring_rsrc_register "io_uring_rsrc_register":
        __u32 nr
        __u32 flags
        __u64 resv2
        __aligned_u64 data
        __aligned_u64 tags

    struct __io_uring_rsrc_update "io_uring_rsrc_update":
        __u32 offset
        __u32 resv
        __aligned_u64 data

    struct __io_uring_rsrc_update2 "io_uring_rsrc_update2":
        __u32 offset
        __u32 resv
        __aligned_u64 data
        __aligned_u64 tags
        __u32 nr
        __u32 resv2

    # Skip updating fd indexes set to this value in the fd table
    int __IORING_REGISTER_FILES_SKIP 'IORING_REGISTER_FILES_SKIP'

    unsigned int __IO_URING_OP_SUPPORTED 'IO_URING_OP_SUPPORTED'

    struct __io_uring_probe_op "io_uring_probe_op":
        __u8 op
        __u8 resv
        __u16 flags   # IO_URING_OP_* flags
        __u32 resv2

    struct __io_uring_probe "io_uring_probe":
        __u8 last_op   # last opcode supported
        __u8 ops_len   # length of ops[] array below
        __u16 resv
        __u32 resv2[3]
        __io_uring_probe_op ops[]

    struct __io_uring_restriction "io_uring_restriction":
        pass  # TODO:
        # __u16   opcode
        # union:
        #     __u8    register_op     # IORING_RESTRICTION_REGISTER_OP
        #     __u8    sqe_op          # IORING_RESTRICTION_SQE_OP
        #     __u8    sqe_flags       # IORING_RESTRICTION_SQE_FLAGS_*
        # __u8    resv
        # __u32   resv2[3]

    struct __io_uring_buf "io_uring_buf":
        __u64 addr
        __u32 len
        __u16 bid
        __u16 resv

    struct __io_uring_buf_ring "io_uring_buf_ring":
        pass  # TODO:
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
    enum __io_uring_buf_op 'io_uring_buf_op':
        __IOU_PBUF_RING_MMAP 'IOU_PBUF_RING_MMAP'

    # argument for IORING_(UN)REGISTER_PBUF_RING
    struct __io_uring_buf_reg "io_uring_buf_reg":
        __u64 ring_addr
        __u32 ring_entries
        __u16 bgid
        __u16 flags
        __u64 resv[3]

    # argument for `IORING_REGISTER_PBUF_STATUS`
    struct __io_uring_buf_status 'io_uring_buf_status':
        __u32 buf_group  # input
        __u32 head  # output
        __u32 resv[8]

    # argument for IORING_(UN)REGISTER_NAPI
    struct __io_uring_napi 'io_uring_napi':
        __u32 busy_poll_to
        __u8  prefer_busy_poll
        __u8  pad[3]
        __u64 resv

    # `io_uring_restriction->opcode` values
    enum __io_uring_restriction_op 'io_uring_restriction_op':
        # Allow an io_uring_register(2) opcode
        __IORING_RESTRICTION_REGISTER_OP 'IORING_RESTRICTION_REGISTER_OP'
        # Allow an sqe opcode
        __IORING_RESTRICTION_SQE_OP 'IORING_RESTRICTION_SQE_OP'
        # Allow sqe flags
        __IORING_RESTRICTION_SQE_FLAGS_ALLOWED 'IORING_RESTRICTION_SQE_FLAGS_ALLOWED'
        # Require sqe flags (these flags must be set on each submission)
        __IORING_RESTRICTION_SQE_FLAGS_REQUIRED 'IORING_RESTRICTION_SQE_FLAGS_REQUIRED'
        __IORING_RESTRICTION_LAST 'IORING_RESTRICTION_LAST'

    struct __io_uring_getevents_arg "io_uring_getevents_arg":
        __u64 sigmask
        __u32 sigmask_sz
        __u32 pad
        __u64 ts

    # Argument for `IORING_REGISTER_SYNC_CANCEL`
    struct __io_uring_sync_cancel_reg "io_uring_sync_cancel_reg":
        __u64 addr
        __s32 fd
        __u32 flags
        __kernel_timespec timeout
        __u64 pad[4]

    # Argument for `IORING_REGISTER_FILE_ALLOC_RANGE`
    # The range is specified as [off, off + len)
    struct __io_uring_file_index_range "io_uring_file_index_range":
        __u32 off
        __u32 len
        __u64 resv

    struct __io_uring_recvmsg_out "io_uring_recvmsg_out":
        __u32 namelen
        __u32 controllen
        __u32 payloadlen
        __u32 flags

    # Argument for `IORING_OP_URING_CMD` when file is a socket
    enum __io_uring_socket_op 'io_uring_socket_op':
        __SOCKET_URING_OP_SIOCINQ 'SOCKET_URING_OP_SIOCINQ'
        __SOCKET_URING_OP_SIOCOUTQ 'SOCKET_URING_OP_SIOCOUTQ'
        __SOCKET_URING_OP_GETSOCKOPT 'SOCKET_URING_OP_GETSOCKOPT'
        __SOCKET_URING_OP_SETSOCKOPT 'SOCKET_URING_OP_SETSOCKOPT'
