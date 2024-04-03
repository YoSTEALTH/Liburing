import liburing


def test_io_uring_defines():
    assert liburing.IORING_FILE_INDEX_ALLOC == 4294967295

    # sqe.flags
    assert liburing.IOSQE_FIXED_FILE == 1 << 0
    assert liburing.IOSQE_IO_DRAIN == 1 << 1
    assert liburing.IOSQE_IO_LINK == 1 << 2
    assert liburing.IOSQE_IO_HARDLINK == 1 << 3
    assert liburing.IOSQE_ASYNC == 1 << 4
    assert liburing.IOSQE_BUFFER_SELECT == 1 << 5
    assert liburing.IOSQE_CQE_SKIP_SUCCESS == 1 << 6

    # io_uring_setup() flags
    assert liburing.IORING_SETUP_IOPOLL == 1 << 0
    assert liburing.IORING_SETUP_SQPOLL == 1 << 1
    assert liburing.IORING_SETUP_SQ_AFF == 1 << 2
    assert liburing.IORING_SETUP_CQSIZE == 1 << 3
    assert liburing.IORING_SETUP_CLAMP == 1 << 4
    assert liburing.IORING_SETUP_ATTACH_WQ == 1 << 5
    assert liburing.IORING_SETUP_R_DISABLED == 1 << 6
    assert liburing.IORING_SETUP_SUBMIT_ALL == 1 << 7

    assert liburing.IORING_SETUP_COOP_TASKRUN == 1 << 8
    assert liburing.IORING_SETUP_TASKRUN_FLAG == 1 << 9
    assert liburing.IORING_SETUP_SQE128 == 1 << 10
    assert liburing.IORING_SETUP_CQE32 == 1 << 11
    assert liburing.IORING_SETUP_SINGLE_ISSUER == 1 << 12
    assert liburing.IORING_SETUP_DEFER_TASKRUN == 1 << 13
    assert liburing.IORING_SETUP_NO_MMAP == 1 << 14
    assert liburing.IORING_SETUP_REGISTERED_FD_ONLY == 1 << 15
    assert liburing.IORING_SETUP_NO_SQARRAY == 1 << 16

    # enum: io_uring_op
    for i, flag in enumerate((liburing.IORING_OP_NOP, 
                              liburing.IORING_OP_READV, 
                              liburing.IORING_OP_WRITEV, 
                              liburing.IORING_OP_FSYNC, 
                              liburing.IORING_OP_READ_FIXED, 
                              liburing.IORING_OP_WRITE_FIXED, 
                              liburing.IORING_OP_POLL_ADD, 
                              liburing.IORING_OP_POLL_REMOVE, 
                              liburing.IORING_OP_SYNC_FILE_RANGE, 
                              liburing.IORING_OP_SENDMSG, 
                              liburing.IORING_OP_RECVMSG, 
                              liburing.IORING_OP_TIMEOUT, 
                              liburing.IORING_OP_TIMEOUT_REMOVE, 
                              liburing.IORING_OP_ACCEPT, 
                              liburing.IORING_OP_ASYNC_CANCEL, 
                              liburing.IORING_OP_LINK_TIMEOUT, 
                              liburing.IORING_OP_CONNECT, 
                              liburing.IORING_OP_FALLOCATE, 
                              liburing.IORING_OP_OPENAT, 
                              liburing.IORING_OP_CLOSE, 
                              liburing.IORING_OP_FILES_UPDATE, 
                              liburing.IORING_OP_STATX, 
                              liburing.IORING_OP_READ, 
                              liburing.IORING_OP_WRITE, 
                              liburing.IORING_OP_FADVISE, 
                              liburing.IORING_OP_MADVISE, 
                              liburing.IORING_OP_SEND, 
                              liburing.IORING_OP_RECV, 
                              liburing.IORING_OP_OPENAT2, 
                              liburing.IORING_OP_EPOLL_CTL, 
                              liburing.IORING_OP_SPLICE, 
                              liburing.IORING_OP_PROVIDE_BUFFERS, 
                              liburing.IORING_OP_REMOVE_BUFFERS, 
                              liburing.IORING_OP_TEE, 
                              liburing.IORING_OP_SHUTDOWN, 
                              liburing.IORING_OP_RENAMEAT, 
                              liburing.IORING_OP_UNLINKAT, 
                              liburing.IORING_OP_MKDIRAT, 
                              liburing.IORING_OP_SYMLINKAT, 
                              liburing.IORING_OP_LINKAT, 
                              liburing.IORING_OP_MSG_RING, 
                              liburing.IORING_OP_FSETXATTR, 
                              liburing.IORING_OP_SETXATTR, 
                              liburing.IORING_OP_FGETXATTR, 
                              liburing.IORING_OP_GETXATTR, 
                              liburing.IORING_OP_SOCKET, 
                              liburing.IORING_OP_URING_CMD, 
                              liburing.IORING_OP_SEND_ZC, 
                              liburing.IORING_OP_SENDMSG_ZC, 
                              liburing.IORING_OP_READ_MULTISHOT, 
                              liburing.IORING_OP_WAITID, 
                              liburing.IORING_OP_FUTEX_WAIT, 
                              liburing.IORING_OP_FUTEX_WAKE, 
                              liburing.IORING_OP_FUTEX_WAITV, 
                              liburing.IORING_OP_FIXED_FD_INSTALL, 
                              liburing.IORING_OP_FTRUNCATE, 
                              liburing.IORING_OP_LAST)):
        assert i == flag

    assert liburing.IORING_URING_CMD_FIXED == 1 << 0
    assert liburing.IORING_FSYNC_DATASYNC == 1 << 0

    # `sqe->timeout_flags`
    assert liburing.IORING_TIMEOUT_ABS == 1 << 0
    assert liburing.IORING_TIMEOUT_UPDATE == 1 << 1
    assert liburing.IORING_TIMEOUT_BOOTTIME == 1 << 2
    assert liburing.IORING_TIMEOUT_REALTIME == 1 << 3
    assert liburing.IORING_LINK_TIMEOUT_UPDATE == 1 << 4
    assert liburing.IORING_TIMEOUT_ETIME_SUCCESS == 1 << 5
    assert liburing.IORING_TIMEOUT_MULTISHOT == 1 << 6
    assert liburing.IORING_TIMEOUT_CLOCK_MASK == (liburing.IORING_TIMEOUT_BOOTTIME
                                                  | liburing.IORING_TIMEOUT_REALTIME)
    assert liburing.IORING_TIMEOUT_UPDATE_MASK == (liburing.IORING_TIMEOUT_UPDATE
                                                   | liburing.IORING_LINK_TIMEOUT_UPDATE)

    assert liburing.SPLICE_F_FD_IN_FIXED == 1 << 31

    assert liburing.IORING_POLL_ADD_MULTI == 1 << 0
    assert liburing.IORING_POLL_UPDATE_EVENTS == 1 << 1
    assert liburing.IORING_POLL_UPDATE_USER_DATA == 1 << 2
    assert liburing.IORING_POLL_ADD_LEVEL == 1 << 3

    assert liburing.IORING_ASYNC_CANCEL_ALL == 1 << 0
    assert liburing.IORING_ASYNC_CANCEL_FD == 1 << 1
    assert liburing.IORING_ASYNC_CANCEL_ANY == 1 << 2
    assert liburing.IORING_ASYNC_CANCEL_FD_FIXED == 1 << 3

    assert liburing.IORING_RECVSEND_POLL_FIRST == 1 << 0
    assert liburing.IORING_RECV_MULTISHOT == 1 << 1
    assert liburing.IORING_RECVSEND_FIXED_BUF == 1 << 2
    assert liburing.IORING_SEND_ZC_REPORT_USAGE == 1 << 3

    assert liburing.IORING_NOTIF_USAGE_ZC_COPIED == 1 << 31
    assert liburing.IORING_ACCEPT_MULTISHOT == 1 << 0

    # enum: io_uring_msg_ring_flags
    for i, flag in enumerate((liburing.IORING_MSG_DATA, 
                              liburing.IORING_MSG_SEND_FD)):
        assert i == flag

    assert liburing.IORING_MSG_RING_CQE_SKIP == 1 << 0
    assert liburing.IORING_MSG_RING_FLAGS_PASS == 1 << 1
    assert liburing.IORING_FIXED_FD_NO_CLOEXEC == 1 << 0

    assert liburing.IORING_CQE_F_BUFFER == 1 << 0
    assert liburing.IORING_CQE_F_MORE == 1 << 1
    assert liburing.IORING_CQE_F_SOCK_NONEMPTY == 1 << 2
    assert liburing.IORING_CQE_F_NOTIF == 1 << 3

    assert liburing.IORING_CQE_BUFFER_SHIFT == 16

    assert liburing.IORING_OFF_SQ_RING == 0
    assert liburing.IORING_OFF_CQ_RING == 0x8000000
    assert liburing.IORING_OFF_SQES == 0x10000000
    assert liburing.IORING_OFF_PBUF_RING == 0x80000000
    assert liburing.IORING_OFF_PBUF_SHIFT == 16
    assert liburing.IORING_OFF_MMAP_MASK == 0xf8000000

    assert liburing.IORING_SQ_NEED_WAKEUP == 1 << 0
    assert liburing.IORING_SQ_CQ_OVERFLOW == 1 << 1
    assert liburing.IORING_SQ_TASKRUN == 1 << 2

    assert liburing.IORING_CQ_EVENTFD_DISABLED == 1 << 0

    # io_uring_enter(2) flags
    assert liburing.IORING_ENTER_GETEVENTS == 1 << 0
    assert liburing.IORING_ENTER_SQ_WAKEUP == 1 << 1
    assert liburing.IORING_ENTER_SQ_WAIT == 1 << 2
    assert liburing.IORING_ENTER_EXT_ARG == 1 << 3
    assert liburing.IORING_ENTER_REGISTERED_RING == 1 << 4

    # io_uring_params->features flags
    assert liburing.IORING_FEAT_SINGLE_MMAP == 1 << 0
    assert liburing.IORING_FEAT_NODROP == 1 << 1
    assert liburing.IORING_FEAT_SUBMIT_STABLE == 1 << 2
    assert liburing.IORING_FEAT_RW_CUR_POS == 1 << 3
    assert liburing.IORING_FEAT_CUR_PERSONALITY == 1 << 4
    assert liburing.IORING_FEAT_FAST_POLL == 1 << 5
    assert liburing.IORING_FEAT_POLL_32BITS == 1 << 6
    assert liburing.IORING_FEAT_SQPOLL_NONFIXED == 1 << 7
    assert liburing.IORING_FEAT_EXT_ARG == 1 << 8
    assert liburing.IORING_FEAT_NATIVE_WORKERS == 1 << 9
    assert liburing.IORING_FEAT_RSRC_TAGS == 1 << 10
    assert liburing.IORING_FEAT_CQE_SKIP == 1 << 11
    assert liburing.IORING_FEAT_LINKED_FILE == 1 << 12
    assert liburing.IORING_FEAT_REG_REG_RING == 1 << 13

    # enum: io_uring_register_op
    for i, flag in enumerate((liburing.IORING_REGISTER_BUFFERS,
                              liburing.IORING_UNREGISTER_BUFFERS,
                              liburing.IORING_REGISTER_FILES,
                              liburing.IORING_UNREGISTER_FILES,
                              liburing.IORING_REGISTER_EVENTFD,
                              liburing.IORING_UNREGISTER_EVENTFD,
                              liburing.IORING_REGISTER_FILES_UPDATE,
                              liburing.IORING_REGISTER_EVENTFD_ASYNC,
                              liburing.IORING_REGISTER_PROBE,
                              liburing.IORING_REGISTER_PERSONALITY,
                              liburing.IORING_UNREGISTER_PERSONALITY,
                              liburing.IORING_REGISTER_RESTRICTIONS,
                              liburing.IORING_REGISTER_ENABLE_RINGS,
                              liburing.IORING_REGISTER_FILES2,
                              liburing.IORING_REGISTER_FILES_UPDATE2,
                              liburing.IORING_REGISTER_BUFFERS2,
                              liburing.IORING_REGISTER_BUFFERS_UPDATE,
                              liburing.IORING_REGISTER_IOWQ_AFF,
                              liburing.IORING_UNREGISTER_IOWQ_AFF,
                              liburing.IORING_REGISTER_IOWQ_MAX_WORKERS,
                              liburing.IORING_REGISTER_RING_FDS,
                              liburing.IORING_UNREGISTER_RING_FDS,
                              liburing.IORING_REGISTER_PBUF_RING,
                              liburing.IORING_UNREGISTER_PBUF_RING,
                              liburing.IORING_REGISTER_SYNC_CANCEL,
                              liburing.IORING_REGISTER_FILE_ALLOC_RANGE,
                              liburing.IORING_REGISTER_PBUF_STATUS,
                              liburing.IORING_REGISTER_NAPI,
                              liburing.IORING_UNREGISTER_NAPI,
                              liburing.IORING_REGISTER_LAST)):
        assert i == flag
    assert liburing.IORING_REGISTER_USE_REGISTERED_RING == 2147483648

    # enum: io_wq_type
    for i, flag in enumerate((liburing.IO_WQ_BOUND,
                              liburing.IO_WQ_UNBOUND)):
        assert i == flag

    assert liburing.IORING_RSRC_REGISTER_SPARSE == 1 << 0

    assert liburing.IORING_REGISTER_FILES_SKIP == -2
    assert liburing.IO_URING_OP_SUPPORTED == 1 << 0

    # enum: io_uring_register_pbuf_ring_flags
    assert liburing.IOU_PBUF_RING_MMAP == 1

    # enum: io_uring_restriction_op
    for i, flag in enumerate((liburing.IORING_RESTRICTION_REGISTER_OP,
                              liburing.IORING_RESTRICTION_SQE_OP,
                              liburing.IORING_RESTRICTION_SQE_FLAGS_ALLOWED,
                              liburing.IORING_RESTRICTION_SQE_FLAGS_REQUIRED,
                              liburing.IORING_RESTRICTION_LAST)):
        assert i == flag

    # enum: io_uring_socket_op
    for i, flag in enumerate((liburing.SOCKET_URING_OP_SIOCINQ,
                              liburing.SOCKET_URING_OP_SIOCOUTQ,
                              liburing.SOCKET_URING_OP_GETSOCKOPT,
                              liburing.SOCKET_URING_OP_SETSOCKOPT)):
        assert i == flag
