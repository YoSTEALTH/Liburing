import os
from liburing import *


def test_type_define():
    assert os.O_CREAT == O_CREAT

    # flags for `renameat2`.
    assert RENAME_NOREPLACE == 1 << 0
    assert RENAME_EXCHANGE == 1 << 1
    assert RENAME_WHITEOUT == 1 << 2

    # AT_* flags
    assert AT_FDCWD == -100
    assert AT_SYMLINK_FOLLOW == 0x400
    assert AT_SYMLINK_NOFOLLOW == 0x100
    assert AT_REMOVEDIR == 0x200
    assert AT_NO_AUTOMOUNT == 0x800
    assert AT_EMPTY_PATH == 0x1000
    assert AT_RECURSIVE == 0x8000

    # splice flags
    assert SPLICE_F_MOVE == 1
    assert SPLICE_F_NONBLOCK == 2
    assert SPLICE_F_MORE == 4
    assert SPLICE_F_GIFT == 8

    # `fallocate` mode
    assert FALLOC_FL_KEEP_SIZE == 0x01
    assert FALLOC_FL_PUNCH_HOLE == 0x02
    assert FALLOC_FL_NO_HIDE_STALE == 0x04
    assert FALLOC_FL_COLLAPSE_RANGE == 0x08
    assert FALLOC_FL_ZERO_RANGE == 0x10
    assert FALLOC_FL_INSERT_RANGE == 0x20
    assert FALLOC_FL_UNSHARE_RANGE == 0x40


def test_io_uring_defines():
    assert LIBURING_UDATA_TIMEOUT == 18446744073709551615

    # io_uring.h
    assert IORING_RW_ATTR_FLAG_PI == 1 << 0
    assert IORING_FILE_INDEX_ALLOC == 4294967295

    # sqe.flags
    assert IOSQE_FIXED_FILE == 1 << 0
    assert IOSQE_IO_DRAIN == 1 << 1
    assert IOSQE_IO_LINK == 1 << 2
    assert IOSQE_IO_HARDLINK == 1 << 3
    assert IOSQE_ASYNC == 1 << 4
    assert IOSQE_BUFFER_SELECT == 1 << 5
    assert IOSQE_CQE_SKIP_SUCCESS == 1 << 6

    # io_uring_setup() flags
    assert IORING_SETUP_IOPOLL == 1 << 0
    assert IORING_SETUP_SQPOLL == 1 << 1
    assert IORING_SETUP_SQ_AFF == 1 << 2
    assert IORING_SETUP_CQSIZE == 1 << 3
    assert IORING_SETUP_CLAMP == 1 << 4
    assert IORING_SETUP_ATTACH_WQ == 1 << 5
    assert IORING_SETUP_R_DISABLED == 1 << 6
    assert IORING_SETUP_SUBMIT_ALL == 1 << 7

    assert IORING_SETUP_COOP_TASKRUN == 1 << 8
    assert IORING_SETUP_TASKRUN_FLAG == 1 << 9
    assert IORING_SETUP_SQE128 == 1 << 10
    assert IORING_SETUP_CQE32 == 1 << 11
    assert IORING_SETUP_SINGLE_ISSUER == 1 << 12
    assert IORING_SETUP_DEFER_TASKRUN == 1 << 13
    assert IORING_SETUP_NO_MMAP == 1 << 14
    assert IORING_SETUP_REGISTERED_FD_ONLY == 1 << 15
    assert IORING_SETUP_NO_SQARRAY == 1 << 16
    assert IORING_SETUP_HYBRID_IOPOLL == 1 << 17

    assert IORING_SETUP_CQE_MIXED == 1 << 18
    assert IORING_SETUP_SQE_MIXED == 1 << 19
    assert IORING_SETUP_SQ_REWIND == 1 << 20

    assert IORING_URING_CMD_FIXED == 1 << 0
    assert IORING_URING_CMD_MASK == IORING_URING_CMD_FIXED
    assert IORING_FSYNC_DATASYNC == 1 << 0

    # `sqe->timeout_flags`
    assert IORING_TIMEOUT_ABS == 1 << 0
    assert IORING_TIMEOUT_UPDATE == 1 << 1
    assert IORING_TIMEOUT_BOOTTIME == 1 << 2
    assert IORING_TIMEOUT_REALTIME == 1 << 3
    assert IORING_LINK_TIMEOUT_UPDATE == 1 << 4
    assert IORING_TIMEOUT_ETIME_SUCCESS == 1 << 5
    assert IORING_TIMEOUT_MULTISHOT == 1 << 6
    assert IORING_TIMEOUT_IMMEDIATE_ARG == 1 << 7
    assert IORING_TIMEOUT_CLOCK_MASK == (IORING_TIMEOUT_BOOTTIME | IORING_TIMEOUT_REALTIME)
    assert IORING_TIMEOUT_UPDATE_MASK == (IORING_TIMEOUT_UPDATE | IORING_LINK_TIMEOUT_UPDATE)

    assert SPLICE_F_FD_IN_FIXED == 1 << 31

    assert IORING_POLL_ADD_MULTI == 1 << 0
    assert IORING_POLL_UPDATE_EVENTS == 1 << 1
    assert IORING_POLL_UPDATE_USER_DATA == 1 << 2
    assert IORING_POLL_ADD_LEVEL == 1 << 3

    assert IORING_ASYNC_CANCEL_ALL == 1 << 0
    assert IORING_ASYNC_CANCEL_FD == 1 << 1
    assert IORING_ASYNC_CANCEL_ANY == 1 << 2
    assert IORING_ASYNC_CANCEL_FD_FIXED == 1 << 3
    assert IORING_ASYNC_CANCEL_USERDATA == 1 << 4
    assert IORING_ASYNC_CANCEL_OP == 1 << 5

    assert IORING_RECVSEND_POLL_FIRST == 1 << 0
    assert IORING_RECV_MULTISHOT == 1 << 1
    assert IORING_RECVSEND_FIXED_BUF == 1 << 2
    assert IORING_SEND_ZC_REPORT_USAGE == 1 << 3
    assert IORING_RECVSEND_BUNDLE == 1 << 4
    assert IORING_SEND_VECTORIZED == 1 << 5

    assert IORING_NOTIF_USAGE_ZC_COPIED == 1 << 31
    assert IORING_ACCEPT_MULTISHOT == 1 << 0
    assert IORING_ACCEPT_DONTWAIT == 1 << 1
    assert IORING_ACCEPT_POLL_FIRST == 1 << 2

    assert IORING_MSG_RING_CQE_SKIP == 1 << 0
    assert IORING_MSG_RING_FLAGS_PASS == 1 << 1
    assert IORING_FIXED_FD_NO_CLOEXEC == 1 << 0
    assert IORING_NOP_INJECT_RESULT == 1 << 0
    assert IORING_NOP_CQE32 == 1 << 5

    assert IORING_CQE_F_BUFFER == 1 << 0
    assert IORING_CQE_F_MORE == 1 << 1
    assert IORING_CQE_F_SOCK_NONEMPTY == 1 << 2
    assert IORING_CQE_F_NOTIF == 1 << 3
    assert IORING_CQE_F_BUF_MORE == 1 << 4
    assert IORING_CQE_F_SKIP == 1 << 5
    assert IORING_CQE_F_32 == 1 << 15

    assert IORING_CQE_BUFFER_SHIFT == 16

    assert IORING_OFF_SQ_RING == 0
    assert IORING_OFF_CQ_RING == 0x8000000
    assert IORING_OFF_SQES == 0x10000000
    assert IORING_OFF_PBUF_RING == 0x80000000
    assert IORING_OFF_PBUF_SHIFT == 16
    assert IORING_OFF_MMAP_MASK == 0xF8000000

    # sq_ring.flags
    assert IORING_SQ_NEED_WAKEUP == 1 << 0
    assert IORING_SQ_CQ_OVERFLOW == 1 << 1
    assert IORING_SQ_TASKRUN == 1 << 2

    # cq_ring.flags
    assert IORING_CQ_EVENTFD_DISABLED == 1 << 0

    # io_uring_enter(2) flags
    assert IORING_ENTER_GETEVENTS == 1 << 0
    assert IORING_ENTER_SQ_WAKEUP == 1 << 1
    assert IORING_ENTER_SQ_WAIT == 1 << 2
    assert IORING_ENTER_EXT_ARG == 1 << 3
    assert IORING_ENTER_REGISTERED_RING == 1 << 4
    assert IORING_ENTER_ABS_TIMER == 1 << 5
    assert IORING_ENTER_EXT_ARG_REG == 1 << 6
    assert IORING_ENTER_NO_IOWAIT == 1 << 7

    # io_uring_params->features flags
    assert IORING_FEAT_SINGLE_MMAP == 1 << 0
    assert IORING_FEAT_NODROP == 1 << 1
    assert IORING_FEAT_SUBMIT_STABLE == 1 << 2
    assert IORING_FEAT_RW_CUR_POS == 1 << 3
    assert IORING_FEAT_CUR_PERSONALITY == 1 << 4
    assert IORING_FEAT_FAST_POLL == 1 << 5
    assert IORING_FEAT_POLL_32BITS == 1 << 6
    assert IORING_FEAT_SQPOLL_NONFIXED == 1 << 7
    assert IORING_FEAT_EXT_ARG == 1 << 8
    assert IORING_FEAT_NATIVE_WORKERS == 1 << 9
    assert IORING_FEAT_RSRC_TAGS == 1 << 10
    assert IORING_FEAT_CQE_SKIP == 1 << 11
    assert IORING_FEAT_LINKED_FILE == 1 << 12
    assert IORING_FEAT_REG_REG_RING == 1 << 13
    assert IORING_FEAT_RECVSEND_BUNDLE == 1 << 14
    assert IORING_FEAT_MIN_TIMEOUT == 1 << 15
    assert IORING_FEAT_RW_ATTR == 1 << 16
    assert IORING_FEAT_NO_IOWAIT == 1 << 17

    assert IORING_MEM_REGION_TYPE_USER == 1
    assert IORING_MEM_REGION_REG_WAIT_ARG == 1

    assert IOU_PBUF_RING_MMAP == 1
    assert IOU_PBUF_RING_INC == 2

    assert IORING_RSRC_REGISTER_SPARSE == 1 << 0

    assert IORING_REGISTER_FILES_SKIP == -2
    assert IO_URING_OP_SUPPORTED == 1 << 0

    assert IORING_REGISTER_SRC_REGISTERED == 1 << 0
    assert IORING_REGISTER_DST_REPLACE == 1 << 1

    assert IORING_REG_WAIT_TS == 1 << 0
