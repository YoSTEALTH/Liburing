//! Liburing - io_uring related functions
const c = @import("c.zig").c;
const e = @import("error.zig");
const oz = @import("PyOZ");
const std = @import("std");
const class = @import("class.zig");
const Statx = @import("statx.zig").Statx;
const Sockaddr = @import("socket.zig").Sockaddr;

const AT_FDCWD = std.os.linux.AT.FDCWD;

const IntStr = union(enum) {
    Int: *c_int,
    Str: []u8,
};

// TODO: const sigset_t = std.posix.sigset_t;

const SyncCancelReg = class.SyncCancelReg;
const ClockRegister = class.ClockRegister;
const MemRegionReg = class.MemRegionReg;
const Restriction = class.Restriction;
const EpollEvent = class.EpollEvent;
const RecvmsgOut = class.RecvmsgOut;
const ZcrxIfqReg = class.ZcrxIfqReg;
const Timespec = class.Timespec;
const RegWait = class.RegWait;
const SigsetT = class.SigsetT;
const BufRing = class.BufRing;
const CqeIter = class.CqeIter;
const Cmsghdr = class.Cmsghdr;
const OpenHow = class.OpenHow;
const Msghdr = class.Msghdr;
const BufReg = class.BufReg;
const Iovec = class.Iovec;
const Probe = class.Probe;
const Param = class.Param;
const Napi = class.Napi;
const Ring = class.Ring;
const CQE = class.CQE;
const Cqe = class.Cqe;
const SQE = class.SQE;
const Sqe = class.Sqe;
const Bpf = class.Bpf;

pub const Functions = .{
    oz.func("io_uring_get_probe_ring", getProbeRing, getProbeRingDoc),
    oz.func("io_uring_get_probe", getProbe, getProbeDoc),
    oz.func("io_uring_free_probe", freeProbe, freeProbeDoc),
    oz.func("io_uring_opcode_supported", opcodeSupported, opcodeSupportedDoc),
    oz.func("io_uring_queue_init_mem", queueInitMem, queueInitMemDoc),
    oz.func("io_uring_queue_init_params", queueInitParams, queueInitParamsDoc),
    oz.kwfunc("io_uring_queue_init", queueInit, queueInitDoc),
    oz.func("io_uring_queue_mmap", queueMmap, queueMmapDoc),
    oz.func("io_uring_ring_dontfork", ringDontfork, ringDontforkDoc),
    oz.func("io_uring_queue_exit", queueExit, queueExitDoc),
    oz.func("io_uring_peek_batch_cqe", peekBatchCqe, peekBatchCqeDoc),
    oz.kwfunc("io_uring_wait_cqes", waitCqes, waitCqesDoc),
    oz.func("io_uring_wait_cqes_min_timeout", waitCqesMinTimeout, waitCqesMinTimeoutDoc),
    oz.func("io_uring_wait_cqe_timeout", waitCqeTimeout, waitCqeTimeoutDoc),
    oz.func("io_uring_submit", submit, submitDoc),
    oz.func("io_uring_submit_and_wait", submitWait, submitWaitDoc),
    oz.kwfunc("io_uring_submit_and_wait_timeout", submitWaitTimeout, submitWaitTimeoutDoc),
    oz.func("io_uring_submit_and_wait_min_timeout", submitWaitMinTimeout, submitWaitMinTimeoutDoc),
    oz.func("io_uring_submit_and_wait_reg", submitWaitReg, submitWaitRegDoc),
    oz.func("io_uring_register_wait_reg", registerWaitReg, registerWaitRegDoc),

    oz.func("io_uring_resize_rings", resieRings, resieRingsDoc),
    oz.kwfunc("io_uring_clone_buffers_offset", cloneBuffersOffset, cloneBuffersOffsetDoc),
    oz.kwfunc("io_uring_clone_buffers", cloneBuffers, cloneBuffersDoc),
    oz.kwfunc("io_uring_register_buffers", registerBuffers, registerBuffersDoc), // io_uring_register_buffers_tags
    oz.func("io_uring_register_buffers_sparse", registerBuffersSparse, registerBuffersSparseDoc),
    oz.func("io_uring_register_buffers_update_tag", registerBuffersUpdateTag, registerBuffersUpdateTagDoc),
    oz.func("io_uring_unregister_buffers", unregisterBuffers, unregisterBuffersDoc),
    oz.kwfunc("io_uring_register_files", registerFiles, registerFilesDoc), // io_uring_register_files_tags
    oz.func("io_uring_register_files_sparse", registerFilesSparse, registerFilesSparseDoc),
    oz.func("io_uring_register_files_update_tag", registerFilesUpdateTag, registerFilesUpdateTagDoc),
    oz.func("io_uring_unregister_files", unregisterFiles, unregisterFilesDoc),
    oz.func("io_uring_register_files_update", registerFilesUpdate, registerFilesUpdateDoc),
    oz.func("io_uring_register_eventfd", registerEventFd, registerEventFdDoc),
    oz.func("io_uring_register_eventfd_async", registerEventFdAsync, registerEventFdAsyncDoc),
    oz.func("io_uring_unregister_eventfd", unregisterEventFd, unregisterEventFdDoc),
    oz.func("io_uring_register_probe", registerProbe, registerProbeDoc),
    oz.func("io_uring_register_personality", registerPersonality, registerPersonalityDoc),
    oz.func("io_uring_unregister_personality", unregisterPersonality, unregisterPersonalityDoc),
    oz.func("io_uring_register_restrictions", registerRestrictions, registerRestrictionsDoc),
    oz.func("io_uring_enable_rings", enableRings, enableRingsDoc),

    // TODO:
    // __io_uring_sqring_wait ???
    // io_uring_register_iowq_aff ??? _GNU_SOURCE ???
    // io_uring_unregister_iowq_aff ???
    // io_uring_register_iowq_max_workers ???

    oz.func("io_uring_register_ring_fd", registerRingFd, registerRingFdDoc),
    oz.func("io_uring_unregister_ring_fd", unregisterRingFd, unregisterRingFdDoc),
    oz.func("io_uring_close_ring_fd", closeRingFd, closeRingFdDoc),
    oz.kwfunc("io_uring_register_buf_ring", registerBufRing, registerBufRingDoc),
    oz.func("io_uring_unregister_buf_ring", unregisterBufRing, unregisterBufRingDoc),
    oz.func("io_uring_buf_ring_head", bufRingHead, bufRingHeadDoc),
    oz.func("io_uring_register_sync_cancel", registerSyncCancel, registerSyncCancelDoc),
    oz.func("io_uring_register_sync_msg", registerSyncMsg, registerSyncMsgDoc),
    oz.func("io_uring_register_file_alloc_range", registerFileAllocRange, registerFileAllocRangeDoc),
    oz.func("io_uring_register_napi", registerNapi, registerNapiDoc),
    oz.func("io_uring_unregister_napi", unregisterNapi, unregisterNapiDoc),
    oz.func("io_uring_register_ifq", registerIfq, registerIfqDoc),
    oz.func("io_uring_register_clock", registerClock, registerClockDoc),
    oz.func("io_uring_register_bpf_filter", registerBpfFilter, registerBpfFilterDoc),
    oz.func("io_uring_register_bpf_filter_task", registerBpfFilterTask, registerBpfFilterTaskDoc),
    oz.func("io_uring_get_events", getEvents, getEventsDoc),
    oz.func("io_uring_submit_and_get_events", submitAndGetEvents, submitAndGetEventsDoc),
    // oz.func("io_uring_enter", enter, enterDoc),
    // oz.func("io_uring_enter2", enter2, enter2Doc),
    // oz.func("io_uring_setup", setup, setupDoc),
    // oz.func("io_uring_register", register, registerDoc),
    oz.func("io_uring_register_region", registerRegion, registerRegionDoc),
    oz.func("io_uring_setup_buf_ring", setupBufRing, setupBufRingDoc),
    oz.func("io_uring_free_buf_ring", freeBufRing, freeBufRingDoc),

    // __io_uring_get_cqe???

    oz.func("io_uring_set_iowait", setIoWait, setIoWaitDoc),

    // Ignoring internal functions
    // - io_uring_cqe_shift_from_flags
    // - io_uring_cqe_shift
    // - io_uring_cqe_nr (annoying bug)

    oz.func("io_uring_cqe_iter_init", cqeIterInit, cqeIterInitDoc),
    oz.func("io_uring_cqe_iter_next", cqeIterNext, cqeIterNextDoc),

    // Ignoring
    // - io_uring_for_each_cqe (outdated C function) use above iter functions

    oz.func("io_uring_cq_advance", cqAdvance, cqAdvanceDoc),
    oz.func("io_uring_cqe_seen", cqeSeen, cqeSeenDoc),

    //
    // Command prep helpers
    //

    oz.func("io_uring_sqe_set_data", setData, setDataDoc),
    oz.func("io_uring_cqe_get_data", getData, getDataDoc),
    oz.func("io_uring_sqe_set_data64", setData64, setData64Doc),
    oz.func("io_uring_cqe_get_data64", getData64, getData64Doc),
    oz.func("io_uring_sqe_set_flags", sqeSetFlags, sqeSetFlagsDoc),
    oz.func("io_uring_sqe_set_buf_group", sqeSetBufGroup, sqeSetBufGroupDoc),

    // internal functions:
    //      __io_uring_set_target_fixed_file
    //      io_uring_initialize_sqe
    //      io_uring_prep_rw

    oz.func("io_uring_prep_splice", prepSplice, prepSpliceDoc),
    oz.func("io_uring_prep_tee", prepTee, prepTeeDoc),
    oz.kwfunc("io_uring_prep_readv", prepReadV, prepReadVDoc),
    oz.func("io_uring_prep_read_fixed", prepReadFixed, prepReadFixedDoc),
    oz.func("io_uring_prep_readv_fixed", prepReadVFixed, prepReadVFixedDoc),
    oz.func("io_uring_prep_writev", prepWriteV, prepWriteVDoc),
    oz.func("io_uring_prep_write_fixed", prepWriteFixed, prepWriteFixedDoc),
    oz.func("io_uring_prep_writev_fixed", prepWriteVFixed, prepWriteVFixedDoc),

    oz.kwfunc("io_uring_prep_recvmsg", prepRecvmsg, prepRecvmsgDoc),
    oz.func("io_uring_prep_recvmsg_multishot", prepRecvmsgMultishot, prepRecvmsgMultishotDoc),
    oz.func("io_uring_prep_sendmsg", prepSendmsg, prepSendmsgDoc),
    oz.func("io_uring_prep_poll_add", prepPollAdd, prepPollAddDoc),
    oz.func("io_uring_prep_poll_multishot", prepPollMultishot, prepPollMultishotDoc),
    oz.func("io_uring_prep_poll_remove", prepPollRemove, prepPollRemoveDoc),
    oz.kwfunc("io_uring_prep_poll_update", prepPollUpdate, prepPollUpdateDoc),
    oz.kwfunc("io_uring_prep_fsync", prepFsync, prepFsyncDoc),

    oz.func("io_uring_prep_nop", prepNop, prepNopDoc),

    oz.func("io_uring_prep_nop128", prepNop128, prepNop128Doc),
    oz.kwfunc("io_uring_prep_timeout", prepTimeout, prepTimeoutDoc),
    oz.kwfunc("io_uring_prep_timeout_remove", prepTimeoutRemove, prepTimeoutRemoveDoc),
    oz.kwfunc("io_uring_prep_timeout_update", prepTimeoutUpdate, prepTimeoutUpdateDoc),
    oz.kwfunc("io_uring_prep_accept", prepAccept, prepAcceptDoc),
    oz.kwfunc("io_uring_prep_accept_direct", prepAcceptDirect, prepAcceptDirectDoc),
    oz.kwfunc("io_uring_prep_multishot_accept", prepMultishotAccept, prepMultishotAcceptDoc),
    oz.kwfunc("io_uring_prep_multishot_accept_direct", prepMultishotAcceptDirect, prepMultishotAcceptDirectDoc),
    oz.kwfunc("io_uring_prep_cancel64", prepCancel64, prepCancel64Doc),
    oz.kwfunc("io_uring_prep_cancel", prepCancel, prepCancelDoc),
    oz.kwfunc("io_uring_prep_cancel_fd", prepCancelFd, prepCancelFdDoc),
    oz.func("io_uring_prep_link_timeout", prepLinkTimeout, prepLinkTimeoutDoc),
    oz.func("io_uring_prep_connect", prepConnect, prepConnectDoc),
    oz.func("io_uring_prep_bind", prepBind, prepBindDoc),
    oz.func("io_uring_prep_listen", prepListen, prepListenDoc),
    oz.kwfunc("io_uring_prep_epoll_wait", prepEpollWait, prepEpollWaitDoc),
    oz.kwfunc("io_uring_prep_files_update", prepFilesUpdate, prepFilesUpdateDoc),
    oz.func("io_uring_prep_fallocate", prepFallocate, prepFallocateDoc),
    oz.kwfunc("io_uring_prep_open", prepOpen, prepOpenDoc), // io_uring_prep_openat
    oz.kwfunc("io_uring_prep_open_direct", prepOpenDirect, prepOpenDirectDoc), // io_uring_prep_openat_direct
    oz.func("io_uring_prep_close", prepClose, prepCloseDoc),
    oz.func("io_uring_prep_close_direct", prepCloseDirect, prepCloseDirectDoc),
    oz.kwfunc("io_uring_prep_read", prepRead, prepReadDoc),
    oz.kwfunc("io_uring_prep_read_multishot", prepReadMultishot, prepReadMultishotDoc),
    oz.kwfunc("io_uring_prep_write", prepWrite, prepWriteDoc),
    oz.kwfunc("io_uring_prep_statx", prepStatx, prepStatxDoc),
    oz.kwfunc("io_uring_prep_fadvise", prepFadvise, prepFadviseDoc),
    oz.func("io_uring_prep_madvise", prepMadvise, prepMadviseDoc),
    oz.kwfunc("io_uring_prep_fadvise64", prepFadvise64, prepFadvise64Doc),
    oz.func("io_uring_prep_madvise64", prepMadvise64, prepMadvise64Doc),

    oz.kwfunc("io_uring_prep_send", prepSend, prepSendDoc),
    oz.kwfunc("io_uring_prep_send_bundle", prepSendBundle, prepSendBundleDoc),
    oz.func("io_uring_prep_send_set_addr", prepSendSetAddr, prepSendSetAddrDoc),
    oz.kwfunc("io_uring_prep_sendto", prepSendto, prepSendtoDoc),
    oz.kwfunc("io_uring_prep_send_zc", prepSendZc, prepSendZcDoc),
    oz.kwfunc("io_uring_prep_send_zc_fixed", prepSendZcFixed, prepSendZcFixedDoc),
    oz.kwfunc("io_uring_prep_sendmsg_zc", prepSendmsgZc, prepSendmsgZcDoc),
    oz.kwfunc("io_uring_prep_sendmsg_zc_fixed", prepSendmsgZcFixed, prepSendmsgZcFixedDoc),
    oz.kwfunc("io_uring_prep_recv", prepRecv, prepRecvDoc),
    oz.kwfunc("io_uring_prep_recv_multishot", prepRecvMultishot, prepRecvMultishotDoc),
    oz.func("io_uring_recvmsg_validate", recvmsgValidate, recvmsgValidateDoc),
    oz.func("io_uring_recvmsg_name", recvmsgName, recvmsgNameDoc),
    oz.func("io_uring_recvmsg_cmsg_firsthdr", recvmsgCmsgFirsthdr, recvmsgCmsgFirsthdrDoc),
    oz.func("io_uring_recvmsg_cmsg_nexthdr", recvmsgCmsgNexthdr, recvmsgCmsgNexthdrDoc),
    oz.func("io_uring_recvmsg_payload", recvmsgPayload, recvmsgPayloadDoc),
    oz.func("io_uring_recvmsg_payload_length", recvmsgPayloadLength, recvmsgPayloadLengthDoc),
    oz.kwfunc("io_uring_prep_openat2", prepOpenat2, prepOpenat2Doc),
    oz.kwfunc("io_uring_prep_openat2_direct", prepOpenat2Direct, prepOpenat2DirectDoc),
    oz.func("io_uring_prep_epoll_ctl", prepEpollCtl, prepEpollCtlDoc),
    oz.func("io_uring_prep_provide_buffers", prepProvideBuffers, prepProvideBuffersDoc),
    oz.func("io_uring_prep_remove_buffers", prepRemoveBuffers, prepRemoveBuffersDoc),
    oz.func("io_uring_prep_shutdown", prepShutdown, prepShutdownDoc),
    oz.kwfunc("io_uring_prep_unlink", prepUnlink, prepUnlinkDoc),
    oz.func("io_uring_prep_rename", prepRename, prepRenameDoc), // io_uring_prep_renameat
    oz.kwfunc("io_uring_prep_sync_file_range", prepSyncFileRange, prepSyncFileRangeDoc),
    oz.kwfunc("io_uring_prep_mkdir", prepMkdir, prepMkdirDoc), // io_uring_prep_mkdirat
    oz.func("io_uring_prep_symlink", prepSymlink, prepSymlinkDoc), // io_uring_prep_symlinkat
    oz.func("io_uring_prep_link", prepLink, prepLinkDoc), // io_uring_prep_linkat
    oz.func("io_uring_prep_msg_ring_cqe_flags", prepMsgRingCqeFlags, prepMsgRingCqeFlagsDoc),
    oz.kwfunc("io_uring_prep_msg_ring", prepMsgRing, prepMsgRingDoc),
    oz.kwfunc("io_uring_prep_msg_ring_fd", prepMsgRingFd, prepMsgRingFdDoc),
    oz.kwfunc("io_uring_prep_msg_ring_fd_alloc", prepMsgRingFdAlloc, prepMsgRingFdAllocDoc),
    oz.func("io_uring_prep_getxattr", prepGetxattr, prepGetxattrDoc),
    oz.func("io_uring_prep_setxattr", prepSetxattr, prepSetxattrDoc),
    oz.func("io_uring_prep_fgetxattr", prepFgetxattr, prepFgetxattrDoc),
    oz.func("io_uring_prep_fsetxattr", prepFsetxattr, prepFsetxattrDoc),

    oz.kwfunc("io_uring_prep_socket", prepSocket, prepSocketDoc),
    oz.kwfunc("io_uring_prep_socket_direct", prepSocketDirect, prepSocketDirectDoc), // io_uring_prep_socket_direct_alloc
    oz.func("io_uring_prep_uring_cmd", prepUringCmd, prepUringCmdDoc),
    oz.func("io_uring_prep_uring_cmd128", prepUringCmd128, prepUringCmd128Doc),
    oz.func("io_uring_prep_cmd_sock", prepCmdSock, prepCmdSockDoc), // TODO: fix the way this works
    // oz.func("io_uring_prep_cmd_getsockname", prepCmdGetsockname, prepCmdGetsocknameDoc), // TODO
    oz.kwfunc("io_uring_prep_waitid", prepWaitid, prepWaitidDoc),
    // oz.func("io_uring_prep_futex_wake", prepFutexWake, prepFutexWakeDoc),
    // oz.func("io_uring_prep_futex_wait", prepFutexWait, prepFutexWaitDoc),
    // oz.func("io_uring_prep_futex_waitv", prepFutexWaitv, prepFutexWaitvDoc),
    oz.kwfunc("io_uring_prep_fixed_fd_install", prepFixedFdInstall, prepFixedFdInstallDoc),
    oz.func("io_uring_prep_ftruncate", prepFtruncate, prepFtruncateDoc),
    oz.func("io_uring_prep_cmd_discard", prepCmdDiscard, prepCmdDiscardDoc),
    oz.func("io_uring_prep_pipe", prepPipe, prepPipeDoc),
    oz.func("io_uring_prep_pipe_direct", prepPipeDirect, prepPipeDirectDoc),
    oz.func("io_uring_load_sq_head", loadSqHead, loadSqHeadDoc),

    oz.func("io_uring_sq_ready", sqReady, sqReadyDoc),
    oz.func("io_uring_sq_space_left", sqSpaceLeft, sqSpaceLeftDoc),
    oz.func("io_uring_sqe_shift_from_flags", sqeShiftFromFlags, sqeShiftFromFlagsDoc),
    oz.func("io_uring_sqe_shift", sqeShift, sqeShiftDoc),
    oz.func("io_uring_sqring_wait", sqringWait, sqringWaitDoc),
    oz.func("io_uring_cq_ready", cqReady, cqReadyDoc),
    oz.func("io_uring_cq_has_overflow", cqHasOverflow, cqHasOverflowDoc),
    oz.func("io_uring_cq_eventfd_enabled", cqEventfdEnabled, cqEventfdEnabledDoc),
    oz.func("io_uring_cq_eventfd_toggle", cqEventfdToggle, cqEventfdToggleDoc),
    oz.func("io_uring_wait_cqe_nr", waitCqeNr, waitCqeNrDoc),
    oz.func("io_uring_peek_cqe", peekCqe, peekCqeDoc),
    oz.func("io_uring_wait_cqe", waitCqe, waitCqeDoc),
    oz.func("io_uring_buf_ring_mask", bufRingMask, bufRingMaskDoc),
    oz.func("io_uring_buf_ring_init", bufRingInit, bufRingInitDoc),
    oz.kwfunc("io_uring_buf_ring_add", bufRingAdd, bufRingAddDoc),
    oz.func("io_uring_buf_ring_advance", bufRingAdvance, bufRingAdvanceDoc),
    oz.func("io_uring_buf_ring_cq_advance", bufRingCqAdvance, bufRingCqAdvanceDoc),
    oz.func("io_uring_buf_ring_available", bufRingAvailable, bufRingAvailableDoc),
    oz.func("io_uring_get_sqe", getSqe, getSqeDoc),
    // TODO: ???
    // oz.func("io_uring_get_sqe128", getSqe128, getSqe128Doc),

    oz.func("liburing_version_major", liburingVersionMajor, liburingVersionMajorDoc),
    oz.func("liburing_version_minor", liburingVersionMinor, liburingVersionMinorDoc),
    oz.func("liburing_version_check", liburingVersionCheck, liburingVersionCheckDoc),
};

const getProbeRingDoc =
    \\>>> probe = io_uring_get_probe_ring(ring)
    \\... ...
    \\>>> io_uring_free_probe(probe)
    \\
    \\Note
    \\    - Don't forget to call `io_uring_free_probe(probe)` after you are done with `probe`.
; // io_uring_get_probe_ring
fn getProbeRing(ring: *Ring) ?Probe {
    if (c.io_uring_get_probe_ring(ring._io_uring)) |p| {
        return .{ ._io_uring_probe = p };
        // return .{ ._parent = .{ ._probe = p }, ._len = 1, ._io_uring_probe = p };
        // return .{ ._parent = .{._probe = @ptrCast(p[0])}, ._len=1, ._io_uring_probe = p };
    }
    return oz.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe_ring()`");
}

const getProbeDoc =
    \\>>> io_uring_get_probe()
; // io_uring_get_probe
fn getProbe() ?Probe {
    if (c.io_uring_get_probe()) |p| return .{ ._io_uring_probe = p };
    return oz.raiseRuntimeError("Linux kernel version does not support `io_uring_get_probe()`");
}

const freeProbeDoc =
    \\>>> io_uring_free_probe(probe)
; // io_uring_free_probe
fn freeProbe(probe: *Probe) void {
    if (probe._io_uring_probe) |p| {
        c.io_uring_free_probe(p);
        probe._io_uring_probe = null;
    }
}

const opcodeSupportedDoc =
    \\>>> io_uring_opcode_supported(probe, op)
    \\ True # or False
; // io_uring_opcode_supported
fn opcodeSupported(probe: *Probe, op: i32) bool {
    return (c.io_uring_opcode_supported(probe._io_uring_probe, op) == 1);
}

const queueInitMemDoc =
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_queue_init_mem
fn queueInitMem(entries: u32, ring: *Ring, p: *Param, buf: ?*anyopaque, buf_size: usize) ?i32 {
    return e.trapError(c.io_uring_queue_init_mem(entries, ring._io_uring, p._io_uring_params, buf, buf_size));
}

const queueInitParamsDoc =
    \\TODO 
; // io_uring_queue_init_params
fn queueInitParams(entries: u32, ring: *Ring, param: *Param) ?i32 {
    return e.trapError(c.io_uring_queue_init_params(entries, ring._io_uring, param._io_uring_params));
}

const queueInitDoc =
    \\ Setup `io_uring` Submission & Completion Queues
    \\
    \\ Example
    \\     >>> ring = io_uring()
    \\     >>> try:
    \\     ...     io_uring_queue_init(1024, ring)
    \\     ...     # do stuff ...
    \\     >>> finally:
    \\     ...     io_uring_queue_exit(ring)
; // io_uring_queue_init
fn queueInit(entries: u32, ring: *Ring, flags: ?u32) ?i32 {
    if (ring._io_uring) |io_uring| {
        if (io_uring.ring_fd > 0) return oz.raiseRuntimeError("`io_uring_queue_init(ring)` already initialized!");
        return e.trapError(c.io_uring_queue_init(entries, io_uring, flags orelse 0));
    }
    return oz.raiseRuntimeError("`ring = io_uring()` not initialized!");
}

const queueMmapDoc =
    \\>>> io_uring_queue_mmap(fd, param, ring)
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_queue_mmap
fn queueMmap(fd: i32, ring: *Ring, param: *Param) ?i32 {
    return e.trapError(c.io_uring_queue_mmap(fd, @ptrCast(ring._io_uring), @ptrCast(param._io_uring_params)));
}

const ringDontforkDoc =
    \\>>> io_uring_ring_dontfork(ring)
; // io_uring_ring_dontfork
fn ringDontfork(ring: *Ring) ?i32 {
    // note: currently there is no `test` or `man` page for `io_uring_ring_dontfork` so guessing how it should work!
    return e.trapError(c.io_uring_ring_dontfork(ring._io_uring));
}

const queueExitDoc =
    \\>>> io_uring_queue_exit(ring)
; // io_uring_queue_exit
fn queueExit(ring: *Ring) ?void {
    if (ring._io_uring) |io_uring| {
        if (io_uring.ring_fd > 0) {
            c.io_uring_queue_exit(io_uring);
            io_uring.ring_fd = 0;
            return;
        }
    }
    return oz.raiseRuntimeError("`io_uring_queue_exit(ring)` not initialized or already exited!");
}

const peekBatchCqeDoc =
    \\Example
    \\    >>> cqe = io_uring_cqe(1024) # custom memory
    \\    ...
    \\    >>> io_uring_peek_batch_cqe(ring, cqe, 1024)
    \\    123
    \\
    \\Warning
    \\    - Don't use this function, till this warning is removed or else its most likely segfault!!!
; // io_uring_peek_batch_cqe
fn peekBatchCqe(_: *Ring, _: *Cqe, _: u32) ?void {
    return oz.raiseNotImplementedError("`io_uring_peek_batch_cqe` is fully implemented yet!");
    // TODO:
    // fn peekBatchCqe(ring: *Ring, cqe: *Cqe, count: u32) ?void {
    // if (cqe._array) |_| return c.io_uring_peek_batch_cqe(ring._io_uring, &cqe._io_uring_cqe, count);
}

const waitCqesDoc =
    \\Example
    \\    >>> io_uring_wait_cqes(ring, cqe, 123)
    \\    # or
    \\    >>> ts = timespec(1.5)  # timeout
    \\    >>>io_uring_wait_cqes(ring, cqe, 123, ts)
; // io_uring_wait_cqes
fn waitCqes(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) ?i32 {
    const _sigmask = null; // TODO'
    const _ts = if (ts) |t| t._timespec else null;
    return e.trapError(c.io_uring_wait_cqes(ring._io_uring, &cqe._io_uring_cqe, wait_nr, _ts, _sigmask));
}

const waitCqesMinTimeoutDoc =
    \\>>> io_uring_wait_cqes_min_timeout(ring)
; // io_uring_wait_cqes_min_timeout
fn waitCqesMinTimeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_ts_usec: u32) ?i32 {
    const _sigmask = null; // TODO
    return e.trapError(c.io_uring_wait_cqes_min_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        ts._timespec,
        min_ts_usec,
        _sigmask,
    ));
}

const waitCqeTimeoutDoc =
    \\>>> ts = timespec(1.5)  # timeout
    \\>>> io_uring_wait_cqe_timeout(ring, cqe, ts)
; // io_uring_wait_cqe_timeout
fn waitCqeTimeout(ring: *Ring, cqe: *Cqe, ts: *Timespec) ?i32 {
    return e.trapError(c.io_uring_wait_cqe_timeout(ring._io_uring, &cqe._io_uring_cqe, ts._timespec));
}

const submitDoc =
    \\>>> io_uring_submit(ring)
    \\123
; // io_uring_submit
pub fn submit(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_submit(ring._io_uring));
}

const submitWaitDoc =
    \\>>> io_uring_submit_and_wait(ring, 123)
; // io_uring_submit_and_wait
fn submitWait(ring: *Ring, wait_nr: u32) ?i32 {
    return e.trapError(c.io_uring_submit_and_wait(ring._io_uring, wait_nr));
}

const submitWaitTimeoutDoc =
    \\>>> io_uring_submit_and_wait_timeout(ring, cqe, 1)
    \\# or
    \\>>> ts = timespec(0.5)
    \\>>> io_uring_submit_and_wait_timeout(ring, cqe, 1, ts)
; // io_uring_submit_and_wait_timeout
fn submitWaitTimeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: ?*Timespec) ?i32 {
    const _sigmask = null; // TODO
    const _ts = if (ts) |t| t._timespec else null;
    return e.trapError(c.io_uring_submit_and_wait_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        _ts,
        _sigmask,
    ));
}

const submitWaitMinTimeoutDoc =
    \\>>> TODO
; // io_uring_submit_and_wait_min_timeout
fn submitWaitMinTimeout(ring: *Ring, cqe: *Cqe, wait_nr: u32, ts: *Timespec, min_wait: u32) ?i32 {
    const _sigmask = null; // TODO

    return e.trapError(c.io_uring_submit_and_wait_min_timeout(
        ring._io_uring,
        &cqe._io_uring_cqe,
        wait_nr,
        ts._timespec,
        min_wait,
        _sigmask,
    ));
}

const submitWaitRegDoc =
    \\>>> TODO
; // io_uring_submit_and_wait_reg
fn submitWaitReg(ring: *Ring, cqe: *Cqe, wait_nr: u32, reg_index: i32) ?i32 {
    return e.trapError(c.io_uring_submit_and_wait_reg(ring._io_uring, &cqe._io_uring_cqe, wait_nr, reg_index));
}

const registerWaitRegDoc =
    \\>>> TODO
; // io_uring_register_wait_reg
fn registerWaitReg(ring: *Ring, reg: *RegWait, nr: i32) ?i32 {
    return e.trapError(c.io_uring_register_wait_reg(ring._io_uring, reg._io_uring_reg_wait, nr));
}

const resieRingsDoc =
    \\TODO
; // io_uring_resize_rings
fn resieRings(ring: *Ring, p: *Param) ?i32 {
    return e.trapError(c.io_uring_resize_rings(ring._io_uring, p._io_uring_params));
}

const cloneBuffersOffsetDoc =
    \\TODO
; // io_uring_clone_buffers_offset
fn cloneBuffersOffset(
    dst_ring: *Ring,
    src_ring: *Ring,
    dst_off: c_uint,
    src_off: c_uint,
    nr: c_uint,
    flags: ?c_uint,
) ?i32 {
    const _flags = flags orelse 0;
    return e.trapError(c.io_uring_clone_buffers_offset(
        dst_ring._io_uring,
        src_ring._io_uring,
        dst_off,
        src_off,
        nr,
        _flags,
    ));
}

const cloneBuffersDoc =
    \\TODO
; // io_uring_clone_buffers
fn cloneBuffers(dst_ring: *Ring, src_ring: *Ring, flags: ?c_uint) ?i32 {
    const _flags = flags orelse 0;
    return e.trapError(c.__io_uring_clone_buffers(dst_ring._io_uring, src_ring._io_uring, _flags));
}

const registerBuffersDoc =
    \\TODO
; // io_uring_register_buffers & io_uring_register_buffers_tags
fn registerBuffers(ring: *Ring, iovecs: *const Iovec, tags: ?u64) ?i32 {
    const _tags = if (tags) |t| t else 0;
    return e.trapError(c.io_uring_register_buffers_tags(ring._io_uring, iovecs._iovec, _tags, @intCast(iovecs._len)));
}

const registerBuffersSparseDoc =
    \\TODO
; // io_uring_register_buffers_sparse
fn registerBuffersSparse(ring: *Ring, nr: u32) ?i32 {
    return e.trapError(c.io_uring_register_buffers_sparse(ring._io_uring, nr));
}

const registerBuffersUpdateTagDoc =
    \\TODO
; // io_uring_register_buffers_update_tag
fn registerBuffersUpdateTag(ring: *Ring, off: u32, iovecs: *const Iovec, tags: *const u64) ?i32 {
    return e.trapError(c.io_uring_register_buffers_update_tag(
        ring._io_uring,
        off,
        iovecs._iovec,
        tags,
        @intCast(iovecs._len),
    ));
}

const unregisterBuffersDoc =
    \\TODO
; // io_uring_unregister_buffers
fn unregisterBuffers(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_unregister_buffers(ring._io_uring));
}

const registerFilesDoc =
    \\Register File Descriptor
    \\
    \\Example
    \\    >>> fds = [1, 2, 3]
    \\    >>> io_uring_register_files(ring, fds)
    \\    ...
    \\    >>> io_uring_unregister_files(ring)
    \\
    \\Note
    \\    - Hold on to `fds` reference till the submit + wait process is done.
    \\    - "Registered files have less overhead per operation than normal files.
    \\    This is due to the kernel grabbing a reference count on a file when an
    \\    operation begins, and dropping it when it's done. When the process file
    \\    table is shared, for example if the process has ever created any
    \\    threads, then this cost goes up even more. Using registered files
    \\    reduces the overhead of file reference management across requests that
    \\    operate on a file."
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_register_files & io_uring_register_files_tags
fn registerFiles(ring: *Ring, files: oz.ListView(i32), tags: ?u64) ?i32 {
    const _tags: u64 = if (tags) |t| t else 0;
    return e.trapError(c.io_uring_register_files_tags(
        ring._io_uring,
        @ptrCast(files.py_list),
        _tags,
        @intCast(files.len()),
    ));
} // TODO: not sure if this works! needs to be tested
// fn registerFiles(ring: *Ring, files: oz.ListView(i32), tags: ?u64) ?i32 {
//     const _tags: u64 = if (tags) |t| t else 0;
//     const _len = files.len();
//     const _data = oz.py.c.PyList_GetSlice(files.py_list, 0, @intCast(_len));

//     return e.trapError(c.io_uring_register_files_tags(
//         ring._io_uring,
//         @ptrCast(_data),
//         _tags,
//         @intCast(_len),
//     ));
// } // TODO: not sure if this works! needs to be tested

const registerFilesSparseDoc =
    \\TODO
; // io_uring_register_files_sparse
fn registerFilesSparse(ring: *Ring, nr: u32) ?i32 {
    return e.trapError(c.io_uring_register_files_sparse(ring._io_uring, nr));
}

const registerFilesUpdateTagDoc =
    \\TODO
; // io_uring_register_files_update_tag
fn registerFilesUpdateTag(ring: *Ring, off: u32, files: oz.ListView(i32), tags: *const u64) ?i32 {
    return e.trapError(
        c.io_uring_register_files_update_tag(ring._io_uring, off, @ptrCast(files.py_list), tags, @intCast(files.len())),
    );
}

const unregisterFilesDoc =
    \\>>> io_uring_unregister_files(ring)
; // io_uring_unregister_files
fn unregisterFiles(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_unregister_files(ring._io_uring));
}

const registerFilesUpdateDoc =
    \\TODO
; // io_uring_register_files_update
fn registerFilesUpdate(ring: *Ring, off: u32, files: oz.ListView(i32)) ?i32 {
    return e.trapError(c.io_uring_register_files_update(
        ring._io_uring,
        off,
        @ptrCast(files.py_list),
        @intCast(files.len()),
    ));
}

const registerEventFdDoc =
    \\>>> io_uring_register_eventfd(fd)
; // io_uring_register_eventfd
fn registerEventFd(ring: *Ring, fd: i32) ?i32 {
    return e.trapError(c.io_uring_register_eventfd(ring._io_uring, fd));
}

const registerEventFdAsyncDoc =
    \\>>> io_uring_register_eventfd_async(fd)
; // io_uring_register_eventfd_async
fn registerEventFdAsync(ring: *Ring, fd: i32) ?i32 {
    return e.trapError(c.io_uring_register_eventfd_async(ring._io_uring, fd));
}

const unregisterEventFdDoc =
    \\>>> io_uring_unregister_eventfd(ring)
; // io_uring_unregister_eventfd
fn unregisterEventFd(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_unregister_eventfd(ring._io_uring));
}

const registerProbeDoc =
    \\>>>TODO
; // io_uring_register_probe
fn registerProbe(_: *Ring, _: *Probe, _: u32) ?i32 {
    return oz.raiseNotImplementedError("`io_uring_register_probe` - caught the zig bug!");
    // return e.trapError(c.io_uring_register_probe(ring._io_uring, probe._io_uring_probe, nr));
}

const registerPersonalityDoc =
    \\>>> io_uring_register_personality(ring)
    \\123  # id
; // io_uring_register_personality
fn registerPersonality(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_register_personality(ring._io_uring));
}

const unregisterPersonalityDoc =
    \\>>> io_uring_unregister_personality(ring, id)
; // io_uring_unregister_personality
fn unregisterPersonality(ring: *Ring, id: i32) ?i32 {
    return e.trapError(c.io_uring_unregister_personality(ring._io_uring, id));
}

// TODO: create Restriction class
const registerRestrictionsDoc =
    \\TODO
; // io_uring_register_restrictions
fn registerRestrictions(ring: *Ring, res: *Restriction) ?i32 {
    return e.trapError(c.io_uring_register_restrictions(ring._io_uring, res._io_uring_restriction, @intCast(res._len)));
}

const enableRingsDoc =
    \\>>> io_uring_enable_rings(ring)
; // io_uring_enable_rings
fn enableRings(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_enable_rings(ring._io_uring));
}

const registerRingFdDoc =
    \\>>> io_uring_register_ring_fd(ring)
; // io_uring_register_ring_fd
fn registerRingFd(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_register_ring_fd(ring._io_uring));
}

const unregisterRingFdDoc =
    \\>>> io_uring_unregister_ring_fd(ring)
; // io_uring_unregister_ring_fd
fn unregisterRingFd(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_unregister_ring_fd(ring._io_uring));
}

const closeRingFdDoc =
    \\>>> io_uring_close_ring_fd(ring)
; // io_uring_close_ring_fd
fn closeRingFd(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_close_ring_fd(ring._io_uring));
}

const registerBufRingDoc =
    \\TODO
; // io_uring_register_buf_ring
fn registerBufRing(ring: *Ring, reg: *BufReg, flags: ?u32) ?i32 {
    const _flags: u32 = if (flags) |f| f else 0;
    return e.trapError(c.io_uring_register_buf_ring(ring._io_uring, reg._io_uring_buf_reg, _flags));
}

const unregisterBufRingDoc =
    \\TODO
; // io_uring_unregister_buf_ring
fn unregisterBufRing(ring: *Ring, bgid: i32) ?i32 {
    return e.trapError(c.io_uring_unregister_buf_ring(ring._io_uring, bgid));
}

const bufRingHeadDoc =
    \\TODO
; // io_uring_buf_ring_head
fn bufRingHead(ring: *Ring, buf_group: i32, head: *u16) ?i32 {
    return e.trapError(c.io_uring_buf_ring_head(ring._io_uring, buf_group, head));
}

const registerSyncCancelDoc =
    \\TODO
; // io_uring_register_sync_cancel
fn registerSyncCancel(ring: *Ring, reg: *SyncCancelReg) ?i32 {
    return e.trapError(c.io_uring_register_sync_cancel(ring._io_uring, reg._io_uring_sync_cancel_reg));
}

const registerSyncMsgDoc =
    \\TODO
; // io_uring_register_sync_msg
fn registerSyncMsg(sqe: *Sqe) ?i32 {
    return e.trapError(c.io_uring_register_sync_msg(sqe._io_uring_sqe));
}

const registerFileAllocRangeDoc =
    \\TODO
; // io_uring_register_file_alloc_range
fn registerFileAllocRange(ring: *Ring, off: u32, len: u32) ?i32 {
    return e.trapError(c.io_uring_register_file_alloc_range(ring._io_uring, off, len));
}

const registerNapiDoc =
    \\TODO
; // io_uring_register_napi
fn registerNapi(ring: *Ring, napi: *Napi) ?i32 {
    return e.trapError(c.io_uring_register_napi(ring._io_uring, napi._io_uring_napi));
}

const unregisterNapiDoc =
    \\TODO
; // io_uring_unregister_napi
fn unregisterNapi(ring: *Ring, napi: *Napi) ?i32 {
    return e.trapError(c.io_uring_unregister_napi(ring._io_uring, napi._io_uring_napi));
}

const registerIfqDoc =
    \\TODO
; // io_uring_register_ifq
fn registerIfq(ring: *Ring, reg: *ZcrxIfqReg) ?i32 {
    return e.trapError(c.io_uring_register_ifq(ring._io_uring, reg._io_uring_zcrx_ifq_reg));
}

const registerClockDoc =
    \\TODO
; // io_uring_register_clock
fn registerClock(ring: *Ring, arg: *ClockRegister) ?i32 {
    return e.trapError(c.io_uring_register_clock(ring._io_uring, arg._io_uring_clock_register));
}

const registerBpfFilterDoc =
    \\TODO
; // io_uring_register_bpf_filter
fn registerBpfFilter(ring: *Ring, bpf: *Bpf) ?i32 {
    return e.trapError(c.io_uring_register_bpf_filter(ring._io_uring, bpf._io_uring_bpf));
}

const registerBpfFilterTaskDoc =
    \\TODO
; // io_uring_register_bpf_filter_task
fn registerBpfFilterTask(bpf: *Bpf) ?i32 {
    return e.trapError(c.io_uring_register_bpf_filter_task(bpf._io_uring_bpf));
}

const getEventsDoc =
    \\TODO
; // io_uring_get_events
fn getEvents(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_get_events(ring._io_uring));
}

const submitAndGetEventsDoc =
    \\TODO
; // io_uring_submit_and_get_events
fn submitAndGetEvents(ring: *Ring) ?i32 {
    return e.trapError(c.io_uring_submit_and_get_events(ring._io_uring));
}

const enterDoc =
    \\TODO
; // io_uring_enter
fn enter(fd: u32, to_submit: u32, min_complete: u32, flags: u32, sig: *SigsetT) ?i32 {
    return e.trapError(c.io_uring_enter(fd, to_submit, min_complete, flags, sig._sigset_t));
}

const enter2Doc =
    \\TODO
; // io_uring_enter2
fn enter2(fd: u32, to_submit: u32, min_complete: u32, flags: u32, arg: ?*anyopaque, sz: usize) ?i32 {
    return e.trapError(c.io_uring_enter2(fd, to_submit, min_complete, flags, arg, sz));
}

const setupDoc =
    \\TODO
; // io_uring_setup
fn setup(entries: u32, p: *Param) ?i32 {
    return e.trapError(c.io_uring_setup(entries, p._io_uring_params));
}

const registerDoc =
    \\TODO
; // io_uring_register
fn register(fd: u32, opcode: u32, arg: ?*anyopaque, nr_args: u32) ?i32 {
    return e.trapError(c.io_uring_register(fd, opcode, arg, nr_args));
}

const registerRegionDoc =
    \\TODO
; // io_uring_register_region
fn registerRegion(ring: *Ring, reg: MemRegionReg) ?i32 {
    return e.trapError(c.io_uring_register_region(ring._io_uring, reg._io_uring_mem_region_reg));
}

const setupBufRingDoc =
    \\TODO
; // io_uring_setup_buf_ring
fn setupBufRing(ring: *Ring, nentries: u32, bgid: i32, flags: u32, err: *i32) ?BufRing {
    if (c.io_uring_setup_buf_ring(ring._io_uring, nentries, bgid, flags, err)) |br| {
        return .{ ._io_uring_buf_ring = br };
    }
    return oz.raiseRuntimeError("`io_uring_setup_buf_ring` - could not be initialized!");
}

const freeBufRingDoc =
    \\TODO
; // io_uring_free_buf_ring
fn freeBufRing(ring: *Ring, br: BufRing, nentries: u32, bgid: i32) ?i32 {
    return e.trapError(c.io_uring_free_buf_ring(ring._io_uring, br._io_uring_buf_ring, nentries, bgid));
}

const setIoWaitDoc =
    \\TODO
; // io_uring_set_iowait
fn setIoWait(ring: *Ring, enable_iowait: bool) ?i32 {
    return e.trapError(c.io_uring_set_iowait(ring._io_uring, enable_iowait));
}

const cqeIterInitDoc =
    \\>>> cqe_iter = io_uring_cqe_iter_init(ring)
    \\>>> while io_uring_cqe_iter_next(cqe_iter, cqe):
    \\
    \\Note
    \\    - `io_uring_cqe_iter_init` must be used with `io_uring_cqe_iter_next`
    \\    - Refer to `help(io_uring_cqe_iter_next)` for better example.
; // io_uring_cqe_iter_init
pub inline fn cqeIterInit(ring: *Ring) CqeIter {
    return .{ ._io_uring_cqe_iter = c.io_uring_cqe_iter_init(ring._io_uring) };
}

const cqeIterNextDoc =
    \\Example
    \\    # Must submit `sqe` before:
    \\    ... ...
    \\    >>> ready = 0
    \\    >>> cqe_iter = io_uring_cqe_iter_init(ring)
    \\    >>> while io_uring_cqe_iter_next(cqe_iter, cqe):
    \\    >>>     ready += 1
    \\    >>>     entry = cqe[0]  # only index `0` data gets updated!!!
    \\    >>>     entry.user_data, entry.res  # do something with info
    \\    ...     ...
    \\    # either:
    \\    >>>     io_uring_cqe_seen(ring, entry)  # within `while` loop
    \\    # or
    \\    >>> io_uring_cq_advance(ring, ready)  # after `while` loop is finished (probably faster).
    \\
    \\Note
    \\    - Only `cqe[0]` gets updated with new completed entry value.
    \\    - Getting iter is low level and very touchy must be used as shown in example.
    \\    - Consider using `io_uring_cqe_iter` instead, in `for` loop.
; // io_uring_cqe_iter_next
inline fn cqeIterNext(iter: *CqeIter, cqe: *Cqe) bool {
    return c.io_uring_cqe_iter_next(&iter._io_uring_cqe_iter, &cqe._io_uring_cqe);
}

const cqAdvanceDoc =
    \\TODO
; // io_uring_cq_advance
inline fn cqAdvance(ring: *Ring, nr: u32) void {
    c.io_uring_cq_advance(ring._io_uring, nr);
}

const cqeSeenDoc =
    \\Warning
    \\    - Use `io_uring_cq_advance(ring, 1)` instead.
; // io_uring_cqe_seen
inline fn cqeSeen(ring: *Ring, cqe: *CQE) void {
    c.io_uring_cqe_seen(ring._io_uring, cqe._cqe);
}
// inline fn cqeSeen(ring: *Ring, cqe: *Cqe) ?void {
//     if (cqe._io_uring_cqe) |q| {
//         c.io_uring_cqe_seen(ring._io_uring, &q);
//         return;
//     }
//     return oz.raiseValueError("`io_uring_cqe_seen()` - `cqe` is `null`");
// }

const setDataDoc =
    \\>>> io_uring_sqe_set_data(sqe, python_object)
    \\
    \\Warning
    \\    - Not tested!!!
; // io_uring_sqe_set_data
inline fn setData(sqe: *SQE, data: *oz.py.PyObject) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(data)) |ptr| {
        oz.py.Py_IncRef(data);
        c.io_uring_sqe_set_data(sqe._sqe, ptr);
    } else return null;
}

const getDataDoc =
    \\>>> python_object = io_uring_cqe_get_data(cqe[0])
    \\
    \\Warning
    \\    - Not tested!!!
; // io_uring_cqe_get_data
inline fn getData(cqe: *CQE) ?*oz.py.PyObject {
    const ptr: ?*anyopaque = c.io_uring_cqe_get_data(cqe._cqe); // NOTE: This can return garbage data!
    if (ptr == null) return oz.raiseValueError("`io_uring_cqe_get_data()` - received `null`");
    const data: ?*oz.py.PyObject = oz.py.c.PyLong_FromVoidPtr(ptr);
    if (data == null) return null;
    defer oz.py.Py_DecRef(data);
    return data;
    // return oz.raiseValueError("`io_uring_cqe_get_data()` - `cqe` is `null`");

    // if (cqe._cqe) |q| {
    //     const ptr: ?*anyopaque = c.io_uring_cqe_get_data(q); // NOTE: This can return garbage data!
    //     if (ptr == null) return oz.raiseValueError("`io_uring_cqe_get_data()` - received `null`");
    //     const data: ?*oz.py.PyObject = oz.py.c.PyLong_FromVoidPtr(ptr);
    //     if (data == null) return null;
    //     defer oz.py.Py_DecRef(data);
    //     return data;
    // }
    // return oz.raiseValueError("`io_uring_cqe_get_data()` - `cqe` is `null`");
}

const setData64Doc =
    \\>>> io_uring_sqe_set_data64(sqe, 123)
; // io_uring_sqe_set_data64
inline fn setData64(sqe: *SQE, data: u64) ?void {
    // TODO: remove this later!
    // if (data == 0) return oz.raiseValueError("`io_uring_sqe_set_data64(sqe, 0)` - `sqe.user_data` can not be set to `0`");
    c.io_uring_sqe_set_data64(sqe._sqe, data);
}

const getData64Doc =
    \\>>> io_uring_cqe_get_data64(cqe)
    \\123
; // io_uring_cqe_get_data64
inline fn getData64(cqe: *CQE) ?u64 {
    return c.io_uring_cqe_get_data64(cqe._cqe);
    // if (cqe._cqe) |q| return c.io_uring_cqe_get_data64(q);
    // return oz.raiseRuntimeError("`io_uring_cqe_get_data64(cqe)` is `null`!");
}

const sqeSetFlagsDoc =
    \\>>> io_uring_sqe_set_flags(sqe, IOSQE_IO_HARDLINK)
; // io_uring_sqe_set_flags
inline fn sqeSetFlags(sqe: *SQE, flags: u32) void {
    c.io_uring_sqe_set_flags(sqe._sqe, flags);
}

const sqeSetBufGroupDoc =
    \\>>> io_uring_sqe_set_buf_group(sqe, 123)
; // io_uring_sqe_set_buf_group
inline fn sqeSetBufGroup(sqe: *SQE, bgid: i32) void {
    c.io_uring_sqe_set_buf_group(sqe._sqe, bgid);
}

const prepSpliceDoc =
    \\TODO
; // io_uring_prep_splice
inline fn prepSplice(
    sqe: *SQE,
    fd_in: i32,
    off_in: i64,
    fd_out: i32,
    off_out: i64,
    nbytes: u32,
    splice_flags: u32,
) ?void {
    c.io_uring_prep_splice(sqe._sqe, fd_in, off_in, fd_out, off_out, nbytes, splice_flags);
}

const prepTeeDoc =
    \\TODO
; // io_uring_prep_tee
inline fn prepTee(sqe: *SQE, fd_in: i32, fd_out: i32, nbytes: u32, splice_flags: u32) void {
    c.io_uring_prep_tee(sqe._sqe, fd_in, fd_out, nbytes, splice_flags);
}

const prepReadVDoc =
    \\Example
    \\    >>> buffer = [bytearray(5), bytearray(4)]
    \\    >>> io_uring_prep_readv(sqe, fd, buffer)
    \\    ...
    \\    >>> buffer
    \\    [bytearray(b"hi..."), bytearray(b"bye!")]
    \\
    \\Note
    \\    - `io_uring_prep_readv` includes `io_uring_prep_readv2` feature as well.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_readv & io_uring_prep_readv2
inline fn prepReadV(sqe: *SQE, fd: i32, buffer: *oz.PyObject, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    if (Iovec.__new__(buffer)) |iovec| {
        c.io_uring_prep_readv2(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags);
    } else return null; // raised error.
}

const prepReadFixedDoc =
    \\Example
    \\    >>> # `buf_index` = registered IO buffer
    \\    >>> buffer = bytearray(5)
    \\    >>> io_uring_prep_read_fixed(sqe, fd, buffer, buf_index)
    \\    ...
    \\    >>> buffer
    \\    bytearray(b"hi...")
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_read_fixed
inline fn prepReadFixed(sqe: *SQE, fd: i32, buffer: *oz.PyObject, buf_index: i32, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    if (Iovec.__new__(buffer)) |iov| {
        if (iov._iovec) |v| {
            c.io_uring_prep_read_fixed(sqe._sqe, fd, v[0].iov_base, @intCast(v[0].iov_len), _offset, buf_index);
        } else return null; // raised error. TODO: should raise proper error
    } else return null; // raised error.
}

const prepReadVFixedDoc =
    \\Example
    \\    >>> # `buf_index` = registered IO buffer
    \\    >>> buffer = [bytearray(5), bytearray(4)]
    \\    >>> io_uring_prep_readv_fixed(sqe, fd, buffer, buf_index)
    \\    ...
    \\    >>> buffer
    \\    [bytearray(b"hi..."), bytearray(b"bye!")]
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_readv_fixed
inline fn prepReadVFixed(sqe: *SQE, fd: i32, buffer: *oz.PyObject, buf_index: i32, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    if (Iovec.__new__(buffer)) |iov| {
        c.io_uring_prep_readv_fixed(sqe._sqe, fd, iov._iovec, @intCast(iov._len), _offset, _flags, buf_index);
    } else return null; // raised error.
}

const prepWriteVDoc =
    \\Example
    \\    >>> buffer = [b'hi...'), b'bye!']
    \\    >>> io_uring_prep_writev(sqe, fd, buffer)
    \\    ... ...
    \\    >>> cqe.res
    \\    9
    \\
    \\Note
    \\    - `io_uring_prep_writev` includes `io_uring_prep_writev2` feature as well.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_writev & io_uring_prep_writev2
inline fn prepWriteV(sqe: *SQE, fd: i32, buffer: *oz.PyObject, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    if (Iovec.__new__(buffer)) |iovec| {
        c.io_uring_prep_writev2(sqe._sqe, fd, iovec._iovec, @intCast(iovec._len), _offset, _flags);
    } else return null; // raised error.
}

const prepWriteFixedDoc =
    \\Example
    \\    >>> # `buf_index` = registered IO buffer
    \\    >>> io_uring_prep_write_fixed(sqe, fd, b'hi...', buf_index)
    \\    ... ...
    \\    >>> cqe.res
    \\    5
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_write_fixed
inline fn prepWriteFixed(sqe: *SQE, fd: i32, buffer: *oz.PyObject, buf_index: i32, offset: ?u64) ?void {
    const _offset = offset orelse 0;
    if (Iovec.__new__(buffer)) |iov| {
        c.io_uring_prep_write_fixed(sqe._sqe, fd, iov._iovec, @intCast(iov._len), _offset, buf_index);
    } else return null; // raised error.
}

const prepWriteVFixedDoc =
    \\Example
    \\    >>> # `buf_index` = registered IO buffer
    \\    >>> buffer = [bytearray(b"hi..."), bytearray(b"bye!")]
    \\    >>> io_uring_prep_writev_fixed(sqe, fd, buffer, buf_index)
    \\    ...
    \\    >>> cqe.res
    \\    9
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_writev_fixed
inline fn prepWriteVFixed(sqe: *SQE, fd: i32, buffer: *oz.PyObject, buf_index: i32, offset: ?u64, flags: ?i32) ?void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    if (Iovec.__new__(buffer)) |iov| {
        c.io_uring_prep_writev_fixed(sqe._sqe, fd, iov._iovec, @intCast(iov._len), _offset, _flags, buf_index);
    } else return null; // TODO: raised error.
}

const prepRecvmsgDoc =
    \\TODO
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_recvmsg
inline fn prepRecvmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg(sqe._sqe, fd, msg._msghdr, _flags);
}

const prepRecvmsgMultishotDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_recvmsg_multishot
inline fn prepRecvmsgMultishot(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_recvmsg_multishot(sqe._sqe, fd, msg._msghdr, _flags);
}

const prepSendmsgDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_sendmsg
inline fn prepSendmsg(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_sendmsg(sqe._sqe, fd, msg._msghdr, _flags);
}

const prepPollAddDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_poll_add
inline fn prepPollAdd(sqe: *SQE, fd: i32, poll_mask: u32) void {
    c.io_uring_prep_poll_add(sqe._sqe, fd, poll_mask);
}

const prepPollMultishotDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_poll_multishot
inline fn prepPollMultishot(sqe: *SQE, fd: i32, poll_mask: u32) void {
    c.io_uring_prep_poll_multishot(sqe._sqe, fd, poll_mask);
}

const prepPollRemoveDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_poll_remove
inline fn prepPollRemove(sqe: *SQE, user_data: u64) ?void {
    c.io_uring_prep_poll_remove(sqe._sqe, user_data);
}

const prepPollUpdateDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_poll_update
inline fn prepPollUpdate(sqe: *SQE, old_user_data: u64, new_user_data: u64, poll_mask: u32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_poll_update(sqe._sqe, old_user_data, new_user_data, poll_mask, _flags);
}

const prepFsyncDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fsync
inline fn prepFsync(sqe: *SQE, fd: i32, fsync_flags: ?u32) void {
    const _flags = fsync_flags orelse 0;
    c.io_uring_prep_fsync(sqe._sqe, fd, _flags);
}

const prepNopDoc =
    \\>>> io_uring_prep_nop(sqe)
; // io_uring_prep_nop
inline fn prepNop(sqe: *SQE) void {
    c.io_uring_prep_nop(sqe._sqe);
}

const prepNop128Doc =
    \\>>> io_uring_prep_nop128(sqe)
; // io_uring_prep_nop128
inline fn prepNop128(sqe: *SQE) void {
    c.io_uring_prep_nop128(sqe._sqe);
}

const prepTimeoutDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_timeout
inline fn prepTimeout(sqe: *SQE, ts: *Timespec, count: u32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout(sqe._sqe, ts._timespec, count, _flags);
}

const prepTimeoutRemoveDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_timeout_remove
inline fn prepTimeoutRemove(sqe: *SQE, user_data: u64, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_remove(sqe._sqe, user_data, _flags);
}

const prepTimeoutUpdateDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_timeout_update
inline fn prepTimeoutUpdate(sqe: *SQE, ts: *Timespec, user_data: u64, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_timeout_update(sqe._sqe, ts._timespec, user_data, _flags);
}

const prepAcceptDoc =
    \\TODO 
    \\Example
    \\    >>> addr = sockaddr(AF_INET, "127.0.0.1", 12345)
    \\    ... ...
    \\    >>> io_uring_prep_accept(sqe, fd, addr)
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_accept
inline fn prepAccept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;

    if (addr) |a| return c.io_uring_prep_accept(sqe._sqe, fd, @ptrFromInt(a._sockaddr), a._socklen, _flags);
    c.io_uring_prep_accept(sqe._sqe, fd, null, null, _flags);
}

const prepAcceptDirectDoc =
    \\TODO
    \\
    \\Note
    \\    - Function argument `file_index` position has changed for C origin for better usability.
    \\    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
    \\    Allocated descriptor is returned in the `cqe.res`.
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_accept_direct
inline fn prepAcceptDirect(sqe: *SQE, fd: i32, addr: ?*Sockaddr, file_index: ?u32, flags: ?i32) void {
    const _flags = flags orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    if (addr) |a| return c.io_uring_prep_accept_direct(
        sqe._sqe,
        fd,
        @ptrFromInt(a._sockaddr),
        a._socklen,
        _flags,
        _file_index,
    );
    c.io_uring_prep_accept_direct(sqe._sqe, fd, null, null, _flags, _file_index);
}

const prepMultishotAcceptDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_multishot_accept
inline fn prepMultishotAccept(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;
    if (addr) |a| return c.io_uring_prep_multishot_accept(sqe._sqe, fd, @ptrFromInt(a._sockaddr), a._socklen, _flags);
    c.io_uring_prep_multishot_accept(sqe._sqe, fd, null, null, _flags);
}

const prepMultishotAcceptDirectDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_multishot_accept_direct
inline fn prepMultishotAcceptDirect(sqe: *SQE, fd: i32, addr: ?*Sockaddr, flags: ?i32) void {
    const _flags = flags orelse 0;
    if (addr) |a| return c.io_uring_prep_multishot_accept_direct(sqe._sqe, fd, @ptrFromInt(a._sockaddr), a._socklen, _flags);
    c.io_uring_prep_multishot_accept_direct(sqe._sqe, fd, null, null, _flags);
}

const prepCancel64Doc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cancel64
inline fn prepCancel64(sqe: *SQE, user_data: u64, flags: ?i32) void {
    c.io_uring_prep_cancel64(sqe._sqe, user_data, flags orelse 0);
}

const prepCancelDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cancel
inline fn prepCancel(sqe: *SQE, user_data: *oz.py.PyObject, flags: ?i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(user_data)) |ptr| {
        c.io_uring_prep_cancel(sqe._sqe, ptr, flags orelse 0);
    } else return null;
}

const prepCancelFdDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cancel_fd
inline fn prepCancelFd(sqe: *SQE, fd: i32, flags: ?u32) void {
    c.io_uring_prep_cancel_fd(sqe._sqe, fd, flags orelse 0);
}

const prepLinkTimeoutDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_link_timeout
inline fn prepLinkTimeout(sqe: *SQE, ts: Timespec, flags: u32) void {
    c.io_uring_prep_link_timeout(sqe._sqe, ts._timespec, flags);
}

const prepConnectDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_connect
inline fn prepConnect(sqe: *SQE, fd: i32, addr: *Sockaddr) void {
    c.io_uring_prep_connect(sqe._sqe, fd, @ptrFromInt(addr._sockaddr), addr._socklen);
}

const prepBindDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_bind
inline fn prepBind(sqe: *SQE, fd: i32, addr: *Sockaddr) void {
    c.io_uring_prep_bind(sqe._sqe, fd, @ptrFromInt(addr._sockaddr), addr._socklen);
}

const prepListenDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_listen
inline fn prepListen(sqe: *SQE, fd: i32, backlog: i32) void {
    c.io_uring_prep_listen(sqe._sqe, fd, backlog);
}

const prepEpollWaitDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_epoll_wait
inline fn prepEpollWait(sqe: *SQE, fd: i32, events: *EpollEvent, maxevents: i32, flags: ?u32) void {
    c.io_uring_prep_epoll_wait(sqe._sqe, fd, events._epoll_event, maxevents, flags orelse 0);
}

const prepFilesUpdateDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_files_update
inline fn prepFilesUpdate(sqe: *SQE, fds: oz.ListView(i32), offset: ?i32) void {
    c.io_uring_prep_files_update(sqe._sqe, @ptrCast(fds.py_list), @intCast(fds.len()), offset orelse 0);
}

const prepFallocateDoc =
    \\TODO
    \\
    \\Mode
    \\    FALLOC_FL_KEEP_SIZE       # default is extend size
    \\    FALLOC_FL_PUNCH_HOLE      # de-allocates range
    \\    FALLOC_FL_NO_HIDE_STALE   # reserved codepoint
    \\    FALLOC_FL_COLLAPSE_RANGE
    \\    FALLOC_FL_ZERO_RANGE
    \\    FALLOC_FL_INSERT_RANGE
    \\    FALLOC_FL_UNSHARE_RANGE
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fallocate
inline fn prepFallocate(sqe: *SQE, fd: i32, mode: i32, offset: u64, len: u64) void {
    c.io_uring_prep_fallocate(sqe._sqe, fd, mode, offset, len);
}

const prepOpenDoc =
    \\Open File
    \\
    \\Example
    \\    >>> sqe = io_uring_get_sqe(ring)
    \\    >>> io_uring_prep_open(sqe, b'./file.ext')
    \\    >>> sqe.user_data = 123
    \\
    \\Note
    \\    - Function argument `dfd` has been moved to end from how it is in C function.
    \\    - `io_uring_prep_open` includes `io_uring_prep_openat` as well.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_open & io_uring_prep_openat
inline fn prepOpen(sqe: *SQE, path: oz.Path, flags: ?i32, mode: ?c.mode_t, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse 0;
    c.io_uring_prep_openat(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mode);
}

const prepOpenDirectDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
    \\    Allocated descriptor is returned in the `cqe.res`.
    \\    - `io_uring_prep_open_direct` includes `io_uring_prep_openat_direct` as well.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_open_direct & io_uring_prep_openat_direct
inline fn prepOpenDirect(
    sqe: *SQE,
    path: oz.Path,
    flags: ?i32,
    file_index: ?u32,
    mode: ?c.mode_t,
    dfd: ?i32,
) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mode = mode orelse 0o777;
    const _flags = flags orelse c.O_RDONLY;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_openat_direct(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mode, _file_index);
}

const prepCloseDoc =
    \\>>> io_uring_prep_close(sqe, fd)
; // io_uring_prep_close
inline fn prepClose(sqe: *SQE, fd: i32) void {
    c.io_uring_prep_close(sqe._sqe, fd);
}

const prepCloseDirectDoc =
    \\>>> io_uring_prep_close_direct(sqe, file_index)
; // io_uring_prep_close_direct
inline fn prepCloseDirect(sqe: *SQE, file_index: u32) void {
    c.io_uring_prep_close_direct(sqe._sqe, file_index);
}

const prepReadDoc =
    \\>>> buf = bytearray(5)
    \\>>> sqe = io_uring_get_sqe(ring)
    \\>>> io_uring_prep_read(sqe, fd, buf)
    \\... ...
    \\>>> cqe.res
    \\5
    \\... ...
    \\>>> buf
    \\bytearray(b'hi...')
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_read
inline fn prepRead(sqe: *SQE, fd: i32, buf: *oz.py.PyObject, offset: ?u64) ?void {
    const msg = "`io_uring_prep_read` - `buf` type not supported, only `bytes`, `bytearray`, `memoryview`";
    const _offset = offset orelse 0;

    // check if bytes, bytearray or memoryview
    if (oz.py.PyBytes_Check(buf) | oz.py.PyByteArray_Check(buf) | oz.py.PyMemoryView_Check(buf)) {
        const length: c_uint = @intCast(oz.py.c.PyObject_Length(buf)); // length of byte string.

        if (oz.py.c.PyLong_AsVoidPtr(buf)) |ptr| {
            c.io_uring_prep_read(sqe._sqe, fd, ptr, length, _offset);
        } else return null;
    } else return oz.raiseTypeError(msg);
}

const prepReadMultishotDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_read_multishot
inline fn prepReadMultishot(sqe: *SQE, fd: i32, buf_group: i32, nbytes: ?u32, offset: ?u64) void {
    const _nbytes = nbytes orelse 0;
    const _offset = offset orelse 0;
    c.io_uring_prep_read_multishot(sqe._sqe, fd, _nbytes, _offset, buf_group);
}

const prepWriteDoc =
    \\>>> sqe = io_uring_get_sqe(ring)
    \\>>> io_uring_prep_write(sqe, fd, b"hi...")
    \\... ...
    \\>>> cqe.res
    \\5
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_write
// inline fn prepWrite(sqe: *SQE, fd: i32, buf: *oz.py.PyObject, offset: ?u64) ?void {
//     const msg = "`io_uring_prep_write` - `buf` type not supported, only `bytes`, `bytearray`, `memoryview`";
//     const _offset = offset orelse 0;

//     // check if bytes, bytearray or memoryview
//     if (oz.py.PyBytes_Check(buf) | oz.py.PyByteArray_Check(buf) | oz.py.PyMemoryView_Check(buf)) {
//         const length: c_uint = @intCast(oz.py.c.PyObject_Length(buf)); // length of byte string.

//         if (oz.py.c.PyLong_AsVoidPtr(buf)) |ptr| {
//             c.io_uring_prep_write(sqe._sqe, fd, ptr, length, _offset);
//         } else return null;
//     } else return oz.raiseTypeError(msg);
// }
inline fn prepWrite(sqe: *SQE, fd: i32, buf: oz.Bytes, offset: ?u64) ?void {
    // const msg = "`io_uring_prep_write` - `buf` type not supported, only `bytes`, `bytearray`, `memoryview`";
    const _offset = offset orelse 0;
    c.io_uring_prep_write(sqe._sqe, fd, @ptrCast(buf.data), @intCast(buf.data.len), _offset);
}

const prepStatxDoc =
    \\Type
    \\    sqe:    io_uring_sqe
    \\    stat:   statx
    \\    path:   bytes
    \\    flags:  int
    \\    mask:   int
    \\    dfd:    int
    \\    return: None
    \\
    \\Example
    \\    >>> stat = statx()
    \\    >>> if sqe := io_uring_get_sqe(ring)
    \\    ...     io_uring_prep_statx(sqe, stat, __file__)
    \\    ... ...
    \\    >>> stat.isfile
    \\    True
    \\    >>> stat.size
    \\    123
    \\
    \\Flag
    \\    AT_EMPTY_PATH
    \\    AT_NO_AUTOMOUNT
    \\    AT_SYMLINK_NOFOLLOW     # Do not follow symbolic links.
    \\    AT_STATX_SYNC_AS_STAT
    \\    AT_STATX_FORCE_SYNC
    \\    AT_STATX_DONT_SYNC
    \\
    \\Mask
    \\    STATX_TYPE          # Want|got `stx_mode & S_IFMT`
    \\    STATX_MODE          # Want|got `stx_mode & ~S_IFMT`
    \\    STATX_NLINK         # Want|got `stx_nlink`
    \\    STATX_UID           # Want|got `stx_uid`
    \\    STATX_GID           # Want|got `stx_gid`
    \\    STATX_ATIME         # Want|got `stx_atime`
    \\    STATX_MTIME         # Want|got `stx_mtime`
    \\    STATX_CTIME         # Want|got `stx_ctime`
    \\    STATX_INO           # Want|got `stx_ino`
    \\    STATX_SIZE          # Want|got `stx_size`
    \\    STATX_BLOCKS        # Want|got `stx_blocks`
    \\    STATX_BASIC_STATS   # [All of the above]
    \\    STATX_BTIME         # Want|got `stx_btime`
    \\    STATX_MNT_ID        # Got `stx_mnt_id`
    \\    # note: not supported
    \\    # STATX_DIOALIGN      # Want/got direct I/O alignment info
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `STATX_ALL` is depreciated, use `STATX_BASIC_STATS | STATX_BTIME` which is set by default.
; // io_uring_prep_statx
inline fn prepStatx(sqe: *SQE, statxbuf: *Statx, path: oz.Path, flags: ?i32, mask: ?u32, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _mask = mask orelse c.STATX_BASIC_STATS | c.STATX_BTIME; // replaces `STATX_ALL` as its depreciated!
    const _flags = flags orelse 0;
    c.io_uring_prep_statx(sqe._sqe, _dfd, @ptrCast(path.path), _flags, _mask, statxbuf._statx);
}

const prepFadviseDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fadvise
inline fn prepFadvise(sqe: *SQE, fd: i32, len: u32, advice: i32, offset: ?u64) void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise(sqe._sqe, fd, _offset, len, advice);
}

const prepMadviseDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_madvise
inline fn prepMadvise(sqe: *SQE, addr: *oz.py.PyObject, length: u32, advice: i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(addr)) |ptr| {
        c.io_uring_prep_madvise(sqe._sqe, ptr, length, advice);
    } else return null;
}

const prepFadvise64Doc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fadvise64
inline fn prepFadvise64(sqe: *SQE, fd: i32, len: c.off_t, advice: i32, offset: ?u64) void {
    const _offset = offset orelse 0;
    c.io_uring_prep_fadvise64(sqe._sqe, fd, _offset, len, advice);
}

const prepMadvise64Doc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_madvise64
inline fn prepMadvise64(sqe: *SQE, addr: *oz.py.PyObject, length: c.off_t, advice: i32) ?void {
    if (oz.py.c.PyLong_AsVoidPtr(addr)) |ptr| {
        c.io_uring_prep_madvise64(sqe._sqe, ptr, length, advice);
    } else return null;
}

const prepSendDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_send
inline fn prepSend(sqe: *SQE, sockfd: i32, buf: oz.Bytes, flags: ?i32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_send(sqe._sqe, sockfd, @ptrCast(buf.data), buf.data.len, _flags);
}

const prepSendBundleDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_send_bundle
inline fn prepSendBundle(sqe: *SQE, sockfd: i32, len: ?usize, flags: ?i32) void {
    c.io_uring_prep_send_bundle(sqe._sqe, sockfd, len orelse 0, flags orelse 0);
}

const prepSendSetAddrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_send_set_addr
inline fn prepSendSetAddr(sqe: *SQE, dest_addr: *Sockaddr) void {
    c.io_uring_prep_send_set_addr(sqe._sqe, @ptrFromInt(dest_addr._sockaddr), @intCast(dest_addr._socklen));
}

const prepSendtoDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_sendto
inline fn prepSendto(sqe: *SQE, sockfd: i32, buf: oz.Bytes, addr: *Sockaddr, flags: ?i32) void {
    c.io_uring_prep_sendto(
        sqe._sqe,
        sockfd,
        @ptrCast(buf.data),
        buf.data.len,
        flags orelse 0,
        @ptrFromInt(addr._sockaddr),
        addr._socklen,
    );
}

const prepSendZcDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_send_zc
inline fn prepSendZc(sqe: *SQE, sockfd: i32, buf: oz.Bytes, flags: ?i32, zc_flags: ?u32) void {
    c.io_uring_prep_send_zc(sqe._sqe, sockfd, @ptrCast(buf.data), buf.data.len, flags orelse 0, zc_flags orelse 0);
}

const prepSendZcFixedDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_send_zc_fixed
inline fn prepSendZcFixed(sqe: *SQE, sockfd: i32, buf: oz.Bytes, buf_index: ?u32, flags: ?i32, zc_flags: ?u32) void {
    c.io_uring_prep_send_zc_fixed(
        sqe._sqe,
        sockfd,
        @ptrCast(buf.data),
        buf.data.len,
        flags orelse 0,
        zc_flags orelse 0,
        buf_index orelse 0,
    );
}

const prepSendmsgZcDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_sendmsg_zc
inline fn prepSendmsgZc(sqe: *SQE, fd: i32, msg: *Msghdr, flags: ?u32) void {
    c.io_uring_prep_sendmsg_zc(sqe._sqe, fd, msg._msghdr, flags orelse 0);
}

const prepSendmsgZcFixedDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_sendmsg_zc_fixed
inline fn prepSendmsgZcFixed(sqe: *SQE, fd: i32, msg: *Msghdr, buf_index: u32, flags: ?u32) void {
    c.io_uring_prep_sendmsg_zc_fixed(sqe._sqe, fd, msg._msghdr, flags orelse 0, buf_index);
}

const prepRecvDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_recv
inline fn prepRecv(sqe: *SQE, sockfd: i32, buf: ?oz.ByteArray, flags: ?i32) void {
    if (buf) |b| {
        c.io_uring_prep_recv(sqe._sqe, sockfd, @ptrCast(b.data), b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv(sqe._sqe, sockfd, null, 0, flags orelse 0);
    }
}

const prepRecvMultishotDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_recv_multishot
inline fn prepRecvMultishot(sqe: *SQE, sockfd: i32, buf: ?oz.ByteArray, flags: ?i32) void {
    if (buf) |b| {
        c.io_uring_prep_recv_multishot(sqe._sqe, sockfd, @ptrCast(b.data), b.data.len, flags orelse 0);
    } else {
        c.io_uring_prep_recv_multishot(sqe._sqe, sockfd, null, 0, flags orelse 0);
    }
}

const recvmsgValidateDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_validate
inline fn recvmsgValidate(buf: oz.ByteArray, msgh: *Msghdr) RecvmsgOut {
    return .{ ._recvmsg_out = c.io_uring_recvmsg_validate(@ptrCast(buf.data), @intCast(buf.data.len), msgh._msghdr) };
}

const recvmsgNameDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_name
inline fn recvmsgName(o: *RecvmsgOut) ?*anyopaque {
    return c.io_uring_recvmsg_name(o._recvmsg_out);
}

const recvmsgCmsgFirsthdrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_cmsg_firsthdr
inline fn recvmsgCmsgFirsthdr(o: *RecvmsgOut, msgh: *Msghdr) Cmsghdr {
    return .{ ._cmsghdr = c.io_uring_recvmsg_cmsg_firsthdr(o._recvmsg_out, msgh._msghdr) };
}

const recvmsgCmsgNexthdrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_cmsg_nexthdr
inline fn recvmsgCmsgNexthdr(o: *RecvmsgOut, msgh: *Msghdr, cmsg: *Cmsghdr) Cmsghdr {
    return .{ ._cmsghdr = c.io_uring_recvmsg_cmsg_nexthdr(o._recvmsg_out, msgh._msghdr, cmsg._cmsghdr) };
}

const recvmsgPayloadDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_payload
inline fn recvmsgPayload(o: *RecvmsgOut, msgh: *Msghdr) ?*anyopaque {
    return c.io_uring_recvmsg_payload(o._recvmsg_out, msgh._msghdr);
}

const recvmsgPayloadLengthDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_recvmsg_payload_length
inline fn recvmsgPayloadLength(o: *RecvmsgOut, buf_len: i32, msgh: *Msghdr) u32 {
    return c.io_uring_recvmsg_payload_length(o._recvmsg_out, buf_len, msgh._msghdr);
}

const prepOpenat2Doc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
; // io_uring_prep_openat2
inline fn prepOpenat2(sqe: *SQE, path: oz.Path, how: *OpenHow, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_openat2(sqe._sqe, _dfd, @ptrCast(path.path), how._open_how);
}

const prepOpenat2DirectDoc =
    \\TODO
    \\
    \\
    \\Note
    \\    - If `file_index=IORING_FILE_INDEX_ALLOC` free direct descriptor will be auto assigned.
    \\    Allocated descriptor is returned in the `cqe.res`.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_openat2_direct
inline fn prepOpenat2Direct(sqe: *SQE, path: oz.Path, how: *OpenHow, file_index: ?u32, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    // std.debug.print("_file_index: {d}\n", .{_file_index});
    c.io_uring_prep_openat2_direct(sqe._sqe, _dfd, @ptrCast(path.path), how._open_how, _file_index);
}

const prepEpollCtlDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_epoll_ctl
inline fn prepEpollCtl(sqe: *SQE, epfd: i32, fd: i32, op: i32, ev: *EpollEvent) void {
    c.io_uring_prep_epoll_ctl(sqe._sqe, epfd, fd, op, ev._epoll_event);
}

const prepProvideBuffersDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_provide_buffers
inline fn prepProvideBuffers(sqe: *SQE, addr: oz.ByteArray, nr: i32, bgid: i32, bid: i32) void {
    c.io_uring_prep_provide_buffers(sqe._sqe, @ptrCast(addr.data), @intCast(addr.data.len), nr, bgid, bid);
}

const prepRemoveBuffersDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_remove_buffers
inline fn prepRemoveBuffers(sqe: *SQE, nr: i32, bgid: i32) void {
    c.io_uring_prep_remove_buffers(sqe._sqe, nr, bgid);
}

const prepShutdownDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_shutdown
inline fn prepShutdown(sqe: *SQE, fd: i32, how: i32) void {
    c.io_uring_prep_shutdown(sqe._sqe, fd, how);
}

const prepUnlinkDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `io_uring_prep_unlink` includes `io_uring_prep_unlinkat` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_unlink & io_uring_prep_unlinkat
inline fn prepUnlink(sqe: *SQE, path: oz.Path, flags: ?i32, dfd: ?i32) void {
    c.io_uring_prep_unlinkat(sqe._sqe, dfd orelse AT_FDCWD, @ptrCast(path.path), flags orelse 0);
}

const prepRenameDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `io_uring_prep_rename` includes `io_uring_prep_renameat` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_rename & io_uring_prep_renameat
inline fn prepRename(sqe: *SQE, oldpath: oz.Path, newpath: oz.Path, flags: ?u32, olddfd: ?i32, newdfd: ?i32) void {
    const _flags = flags orelse 0;
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    c.io_uring_prep_renameat(sqe._sqe, _olddfd, @ptrCast(oldpath.path), _newdfd, @ptrCast(newpath.path), _flags);
}

const prepSyncFileRangeDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_sync_file_range
inline fn prepSyncFileRange(sqe: *SQE, fd: i32, len: u32, offset: ?u64, flags: ?i32) void {
    const _offset = offset orelse 0;
    const _flags = flags orelse 0;
    c.io_uring_prep_sync_file_range(sqe._sqe, fd, len, _offset, _flags);
}

const prepMkdirDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `io_uring_prep_mkdir` includes `io_uring_prep_mkdirat` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_mkdir & io_uring_prep_mkdirat
inline fn prepMkdir(sqe: *SQE, path: oz.Path, mode: c.mode_t, dfd: ?i32) void {
    const _dfd = dfd orelse AT_FDCWD;
    c.io_uring_prep_mkdirat(sqe._sqe, _dfd, @ptrCast(path.path), mode);
}

const prepSymlinkDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `io_uring_prep_symlink` includes `io_uring_prep_symlinkat` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_symlink & io_uring_prep_symlinkat
inline fn prepSymlink(sqe: *SQE, target: oz.Path, linkpath: oz.Path, newdirfd: ?i32) void {
    const _newdirfd = newdirfd orelse AT_FDCWD;
    c.io_uring_prep_symlinkat(sqe._sqe, @ptrCast(target.path), _newdirfd, @ptrCast(linkpath.path));
}

const prepLinkDoc =
    \\TODO
    \\
    \\Note
    \\    - Function arguments position has changed for C origin for better usability.
    \\    - `io_uring_prep_link` includes `io_uring_prep_linkat` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_link & io_uring_prep_linkat
inline fn prepLink(sqe: *SQE, oldpath: oz.Path, newpath: oz.Path, flags: ?i32, olddfd: ?i32, newdfd: ?i32) void {
    const _olddfd = olddfd orelse AT_FDCWD;
    const _newdfd = newdfd orelse AT_FDCWD;
    const _flags = flags orelse 0;
    c.io_uring_prep_linkat(sqe._sqe, _olddfd, @ptrCast(oldpath.path), _newdfd, @ptrCast(newpath.path), _flags);
}

const prepMsgRingCqeFlagsDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_msg_ring_cqe_flags
inline fn prepMsgRingCqeFlags(sqe: *SQE, fd: i32, len: u32, data: u64, flags: u32, cqe_flags: u32) void {
    c.io_uring_prep_msg_ring_cqe_flags(sqe._sqe, fd, len, data, flags, cqe_flags);
}

const prepMsgRingDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_msg_ring
inline fn prepMsgRing(sqe: *SQE, fd: i32, len: u32, data: u64, flags: ?u32) void {
    c.io_uring_prep_msg_ring(sqe._sqe, fd, len, data, flags orelse 0);
}

const prepMsgRingFdDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_msg_ring_fd
inline fn prepMsgRingFd(sqe: *SQE, fd: i32, source_fd: i32, target_fd: i32, data: u64, flags: ?u32) void {
    c.io_uring_prep_msg_ring_fd(sqe._sqe, fd, source_fd, target_fd, data, flags orelse 0);
}

const prepMsgRingFdAllocDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_msg_ring_fd_alloc
inline fn prepMsgRingFdAlloc(sqe: *SQE, fd: i32, source_fd: i32, data: u64, flags: ?u32) void {
    c.io_uring_prep_msg_ring_fd_alloc(sqe._sqe, fd, source_fd, data, flags orelse 0);
}

const prepGetxattrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_getxattr
inline fn prepGetxattr(sqe: *SQE, name: [*]const u8, value: [*]u8, path: oz.Path, len: u32) void {
    c.io_uring_prep_getxattr(sqe._sqe, name, value, @ptrCast(path.path), len);
}

const prepSetxattrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_setxattr
inline fn prepSetxattr(sqe: *SQE, name: [*]const u8, value: [*]u8, path: oz.Path, flags: i32, len: u32) void {
    c.io_uring_prep_setxattr(
        sqe._sqe,
        name,
        value,
        @ptrCast(path.path),
        flags,
        len,
    );
}

const prepFgetxattrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fgetxattr
inline fn prepFgetxattr(sqe: *SQE, fd: i32, name: [*]const u8, value: [*]u8, len: u32) void {
    c.io_uring_prep_fgetxattr(sqe._sqe, fd, name, value, len);
}

const prepFsetxattrDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fsetxattr
inline fn prepFsetxattr(sqe: *SQE, fd: i32, name: [*]const u8, value: [*]u8, flags: i32, len: u32) void {
    c.io_uring_prep_fsetxattr(sqe._sqe, fd, name, value, flags, len);
}

const prepSocketDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_socket
inline fn prepSocket(sqe: *SQE, domain: i32, @"type": i32, protocol: ?i32, flags: ?u32) void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    c.io_uring_prep_socket(sqe._sqe, domain, @"type", _protocol, _flags);
}

const prepSocketDirectDoc =
    \\TODO
    \\
    \\Note
    \\    - `io_uring_prep_socket_direct` includes `io_uring_prep_socket_direct_alloc` feature.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_socket_direct & io_uring_prep_socket_direct_alloc
inline fn prepSocketDirect(sqe: *SQE, domain: i32, Type: i32, protocol: ?i32, file_index: ?u32, flags: ?u32) void {
    const _flags = flags orelse 0;
    const _protocol = protocol orelse 0;
    const _file_index = file_index orelse c.IORING_FILE_INDEX_ALLOC;
    c.io_uring_prep_socket_direct(sqe._sqe, domain, Type, _protocol, _file_index, _flags);
}

const prepUringCmdDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_uring_cmd
inline fn prepUringCmd(sqe: *SQE, cmd_op: i32, fd: i32) void {
    c.io_uring_prep_uring_cmd(sqe._sqe, cmd_op, fd);
}

const prepUringCmd128Doc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_uring_cmd128
inline fn prepUringCmd128(sqe: *SQE, cmd_op: i32, fd: i32) void {
    c.io_uring_prep_uring_cmd128(sqe._sqe, cmd_op, fd);
}

const prepCmdSockDoc =
    \\Example
    \\    >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, SO_KEEPALIVE, 1)
    \\    # or
    \\    >>> io_uring_prep_cmd_sock(sqe, SOCKET_URING_OP_SETSOCKOPT, sockfd, SOL_SOCKET, ..., 'eth1')
    \\
    \\Opcode
    \\    SOCKET_URING_OP_SIOCINQ
    \\    SOCKET_URING_OP_SIOCOUTQ
    \\    SOCKET_URING_OP_GETSOCKOPT
    \\    SOCKET_URING_OP_SETSOCKOPT
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cmd_sock
inline fn prepCmdSock(sqe: *SQE, cmd_op: i32, fd: i32, level: i32, optname: i32, optval: IntStr) void {
    switch (optval) {
        .Int => |val| c.io_uring_prep_cmd_sock(sqe._sqe, cmd_op, fd, level, optname, val, 1),
        .Str => |val| c.io_uring_prep_cmd_sock(sqe._sqe, cmd_op, fd, level, optname, @ptrCast(val), @intCast(val.len)),
    }
}

const prepCmdGetsocknameDoc =
    \\TODO
    \\
    \\Example
    \\    # assuming `SO_KEEPALIVE` was previous set to `1`
    \\    >>> sqe = io_uring_get_sqe(ring)
    \\    >>> io_uring_prep_getsockopt(sqe, sockfd, SOL_SOCKET, SO_KEEPALIVE, 0)
    \\    ... # after submit and wait
    \\    >>> val
    \\    array('i', [1])
    \\    >>> val[0]
    \\    1
    \\
    \\Note
    \\    - remember to hold on to `val` as new result will be populated into it.
    \\    - `cqe.res` will return `sizeof` populating data.
    \\    - only 'i' and 'B' format is supported.
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cmd_getsockname
inline fn prepCmdGetsockname(sqe: *SQE) void {
    _ = sqe;
    return oz.raiseNotImplementedError("io_uring_prep_cmd_getsockname");
    // c.io_uring_prep_cmd_getsockname(sqe._sqe);
}

const prepWaitidDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_waitid
inline fn prepWaitid(sqe: *SQE, idtype: c.idtype_t, id: c.id_t, infop: *SigsetT, options: i32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_waitid(sqe._sqe, idtype, id, @ptrCast(infop._sigset_t), options, _flags);
}

const prepFutexWakeDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_futex_wake
inline fn prepFutexWake(sqe: *SQE, futex: *const u32, val: u64, mask: u64, futex_flags: ?u32, flags: ?*u32) void {
    const _flags = flags orelse 0;
    const _futex_flas = futex_flags orelse 0;
    c.io_uring_prep_futex_wake(sqe._sqe, futex._futex, val, mask, _futex_flas, _flags);
}

const prepFutexWaitDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_futex_wait
inline fn prepFutexWait(sqe: *SQE) void {
    c.io_uring_prep_futex_wait(sqe._sqe);
}

const prepFutexWaitvDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_futex_waitv
inline fn prepFutexWaitv(sqe: *SQE) void {
    c.io_uring_prep_futex_waitv(sqe._sqe);
}

const prepFixedFdInstallDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_fixed_fd_install
inline fn prepFixedFdInstall(sqe: *SQE, fd: i32, flags: ?u32) void {
    const _flags = flags orelse 0;
    c.io_uring_prep_fixed_fd_install(sqe._sqe, fd, _flags);
}

const prepFtruncateDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_ftruncate
inline fn prepFtruncate(sqe: *SQE, fd: i32, len: ?c.loff_t) void {
    const _len = len orelse 0;
    c.io_uring_prep_ftruncate(sqe._sqe, fd, _len);
}

const prepCmdDiscardDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_cmd_discard
inline fn prepCmdDiscard(sqe: *SQE, fd: i32, offset: u64, nbytes: u64) void {
    c.io_uring_prep_cmd_discard(sqe._sqe, fd, offset, nbytes);
}

const prepPipeDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_pipe
inline fn prepPipe(sqe: *SQE, fds: i32, pipe_flags: i32) void {
    c.io_uring_prep_pipe(sqe._sqe, fds, pipe_flags);
}

const prepPipeDirectDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_prep_pipe_direct
inline fn prepPipeDirect(sqe: *SQE, fds: i32, pipe_flags: i32, file_index: u32) void {
    c.io_uring_prep_pipe_direct(sqe._sqe, fds, pipe_flags, file_index);
}

const loadSqHeadDoc =
    \\TODO
    \\
    \\Warning
    \\    - Coded but not tested!!!
; // io_uring_load_sq_head
inline fn loadSqHead(ring: *Ring) u32 {
    return c.io_uring_load_sq_head(ring._io_uring);
}

const sqReadyDoc =
    \\TODO
; // io_uring_sq_ready
inline fn sqReady(ring: *Ring) u32 {
    return c.io_uring_sq_ready(ring._io_uring);
}

const sqSpaceLeftDoc =
    \\TODO
; // io_uring_sq_space_left
inline fn sqSpaceLeft(ring: *Ring) u32 {
    return c.io_uring_sq_space_left(ring._io_uring);
}

const sqeShiftFromFlagsDoc =
    \\TODO
; // io_uring_sqe_shift_from_flags
inline fn sqeShiftFromFlags(flags: u32) u32 {
    return c.io_uring_sqe_shift_from_flags(flags);
}

const sqeShiftDoc =
    \\TODO
; // io_uring_sqe_shift
inline fn sqeShift(ring: *Ring) u32 {
    return c.io_uring_sqe_shift(ring._io_uring);
}

const sqringWaitDoc =
    \\TODO
; // io_uring_sqring_wait
inline fn sqringWait(ring: *Ring) i32 {
    return c.io_uring_sqring_wait(ring._io_uring);
}

const cqReadyDoc =
    \\TODO
; // io_uring_cq_ready
inline fn cqReady(ring: *Ring) u32 {
    return c.io_uring_cq_ready(ring._io_uring);
}

const cqHasOverflowDoc =
    \\TODO
; // io_uring_cq_has_overflow"
inline fn cqHasOverflow(ring: *Ring) bool {
    return c.io_uring_cq_has_overflow(ring._io_uring);
}

const cqEventfdEnabledDoc =
    \\TODO
; // io_uring_cq_eventfd_enabled
inline fn cqEventfdEnabled(ring: *Ring) bool {
    return c.io_uring_cq_eventfd_enabled(ring._io_uring);
}

const cqEventfdToggleDoc =
    \\TODO
; // io_uring_cq_eventfd_toggle
inline fn cqEventfdToggle(ring: *Ring, enabled: bool) ?i32 {
    return e.trapError(c.io_uring_cq_eventfd_toggle(ring._io_uring, enabled));
}

const waitCqeNrDoc =
    \\TODO
; // io_uring_wait_cqe_nr
inline fn waitCqeNr(ring: *Ring, cqe: *Cqe, wait_nr: u32) ?i32 {
    return e.trapError(c.io_uring_wait_cqe_nr(ring._io_uring, &cqe._io_uring_cqe, wait_nr));
}

const peekCqeDoc =
    \\>>> io_uring_peek_cqe(ring, cqe)
; // io_uring_peek_cqe
inline fn peekCqe(ring: *Ring, cqe_ptr: *Cqe) ?i32 {
    return e.trapError(c.io_uring_peek_cqe(ring._io_uring, &cqe_ptr._io_uring_cqe));
}

const waitCqeDoc =
    \\TODO
; // io_uring_wait_cqe
pub inline fn waitCqe(ring: *Ring, cqe: *Cqe) ?i32 {
    return e.trapError(c.io_uring_wait_cqe(ring._io_uring, &cqe._io_uring_cqe));
}

const bufRingMaskDoc =
    \\TODO
; // io_uring_buf_ring_mask
inline fn bufRingMask(ring_entries: u32) i32 {
    return c.io_uring_buf_ring_mask(ring_entries);
}

const bufRingInitDoc =
    \\TODO
; // io_uring_buf_ring_init
inline fn bufRingInit(br: *BufRing) void {
    c.io_uring_buf_ring_init(br._io_uring_buf_ring);
}

const bufRingAddDoc =
    \\TODO
; // io_uring_buf_ring_add
inline fn bufRingAdd(br: *BufRing, addr: oz.Bytes, bid: u16, mask: i32, buf_offset: ?i32) void {
    const _buf_offset = buf_offset orelse 0;
    c.io_uring_buf_ring_add(br._io_uring_buf_ring, @ptrCast(@constCast(addr.data)), @intCast(addr.data.len), bid, mask, _buf_offset);
}

const bufRingAdvanceDoc =
    \\TODO
; // io_uring_buf_ring_advance
inline fn bufRingAdvance(br: *BufRing, count: i32) void {
    c.io_uring_buf_ring_advance(br._io_uring_buf_ring, count);
}

const bufRingCqAdvanceDoc =
    \\TODO
; // io_uring_buf_ring_cq_advance
inline fn bufRingCqAdvance(ring: *Ring, br: BufRing, count: i32) void {
    c.io_uring_buf_ring_cq_advance(ring._io_uring, br._io_uring_buf_ring, count);
}

const bufRingAvailableDoc =
    \\TODO
; // io_uring_buf_ring_available
inline fn bufRingAvailable(ring: *Ring, br: BufRing, bgid: u16) i32 {
    return c.io_uring_buf_ring_available(ring._io_uring, br._io_uring_buf_ring, bgid);
}

const getSqeDoc =
    \\>>> if sqe := io_uring_get_sqe(ring):
    \\...   # do stuff...
; // io_uring_get_sqe
fn getSqe(ring: *Ring) ?Sqe {
    if (c.io_uring_get_sqe(ring._io_uring)) |sqe| {
        // std.debug.print("\nio_uring_get_sqe: {any}\n\n", .{sqe});
        return .{ ._parent = .{ ._sqe = @ptrCast(&sqe[0]) }, ._len = 1, ._io_uring_sqe = sqe };
    }
    return null; // None
}

// TODO: ???
// const getSqe128Doc =
//     \\>>> if sqe := io_uring_get_sqe128(ring):
//     \\...   # do stuff...
// ; // io_uring_get_sqe128
// fn getSqe128(ring: *Ring) ?Sqe {
//     if (c.io_uring_get_sqe128(ring._io_uring)) |sqe| {
//         // std.debug.print("\nio_uring_get_sqe: {any}\n\n", .{sqe});
//         return .{ ._parent = .{ ._sqe = @ptrCast(&sqe[0]) }, ._len = 1, ._io_uring_sqe = sqe };
//     }
//     return null; // None
// }

const liburingVersionMajorDoc =
    \\Liburing Version Major 
    \\
    \\Note
    \\    - `io_uring_major_version` has been renamed to `liburing_version_major`
; // liburing_version_major
inline fn liburingVersionMajor() i32 {
    return c.io_uring_major_version();
}

const liburingVersionMinorDoc =
    \\Liburing Version Minor 
    \\
    \\Note
    \\    - `io_uring_minor_version` has been renamed to `liburing_version_minor`
; // liburing_version_minor
inline fn liburingVersionMinor() i32 {
    return c.io_uring_minor_version();
}

const liburingVersionCheckDoc =
    \\Liburing Version Check
    \\
    \\Note
    \\    - `io_uring_check_version` has been renamed to `liburing_version_check`
; // liburing_version_check
inline fn liburingVersionCheck(major: u16, minor: u16) bool {
    return c.io_uring_check_version(major, minor);
}
