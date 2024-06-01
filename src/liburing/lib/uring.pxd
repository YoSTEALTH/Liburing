from .type cimport *
from .file cimport *
from .poll cimport *
from .statx cimport *
from .futex cimport *
from .socket cimport *
from .io_uring cimport *


cdef extern from '../include/liburing.h' nogil:
    ''' // macro function
        static inline unsigned __io_uring_for_each_cqe(struct io_uring* ring,
                                                   struct io_uring_cqe* cqe)
        {
            unsigned head;
            unsigned count = 0;

            io_uring_for_each_cqe(ring, head, cqe){
                count++;
            }
            return count;
        }
    '''
    # Library interface to `io_uring`
    # -------------------------------
    struct __io_uring_sq 'io_uring_sq':
        unsigned int*   khead
        unsigned int*   ktail

        unsigned int*   kflags
        unsigned int*   kdropped
        unsigned int*   array
        __io_uring_sqe* sqes

        unsigned int    sqe_head
        unsigned int    sqe_tail

        size_t          ring_sz
        void*           ring_ptr

        unsigned int    ring_mask
        unsigned int    ring_entries

        unsigned int    pad[2]

    struct __io_uring_cq 'io_uring_cq':
        unsigned int*   khead
        unsigned int*   ktail

        unsigned int*   kflags
        unsigned int*   koverflow
        __io_uring_cqe* cqes

        size_t          ring_sz
        void*           ring_ptr

        unsigned int    ring_mask
        unsigned int    ring_entries

        unsigned int    pad[2]

    struct __io_uring 'io_uring':
        __io_uring_sq   sq
        __io_uring_cq   cq
        unsigned int    flags
        int             ring_fd

        unsigned int    features
        int             enter_ring_fd
        __u8            int_flags
        __u8            pad[3]
        unsigned int    pad2

    # Library interface
    # -----------------
    # return an allocated io_uring_probe structure, or NULL if probe fails (for
    # example, if it is not available). The caller is responsible for freeing it
    __io_uring_probe* __io_uring_get_probe_ring 'io_uring_get_probe_ring'(__io_uring* ring)
    # same as `io_uring_get_probe_ring`, but takes care of ring init and teardown
    __io_uring_probe* __io_uring_get_probe 'io_uring_get_probe'()  # note: (void) is removed
    # frees a probe allocated through `io_uring_get_probe()` or `io_uring_get_probe_ring()`
    void __io_uring_free_probe 'io_uring_free_probe'(__io_uring_probe* probe)

    bint __io_uring_opcode_supported 'io_uring_opcode_supported'(__io_uring_probe* p,
                                                                 int op)

    int __io_uring_queue_init_mem 'io_uring_queue_init_mem'(unsigned int entries,
                                                            __io_uring* ring,
                                                            __io_uring_params* p,
                                                            void* buf,
                                                            size_t buf_size)
    int __io_uring_queue_init_params 'io_uring_queue_init_params'(unsigned int entries,
                                                                  __io_uring* ring,
                                                                  __io_uring_params* p)
    int __io_uring_queue_init 'io_uring_queue_init'(unsigned int entries,
                                                    __io_uring* ring,
                                                    unsigned int flags)
    int __io_uring_queue_mmap 'io_uring_queue_mmap'(int fd,
                                                    __io_uring_params* p,
                                                    __io_uring* ring)
    int __io_uring_ring_dontfork 'io_uring_ring_dontfork'(__io_uring* ring)
    void __io_uring_queue_exit 'io_uring_queue_exit'(__io_uring* ring)
    unsigned int __io_uring_peek_batch_cqe 'io_uring_peek_batch_cqe'(__io_uring* ring,
                                                                     __io_uring_cqe **cqes,
                                                                     unsigned int count)
    int __io_uring_wait_cqes 'io_uring_wait_cqes'(__io_uring* ring,
                                                  __io_uring_cqe **cqe_ptr,
                                                  unsigned int wait_nr,
                                                  __kernel_timespec* ts,
                                                  sigset_t* sigmask)
    int __io_uring_wait_cqe_timeout 'io_uring_wait_cqe_timeout'(__io_uring* ring,
                                                                __io_uring_cqe **cqe_ptr,
                                                                __kernel_timespec* ts)
    int __io_uring_submit 'io_uring_submit'(__io_uring* ring)
    int __io_uring_submit_and_wait 'io_uring_submit_and_wait'(__io_uring* ring,
                                                              unsigned int wait_nr)
    int __io_uring_submit_and_wait_timeout 'io_uring_submit_and_wait_timeout'(
                                                __io_uring* ring,
                                                __io_uring_cqe **cqe_ptr,
                                                unsigned int wait_nr,
                                                __kernel_timespec* ts,
                                                sigset_t* sigmask)

    int __io_uring_register_buffers 'io_uring_register_buffers'(__io_uring* ring,
                                                                const __iovec* iovecs,
                                                                unsigned int nr_iovecs)
    int __io_uring_register_buffers_tags 'io_uring_register_buffers_tags'(__io_uring* ring,
                                                                          const __iovec* iovecs,
                                                                          const __u64* tags,
                                                                          unsigned int nr)
    int __io_uring_register_buffers_sparse 'io_uring_register_buffers_sparse'(__io_uring* ring,
                                                                              unsigned int nr)
    int __io_uring_register_buffers_update_tag 'io_uring_register_buffers_update_tag'(
                                                    __io_uring* ring,
                                                    unsigned int off,
                                                    const __iovec* iovecs,
                                                    const __u64* tags,
                                                    unsigned int nr)
    int __io_uring_unregister_buffers 'io_uring_unregister_buffers'(__io_uring* ring)

    int __io_uring_register_files 'io_uring_register_files'(__io_uring* ring,
                                                            const int* files,
                                                            unsigned int nr_files)
    int __io_uring_register_files_tags 'io_uring_register_files_tags'(__io_uring* ring,
                                                                      const int* files,
                                                                      const __u64* tags,
                                                                      unsigned int nr)
    int __io_uring_register_files_sparse 'io_uring_register_files_sparse'(__io_uring* ring,
                                                                          unsigned int nr)
    int __io_uring_register_files_update_tag 'io_uring_register_files_update_tag'(
                                                __io_uring* ring,
                                                unsigned int off,
                                                const int* files,
                                                const __u64* tags,
                                                unsigned int nr_files)
    
    int __io_uring_unregister_files 'io_uring_unregister_files'(__io_uring* ring)
    int __io_uring_register_files_update 'io_uring_register_files_update'(__io_uring* ring,
                                                                          unsigned int off,
                                                                          const int* files,
                                                                          unsigned int nr_files)
    int __io_uring_register_eventfd 'io_uring_register_eventfd'(__io_uring* ring,
                                                                int fd)
    int __io_uring_register_eventfd_async 'io_uring_register_eventfd_async'(__io_uring* ring,
                                                                            int fd)
    int __io_uring_unregister_eventfd 'io_uring_unregister_eventfd'(__io_uring* ring)
    int __io_uring_register_probe 'io_uring_register_probe'(__io_uring* ring,
                                                            __io_uring_probe* p,
                                                            unsigned int nr)
    int __io_uring_register_personality 'io_uring_register_personality'(__io_uring* ring)
    int __io_uring_unregister_personality 'io_uring_unregister_personality'(__io_uring* ring,
                                                                            int id)
    int __io_uring_register_restrictions 'io_uring_register_restrictions'(
                                            __io_uring* ring,
                                            __io_uring_restriction* res,
                                            unsigned int nr_res)
    int __io_uring_enable_rings 'io_uring_enable_rings'(__io_uring* ring)
    int __io_uring_register_iowq_aff 'io_uring_register_iowq_aff'(__io_uring* ring,
                                                                  size_t cpusz,
                                                                  const cpu_set_t* mask)
    int __io_uring_unregister_iowq_aff 'io_uring_unregister_iowq_aff'(__io_uring* ring)
    int __io_uring_register_iowq_max_workers 'io_uring_register_iowq_max_workers'(
            __io_uring* ring,
            unsigned int* values)
    int __io_uring_register_ring_fd 'io_uring_register_ring_fd'(__io_uring* ring)
    int __io_uring_unregister_ring_fd 'io_uring_unregister_ring_fd'(__io_uring* ring)
    int __io_uring_close_ring_fd 'io_uring_close_ring_fd'(__io_uring* ring)
    int __io_uring_register_buf_ring 'io_uring_register_buf_ring'(__io_uring* ring,
                                                                  __io_uring_buf_reg* reg,
                                                                  unsigned int flags)
    int __io_uring_unregister_buf_ring 'io_uring_unregister_buf_ring'(__io_uring* ring,
                                                                      int bgid)
    int __io_uring_buf_ring_head 'io_uring_buf_ring_head'(__io_uring* ring,
                                                          int buf_group,
                                                          uint16_t* head)
    int __io_uring_register_sync_cancel 'io_uring_register_sync_cancel'(
                                            __io_uring* ring,
                                            __io_uring_sync_cancel_reg* reg)

    int __io_uring_register_file_alloc_range 'io_uring_register_file_alloc_range'(
            __io_uring* ring,
            unsigned int off,
            unsigned int len)

    int __io_uring_register_napi 'io_uring_register_napi'(__io_uring* ring,
                                                          __io_uring_napi* napi)
    int __io_uring_unregister_napi 'io_uring_unregister_napi'(__io_uring* ring,
                                                              __io_uring_napi* napi)

    int __io_uring_get_events 'io_uring_get_events'(__io_uring* ring)
    int __io_uring_submit_and_get_events 'io_uring_submit_and_get_events'(__io_uring* ring)

    # io_uring syscalls.
    int __io_uring_enter 'io_uring_enter'(unsigned int fd,
                                          unsigned int to_submit,
                                          unsigned int min_complete,
                                          unsigned int flags,
                                          sigset_t* sig)
    int __io_uring_enter2 'io_uring_enter2'(unsigned int fd,
                                            unsigned int to_submit,
                                            unsigned int min_complete,
                                            unsigned int flags,
                                            sigset_t* sig,
                                            size_t sz)
    int __io_uring_setup 'io_uring_setup'(unsigned int entries,
                                          __io_uring_params* p)
    int __io_uring_register 'io_uring_register'(unsigned int fd,
                                                unsigned int opcode,
                                                const void* arg,
                                                unsigned int nr_args)

    # Mapped buffer ring alloc/register + unregister/free helpers
    __io_uring_buf_ring* __io_uring_setup_buf_ring 'io_uring_setup_buf_ring'(
        __io_uring* ring,
        unsigned int nentries,
        int bgid,
        unsigned int flags,
        int* ret)
    int __io_uring_free_buf_ring 'io_uring_free_buf_ring'(__io_uring* ring,
                                                          __io_uring_buf_ring* br,
                                                          unsigned int nentries,
                                                          int bgid)

    enum: __LIBURING_UDATA_TIMEOUT 'LIBURING_UDATA_TIMEOUT'

    # Calculates the step size for CQE iteration.
    bint __io_uring_cqe_shift 'io_uring_cqe_shift'(__io_uring* ring)
    int __io_uring_cqe_index 'io_uring_cqe_index'(__io_uring* ring,
                                                  unsigned int ptr,
                                                  unsigned int mask)
    unsigned int __io_uring_for_each_cqe(__io_uring* ring, __io_uring_cqe* cqe)

    # Must be called after `io_uring_for_each_cqe()`
    void __io_uring_cq_advance 'io_uring_cq_advance'(__io_uring* ring,
                                                     unsigned int nr)
    # Must be called after `io_uring_{peek,wait}_cqe()` after the cqe has
    # been processed by the application.
    void __io_uring_cqe_seen 'io_uring_cqe_seen'(__io_uring* ring,
                                                 __io_uring_cqe* cqe)

    # Command prep helpers
    # --------------------
    # Associate pointer `data` with the `sqe`, for later retrieval from the `cqe`
    # at command completion time with `io_uring_cqe_get_data()`.
    void __io_uring_sqe_set_data 'io_uring_sqe_set_data'(__io_uring_sqe* sqe,
                                                         void* data)
    void* __io_uring_cqe_get_data 'io_uring_cqe_get_data'(const __io_uring_cqe* cqe)
    # Assign a 64-bit value to this `sqe`, which can get retrieved at completion
    # time with `io_uring_cqe_get_data64`. Just like the non-64 variants, except
    # these store a 64-bit type rather than a data pointer.
    void __io_uring_sqe_set_data64 'io_uring_sqe_set_data64'(__io_uring_sqe* sqe,
                                                             __u64 data)
    __u64 __io_uring_cqe_get_data64 'io_uring_cqe_get_data64'(const __io_uring_cqe* cqe)

    # Tell the app whether to use 64-bit variants of the `get/set->userdata`
    bint __LIBURING_HAVE_DATA64 'LIBURING_HAVE_DATA64'

    void __io_uring_sqe_set_flags 'io_uring_sqe_set_flags'(__io_uring_sqe* sqe,
                                                           unsigned int flags)
    # note: access to cython users only
    void __io_uring_prep_rw 'io_uring_prep_rw'(int op,
                                               __io_uring_sqe* sqe,
                                               int fd,
                                               const void* addr,
                                               unsigned int len,
                                               __u64 offset)

    # `io_uring_prep_splice()` - Either `fd_in` or `fd_out` must be a pipe.
    #
    # - If `fd_in` refers to a pipe, `off_in` is ignored and must be set to `-1`.
    #
    # - If `fd_in` does not refer to a pipe and `off_in` is `-1`, then `nbytes` are read
    #   from `fd_in` starting from the file offset, which is incremented by the
    #   number of bytes read.
    #
    # - If `fd_in` does not refer to a pipe and `off_in` is not `-1`, then the starting
    #   offset of `fd_in` will be `off_in`.
    #
    # This splice operation can be used to implement sendfile by splicing to an
    # intermediate pipe first, then splice to the final destination.
    # In fact, the implementation of sendfile in kernel uses splice internally.
    #
    # NOTE that even if `fd_in` or `fd_out` refers to a pipe, the splice operation
    # can still fail with `EINVAL` if one of the `fd_*` doesn't explicitly support splice
    # operation
    void __io_uring_prep_splice 'io_uring_prep_splice'(__io_uring_sqe* sqe,
                                                       int fd_in,
                                                       int64_t off_in,
                                                       int fd_out,
                                                       int64_t off_out,
                                                       unsigned int nbytes,
                                                       unsigned int splice_flags)
    void __io_uring_prep_tee 'io_uring_prep_tee'(__io_uring_sqe* sqe,
                                                 int fd_in,
                                                 int fd_out,
                                                 unsigned int nbytes,
                                                 unsigned int splice_flags)
    void __io_uring_prep_readv 'io_uring_prep_readv'(__io_uring_sqe* sqe,
                                                     int fd,
                                                     const __iovec* iovecs,
                                                     unsigned int nr_vecs,
                                                     __u64 offset)
    void __io_uring_prep_readv2 'io_uring_prep_readv2'(__io_uring_sqe* sqe,
                                                       int fd,
                                                       const __iovec* iovecs,
                                                       unsigned int nr_vecs,
                                                       __u64 offset,
                                                       int flags)
    void __io_uring_prep_read_fixed 'io_uring_prep_read_fixed'(__io_uring_sqe* sqe,
                                                               int fd,
                                                               void* buf,
                                                               unsigned int nbytes,
                                                               __u64 offset,
                                                               int buf_index)
    void __io_uring_prep_writev 'io_uring_prep_writev'(__io_uring_sqe* sqe,
                                                       int fd,
                                                       const __iovec* iovecs,
                                                       unsigned int nr_vecs,
                                                       __u64 offset)
    void __io_uring_prep_writev2 'io_uring_prep_writev2'(__io_uring_sqe* sqe,
                                                         int fd,
                                                         const __iovec* iovecs,
                                                         unsigned nr_vecs, __u64 offset,
                                                         int flags)
    void __io_uring_prep_write_fixed 'io_uring_prep_write_fixed'(__io_uring_sqe* sqe,
                                                                 int fd,
                                                                 const char* buf,
                                                                 unsigned int nbytes,
                                                                 __u64 offset,
                                                                 int buf_index)

    void __io_uring_prep_recvmsg 'io_uring_prep_recvmsg'(__io_uring_sqe* sqe,
                                                         int fd,
                                                         __msghdr* msg,
                                                         unsigned int flags)
    void __io_uring_prep_recvmsg_multishot 'io_uring_prep_recvmsg_multishot'(__io_uring_sqe* sqe,
                                                                             int fd, 
                                                                             __msghdr* msg,
                                                                             unsigned int flags)
    void __io_uring_prep_sendmsg 'io_uring_prep_sendmsg'(__io_uring_sqe* sqe,
                                                         int fd,
                                                         const __msghdr* msg,
                                                         unsigned int flags)

    void __io_uring_prep_poll_add 'io_uring_prep_poll_add'(__io_uring_sqe* sqe,
                                                           int fd,
                                                           unsigned int poll_mask)
    void __io_uring_prep_poll_multishot 'io_uring_prep_poll_multishot'(__io_uring_sqe* sqe,
                                                                       int fd,
                                                                       unsigned int poll_mask)
    void __io_uring_prep_poll_remove 'io_uring_prep_poll_remove'(__io_uring_sqe* sqe,
                                                                 __u64 user_data)
    void __io_uring_prep_poll_update 'io_uring_prep_poll_update'(__io_uring_sqe* sqe,
                                                                 __u64 old_user_data,
                                                                 __u64 new_user_data,
                                                                 unsigned int poll_mask,
                                                                 unsigned int flags)

    void __io_uring_prep_fsync 'io_uring_prep_fsync'(__io_uring_sqe* sqe,
                                                     int fd,
                                                     unsigned int fsync_flags)
    void __io_uring_prep_nop 'io_uring_prep_nop'(__io_uring_sqe* sqe)

    void __io_uring_prep_timeout 'io_uring_prep_timeout'(__io_uring_sqe* sqe,
                                                         __kernel_timespec* ts,
                                                         unsigned int count,
                                                         unsigned int flags)
    void __io_uring_prep_timeout_remove 'io_uring_prep_timeout_remove'(__io_uring_sqe* sqe,
                                                                       __u64 user_data,
                                                                       unsigned int flags)
    void __io_uring_prep_timeout_update 'io_uring_prep_timeout_update'(__io_uring_sqe* sqe,
                                                                       __kernel_timespec* ts,
                                                                       __u64 user_data,
                                                                       unsigned int flags)

    void __io_uring_prep_accept 'io_uring_prep_accept'(__io_uring_sqe* sqe,
                                                       int fd,
                                                       __sockaddr* addr,
                                                       socklen_t* addrlen,
                                                       int flags)
    # accept directly into the fixed file table
    void __io_uring_prep_accept_direct 'io_uring_prep_accept_direct'(__io_uring_sqe* sqe,
                                                                     int fd,
                                                                     __sockaddr* addr,
                                                                     socklen_t* addrlen,
                                                                     int flags,
                                                                     unsigned int file_index)
    void __io_uring_prep_multishot_accept 'io_uring_prep_multishot_accept'(__io_uring_sqe* sqe,
                                                                           int fd,
                                                                           __sockaddr* addr,
                                                                           socklen_t* addrlen,
                                                                           int flags)
    # multishot accept directly into the fixed file table
    void __io_uring_prep_multishot_accept_direct 'io_uring_prep_multishot_accept_direct'(
                                                    __io_uring_sqe* sqe,
                                                    int fd,
                                                    __sockaddr* addr,
                                                    socklen_t* addrlen,
                                                    int flags)

    void __io_uring_prep_cancel64 'io_uring_prep_cancel64'(__io_uring_sqe* sqe,
                                                           __u64 user_data,
                                                           int flags)
    void __io_uring_prep_cancel 'io_uring_prep_cancel'(__io_uring_sqe* sqe,
                                                       void* user_data,
                                                       int flags)
    void __io_uring_prep_cancel_fd 'io_uring_prep_cancel_fd'(__io_uring_sqe* sqe,
                                                             int fd,
                                                             unsigned int flags)

    void __io_uring_prep_link_timeout 'io_uring_prep_link_timeout'(__io_uring_sqe* sqe,
                                                                   __kernel_timespec* ts,
                                                                   unsigned int flags)

    void __io_uring_prep_connect 'io_uring_prep_connect'(__io_uring_sqe* sqe,
                                                         int fd,
                                                         const __sockaddr* addr,
                                                         socklen_t addrlen)

    void __io_uring_prep_files_update 'io_uring_prep_files_update'(__io_uring_sqe* sqe,
                                                                   int* fds,
                                                                   unsigned int nr_fds,
                                                                   int offset)

    void __io_uring_prep_fallocate 'io_uring_prep_fallocate'(__io_uring_sqe* sqe,
                                                             int fd,
                                                             int mode,
                                                             __u64 offset,
                                                             __u64 len)

    void __io_uring_prep_openat 'io_uring_prep_openat'(__io_uring_sqe* sqe,
                                                       int dfd,
                                                       const char* path,
                                                       int flags,
                                                       mode_t mode)
    # open directly into the fixed file table
    void __io_uring_prep_openat_direct 'io_uring_prep_openat_direct'(__io_uring_sqe* sqe,
                                                                     int dfd,
                                                                     const char* path,
                                                                     int flags,
                                                                     mode_t mode,
                                                                     unsigned int file_index)
    void __io_uring_prep_close 'io_uring_prep_close'(__io_uring_sqe* sqe,
                                                     int fd)
    void __io_uring_prep_close_direct 'io_uring_prep_close_direct'(__io_uring_sqe* sqe,
                                                                   unsigned int file_index)
    void __io_uring_prep_read 'io_uring_prep_read'(__io_uring_sqe* sqe,
                                                   int fd,
                                                   void* buf,
                                                   unsigned int nbytes,
                                                   __u64 offset)
    void __io_uring_prep_read_multishot 'io_uring_prep_read_multishot'(__io_uring_sqe* sqe,
                                                                       int fd,
                                                                       unsigned int nbytes,
                                                                       __u64 offset,
                                                                       int buf_group)
    void __io_uring_prep_write 'io_uring_prep_write'(__io_uring_sqe* sqe,
                                                     int fd,
                                                     const void* buf,
                                                     unsigned int nbytes,
                                                     __u64 offset)

    void __io_uring_prep_statx 'io_uring_prep_statx'(__io_uring_sqe* sqe,
                                                     int dfd,
                                                     const char* path,
                                                     int flags,
                                                     unsigned int mask,
                                                     __statx* statxbuf)

    void __io_uring_prep_fadvise 'io_uring_prep_fadvise'(__io_uring_sqe* sqe,
                                                         int fd,
                                                         __u64 offset,
                                                         off_t len,
                                                         int advice)
    void __io_uring_prep_madvise 'io_uring_prep_madvise'(__io_uring_sqe* sqe,
                                                         void* addr,
                                                         off_t length,
                                                         int advice)

    void __io_uring_prep_send 'io_uring_prep_send'(__io_uring_sqe* sqe,
                                                   int sockfd,
                                                   const void* buf,
                                                   size_t len,
                                                   int flags)
    void __io_uring_prep_send_set_addr 'io_uring_prep_send_set_addr'(__io_uring_sqe* sqe,
                                                                     const __sockaddr* dest_addr,
                                                                     __u16 addr_len)
    void __io_uring_prep_sendto 'io_uring_prep_sendto'(__io_uring_sqe* sqe,
                                                       int sockfd,
                                                       const void* buf,
                                                       size_t len,
                                                       int flags,
                                                       const __sockaddr* addr,
                                                       socklen_t addrlen)
    void __io_uring_prep_send_zc 'io_uring_prep_send_zc'(__io_uring_sqe* sqe,
                                                         int sockfd,
                                                         const void* buf,
                                                         size_t len,
                                                         int flags,
                                                         unsigned int zc_flags)
    void __io_uring_prep_send_zc_fixed 'io_uring_prep_send_zc_fixed'(__io_uring_sqe* sqe,
                                                                     int sockfd,
                                                                     const void* buf,
                                                                     size_t len,
                                                                     int flags,
                                                                     unsigned int zc_flags,
                                                                     unsigned int buf_index)
    void __io_uring_prep_sendmsg_zc 'io_uring_prep_sendmsg_zc'(__io_uring_sqe* sqe,
                                                               int fd,
                                                               const __msghdr* msg,
                                                               unsigned int flags)
    void __io_uring_prep_recv 'io_uring_prep_recv'(__io_uring_sqe* sqe,
                                                   int sockfd,
                                                   void* buf,
                                                   size_t len,
                                                   int flags)
    void __io_uring_prep_recv_multishot 'io_uring_prep_recv_multishot'(__io_uring_sqe* sqe,
                                                                       int sockfd,
                                                                       void* buf,
                                                                       size_t len,
                                                                       int flags)
    __io_uring_recvmsg_out* __io_uring_recvmsg_validate 'io_uring_recvmsg_validate'(
                                                            void* buf,
                                                            int buf_len,
                                                            __msghdr* msgh)
    void* __io_uring_recvmsg_name 'io_uring_recvmsg_name'(__io_uring_recvmsg_out* o)
    __cmsghdr* __io_uring_recvmsg_cmsg_firsthdr 'io_uring_recvmsg_cmsg_firsthdr'(
                                                    __io_uring_recvmsg_out* o,
                                                    __msghdr* msgh)
    __cmsghdr* __io_uring_recvmsg_cmsg_nexthdr 'io_uring_recvmsg_cmsg_nexthdr'(
                                                    __io_uring_recvmsg_out* o,
                                                    __msghdr* msgh,
                                                    __cmsghdr* cmsg)
    void* __io_uring_recvmsg_payload 'io_uring_recvmsg_payload'(__io_uring_recvmsg_out* o,
                                                                __msghdr* msgh)
    unsigned int __io_uring_recvmsg_payload_length 'io_uring_recvmsg_payload_length'(
                                                        __io_uring_recvmsg_out* o,
                                                        int buf_len,
                                                        __msghdr* msgh)

    void __io_uring_prep_openat2 'io_uring_prep_openat2'(__io_uring_sqe* sqe,
                                                         int dfd,
                                                         const char* path,
                                                         __open_how* how)
    # open directly into the fixed file table
    void __io_uring_prep_openat2_direct 'io_uring_prep_openat2_direct'(__io_uring_sqe* sqe,
                                                                       int dfd,
                                                                       const char* path,
                                                                       __open_how* how,
                                                                       unsigned int file_index)

    void __io_uring_prep_epoll_ctl 'io_uring_prep_epoll_ctl'(__io_uring_sqe* sqe,
                                                             int epfd,
                                                             int fd, int op,
                                                             __epoll_event* ev)
    
    void __io_uring_prep_provide_buffers 'io_uring_prep_provide_buffers'(__io_uring_sqe* sqe,
                                                                         void* addr,
                                                                         int len,
                                                                         int nr,
                                                                         int bgid,
                                                                         int bid)
    void __io_uring_prep_remove_buffers 'io_uring_prep_remove_buffers'(__io_uring_sqe* sqe,
                                                                       int nr,
                                                                       int bgid)

    void __io_uring_prep_shutdown 'io_uring_prep_shutdown'(__io_uring_sqe* sqe,
                                                           int fd,
                                                           int how)
    
    void __io_uring_prep_unlinkat 'io_uring_prep_unlinkat'(__io_uring_sqe* sqe,
                                                           int dfd,
                                                           const char* path,
                                                           int flags)
    void __io_uring_prep_unlink 'io_uring_prep_unlink'(__io_uring_sqe* sqe,
                                                       const char* path,
                                                       int flags)
    void __io_uring_prep_renameat 'io_uring_prep_renameat'(__io_uring_sqe* sqe,
                                                           int olddfd,
                                                           const char* oldpath,
                                                           int newdfd,
                                                           const char* newpath,
                                                           unsigned int flags)
    void __io_uring_prep_rename 'io_uring_prep_rename'(__io_uring_sqe* sqe,
                                                       const char* oldpath,
                                                       const char* newpath)
    void __io_uring_prep_sync_file_range 'io_uring_prep_sync_file_range'(__io_uring_sqe* sqe,
                                                                         int fd,
                                                                         unsigned int len,
                                                                         __u64 offset,
                                                                         int flags)
    void __io_uring_prep_mkdirat 'io_uring_prep_mkdirat'(__io_uring_sqe* sqe,
                                                         int dfd,
                                                         const char* path,
                                                         mode_t mode)
    void __io_uring_prep_mkdir 'io_uring_prep_mkdir'(__io_uring_sqe* sqe,
                                                     const char* path,
                                                     mode_t mode)
    void __io_uring_prep_symlinkat 'io_uring_prep_symlinkat'(__io_uring_sqe* sqe,
                                                             const char* target,
                                                             int newdirfd,
                                                             const char* linkpath)
    void __io_uring_prep_symlink 'io_uring_prep_symlink'(__io_uring_sqe* sqe,
                                                         const char* target,
                                                         const char* linkpath)
    void __io_uring_prep_linkat 'io_uring_prep_linkat'(__io_uring_sqe* sqe,
                                                       int olddfd,
                                                       const char* oldpath,
                                                       int newdfd,
                                                       const char* newpath,
                                                       int flags)
    void __io_uring_prep_link 'io_uring_prep_link'(__io_uring_sqe* sqe,
                                                   const char* oldpath,
                                                   const char* newpath,
                                                   int flags)

    void __io_uring_prep_msg_ring_cqe_flags 'io_uring_prep_msg_ring_cqe_flags'(
                                                __io_uring_sqe* sqe,
                                                int fd,
                                                unsigned int len,
                                                __u64 data,
                                                unsigned int flags,
                                                unsigned int cqe_flags)
    void __io_uring_prep_msg_ring 'io_uring_prep_msg_ring'(__io_uring_sqe* sqe,
                                                           int fd,
                                                           unsigned int len,
                                                           __u64 data,
                                                           unsigned int flags)
    void __io_uring_prep_msg_ring_fd 'io_uring_prep_msg_ring_fd'(__io_uring_sqe* sqe,
                                                                 int fd,
                                                                 int source_fd,
                                                                 int target_fd,
                                                                 __u64 data,
                                                                 unsigned int flags)
    void __io_uring_prep_msg_ring_fd_alloc 'io_uring_prep_msg_ring_fd_alloc'(__io_uring_sqe* sqe,
                                                                             int fd,
                                                                             int source_fd,
                                                                             __u64 data,
                                                                             unsigned int flags)

    void __io_uring_prep_getxattr 'io_uring_prep_getxattr'(__io_uring_sqe* sqe,
                                                           const char* name,
                                                           char* value,
                                                           const char* path,
                                                           unsigned int len)
    void __io_uring_prep_setxattr 'io_uring_prep_setxattr'(__io_uring_sqe* sqe,
                                                           const char* name,
                                                           const char* value,
                                                           const char* path,
                                                           int flags,
                                                           unsigned int len)
    void __io_uring_prep_fgetxattr 'io_uring_prep_fgetxattr'(__io_uring_sqe* sqe,
                                                             int fd,
                                                             const char* name,
                                                             char* value,
                                                             unsigned int len)
    void __io_uring_prep_fsetxattr 'io_uring_prep_fsetxattr'(__io_uring_sqe* sqe,
                                                             int fd,
                                                             const char* name,
                                                             const char* value,
                                                             int flags,
                                                             unsigned int len)

    void __io_uring_prep_socket 'io_uring_prep_socket'(__io_uring_sqe* sqe,
                                                       int domain,
                                                       int type,
                                                       int protocol,
                                                       unsigned int flags)

    void __io_uring_prep_socket_direct 'io_uring_prep_socket_direct'(__io_uring_sqe* sqe,
                                                                     int domain,
                                                                     int type,
                                                                     int protocol,
                                                                     unsigned int file_index,
                                                                     unsigned int flags)
    void __io_uring_prep_socket_direct_alloc 'io_uring_prep_socket_direct_alloc'(
                                                __io_uring_sqe* sqe,
                                                int domain,
                                                int type,
                                                int protocol,
                                                unsigned int flags)

    # Prepare commands for sockets
    void __io_uring_prep_cmd_sock 'io_uring_prep_cmd_sock'(__io_uring_sqe* sqe,
                                                           int cmd_op,
                                                           int fd,
                                                           int level,
                                                           int optname,
                                                           void* optval,
                                                           int optlen)

    void __io_uring_prep_waitid 'io_uring_prep_waitid'(__io_uring_sqe* sqe,
                                                       idtype_t idtype,
                                                       id_t id,
                                                       siginfo_t* infop,
                                                       int options,
                                                       unsigned int flags)

    void __io_uring_prep_futex_wake 'io_uring_prep_futex_wake'(__io_uring_sqe* sqe,
                                                               uint32_t* futex,
                                                               uint64_t val,
                                                               uint64_t mask,
                                                               uint32_t futex_flags,
                                                               unsigned int flags)
    void __io_uring_prep_futex_wait 'io_uring_prep_futex_wait'(__io_uring_sqe* sqe,
                                                               uint32_t* futex,
                                                               uint64_t val,
                                                               uint64_t mask,
                                                               uint32_t futex_flags,
                                                               unsigned int flags)
    void __io_uring_prep_futex_waitv 'io_uring_prep_futex_waitv'(__io_uring_sqe* sqe,
                                                                 __futex_waitv* futex,
                                                                 uint32_t nr_futex,
                                                                 unsigned int flags)

    void __io_uring_prep_fixed_fd_install 'io_uring_prep_fixed_fd_install'(__io_uring_sqe* sqe,
                                                                           int fd,
                                                                           unsigned int flags)

    void __io_uring_prep_ftruncate 'io_uring_prep_ftruncate'(__io_uring_sqe* sqe,
                                                             int fd,
                                                             loff_t len)

    # Returns number of unconsumed (if SQPOLL) or unsubmitted entries exist in the SQ ring
    unsigned int __io_uring_sq_ready 'io_uring_sq_ready'(const __io_uring* ring)
    # Returns how much space is left in the SQ ring.
    unsigned int __io_uring_sq_space_left 'io_uring_sq_space_left'(const __io_uring* ring)
    # Only applicable when using SQPOLL - allows the caller to wait for space
    # to free up in the SQ ring, which happens when the kernel side thread has
    # consumed one or more entries. If the SQ ring is currently non-full, no
    # action is taken. Note: may return -EINVAL if the kernel doesn't support
    # this feature.
    int __io_uring_sqring_wait 'io_uring_sqring_wait'(__io_uring* ring)
    # Returns how many unconsumed entries are ready in the CQ ring
    unsigned int __io_uring_cq_ready 'io_uring_cq_ready'(const __io_uring* ring)
    # Returns true if there are overflow entries waiting to be flushed onto the CQ ring
    bint __io_uring_cq_has_overflow 'io_uring_cq_has_overflow'(const __io_uring* ring)
    # Returns true if the eventfd notification is currently enabled
    bint __io_uring_cq_eventfd_enabled 'io_uring_cq_eventfd_enabled'(const __io_uring* ring)

    # Toggle eventfd notification on or off, if an eventfd is registered with the ring.
    int __io_uring_cq_eventfd_toggle 'io_uring_cq_eventfd_toggle'(__io_uring* ring,
                                                                  bint enabled)
    # Return an IO completion, waiting for `wait_nr` completions if one isn't
    # readily available. Returns `0` with `cqe_ptr` filled in on success, `-errno` on
    # failure.
    int __io_uring_wait_cqe_nr 'io_uring_wait_cqe_nr'(__io_uring* ring,
                                                      __io_uring_cqe **cqe_ptr,
                                                      unsigned int wait_nr)
    # Return an IO completion, if one is readily available. Returns `0` with
    # `cqe_ptr` filled in on success, `-errno` on failure.
    int __io_uring_peek_cqe 'io_uring_peek_cqe'(__io_uring* ring,
                                                __io_uring_cqe **cqe_ptr)
    # Return an IO completion, waiting for it if necessary. Returns `0` with
    # `cqe_ptr` filled in on success, `-errno` on failure.
    int __io_uring_wait_cqe 'io_uring_wait_cqe'(__io_uring* ring,
                                                __io_uring_cqe **cqe_ptr)
    # Return the appropriate mask for a buffer ring of size `ring_entries`
    int __io_uring_buf_ring_mask 'io_uring_buf_ring_mask'(__u32 ring_entries)
    void __io_uring_buf_ring_init 'io_uring_buf_ring_init'(__io_uring_buf_ring* br)
    # Assign `buf` with the addr/len/buffer ID supplied
    void __io_uring_buf_ring_add 'io_uring_buf_ring_add'(__io_uring_buf_ring* br,
                                                         void* addr,
                                                         unsigned int len,
                                                         unsigned short bid,
                                                         int mask,
                                                         int buf_offset)
    # Make 'count' new buffers visible to the kernel. Called after
    # `io_uring_buf_ring_add()` has been called `count` times to fill in new buffers.
    void __io_uring_buf_ring_advance 'io_uring_buf_ring_advance'(__io_uring_buf_ring* br,
                                                                 int count)
    # Make `count` new buffers visible to the kernel while at the same time
    # advancing the CQ ring seen entries. This can be used when the application
    # is using ring provided buffers and returns buffers while processing CQEs,
    # avoiding an extra atomic when needing to increment both the CQ ring and
    # the ring buffer index at the same time.
    void __io_uring_buf_ring_cq_advance 'io_uring_buf_ring_cq_advance'(__io_uring* ring,
                                                                       __io_uring_buf_ring* br,
                                                                       int count)
    int __io_uring_buf_ring_available 'io_uring_buf_ring_available'(__io_uring* ring,
                                                                    __io_uring_buf_ring* br,
                                                                    unsigned short bgid)
    # Return an sqe to fill. Application must later call `io_uring_submit()`
    # when it's ready to tell the kernel about it. The caller may call this
    # function multiple times before calling `io_uring_submit()`.
    #
    # Returns a vacant `sqe`, or `NULL` if we're full.
    __io_uring_sqe* __io_uring_get_sqe 'io_uring_get_sqe'(__io_uring* ring)

    ssize_t __io_uring_mlock_size 'io_uring_mlock_size'(unsigned int entries,
                                                        unsigned int flags)
    ssize_t __io_uring_mlock_size_params 'io_uring_mlock_size_params'(unsigned int entries,
                                                                      __io_uring_params* p)

    # Versioning information for liburing.
    # Use `io_uring_check_version()` for runtime checks of the version of
    # liburing that was loaded by the dynamic linker.
    __u8 __io_uring_major_version "io_uring_major_version"()
    __u8 __io_uring_minor_version "io_uring_minor_version"()
    bint __io_uring_check_version "io_uring_check_version"(__u8 major, __u8 minor)
