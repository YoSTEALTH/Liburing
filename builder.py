import cffi

__all__ = ('ffi',)


ffi = cffi.FFI()

# Python callback in C
# ffi.cdef('''
#     /* `lib.trap_error` callback */
#     extern "Python" int trap_error(int);
# ''')


# Install from source files.
ffi.set_source('liburing._liburing',
               '#include <liburing.h>',
               sources=['src/queue.c', 'src/register.c', 'src/setup.c', 'src/syscall.c'],
               include_dirs=['src/include'])

# Custom types
ffi.cdef('''
    typedef ... socklen_t;
    typedef ... igset_t;
    typedef ... mode_t;
    typedef ... __u64;

    /*
        typedef ... off_t;
        TypeError: 'off_t' is opaque - meaning system or gcc doesn't support it
    */
    typedef long int __off_t;
    typedef __off_t off_t;

    /*
        typedef ... sigset_t;
        TypeError: initializer for ctype 'sigset_t *' must be a cdata pointer, not NoneType
    */
    struct __sigset_t { ...; };
    typedef struct __sigset_t sigset_t;

    int sigemptyset(sigset_t *set);
    int sigaddset(sigset_t *set, int signum);

    const struct iovec {
        void * iov_base;    // starting address
        size_t iov_len;     // number of bytes to transfer
    };
''')

# liburing.h
ffi.cdef('''
    struct __kernel_timespec {
        int64_t     tv_sec;
        long long   tv_nsec;
    };

    /*
     * Library interface to io_uring
     * note: can get with using ...; as all the fields are populated by C function
     */
    struct io_uring { ... ; };

    /*
     * Library interface
     */
    extern int io_uring_queue_init_params(unsigned entries,
                                          struct io_uring *ring,
                                          struct io_uring_params *p);
    extern int io_uring_queue_init(unsigned entries,
                                   struct io_uring *ring,
                                   unsigned flags);
    extern int io_uring_queue_mmap(int fd,
                                   struct io_uring_params *p,
                                   struct io_uring *ring);
    extern void io_uring_queue_exit(struct io_uring *ring);
    unsigned io_uring_peek_batch_cqe(struct io_uring *ring,
                                     struct io_uring_cqe **cqes,
                                     unsigned count);
    extern int io_uring_wait_cqes(struct io_uring *ring,
                                  struct io_uring_cqe **cqe_ptr,
                                  unsigned wait_nr,
                                  struct __kernel_timespec *ts,
                                  sigset_t *sigmask);
    extern int io_uring_wait_cqe_timeout(struct io_uring *ring,
                                         struct io_uring_cqe **cqe_ptr,
                                         struct __kernel_timespec *ts);
    extern int io_uring_submit(struct io_uring *ring);
    extern int io_uring_submit_and_wait(struct io_uring *ring, unsigned wait_nr);
    extern struct io_uring_sqe *io_uring_get_sqe(struct io_uring *ring);

    extern int io_uring_register_buffers(struct io_uring *ring,
                                         const struct iovec *iovecs,
                                         unsigned nr_iovecs);
    extern int io_uring_unregister_buffers(struct io_uring *ring);
    extern int io_uring_register_files(struct io_uring *ring,
                                       const int *files,
                                       unsigned nr_files);
    extern int io_uring_unregister_files(struct io_uring *ring);
    extern int io_uring_register_files_update(struct io_uring *ring,
                                              unsigned off,
                                              int *files,
                                              unsigned nr_files);
    extern int io_uring_register_eventfd(struct io_uring *ring, int fd);
    extern int io_uring_unregister_eventfd(struct io_uring *ring);
''')

# helper & prep functions
ffi.cdef('''
    /*
     * SKIPPING - this function should not be called directly.
     * extern int __io_uring_get_cqe(struct io_uring *ring,
     *                               struct io_uring_cqe **cqe_ptr,
     *                               unsigned submit,
     *                               unsigned wait_nr,
     *                               igset_t *sigmask);
     */

    #define LIBURING_UDATA_TIMEOUT ...

    // TODO: parsing Error
    // #define io_uring_for_each_cqe(ring, head, cqe);

    /*
     * Must be called after io_uring_for_each_cqe()
     */
    static inline void io_uring_cq_advance(struct io_uring *ring, unsigned nr);

    /*
     * Must be called after io_uring_{peek,wait}_cqe() after the cqe has
     * been processed by the application.
     */
    static inline void io_uring_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe);

    /*
     * Command prep helpers
     */
    static inline void io_uring_sqe_set_data(struct io_uring_sqe *sqe, void *data);
    static inline void *io_uring_cqe_get_data(struct io_uring_cqe *cqe);
    static inline void io_uring_sqe_set_flags(struct io_uring_sqe *sqe, unsigned flags);
    static inline void io_uring_prep_rw(int op,
                                        struct io_uring_sqe *sqe,
                                        int fd,
                                        const void *addr,
                                        unsigned len,
                                        __u64 offset);
    static inline void io_uring_prep_readv(struct io_uring_sqe *sqe,
                                           int fd,
                                           const struct iovec *iovecs,
                                           unsigned nr_vecs,
                                           off_t offset);
    static inline void io_uring_prep_read_fixed(struct io_uring_sqe *sqe,
                                                int fd,
                                                void *buf,
                                                unsigned nbytes,
                                                off_t offset,
                                                int buf_index);
    static inline void io_uring_prep_writev(struct io_uring_sqe *sqe,
                                            int fd,
                                            const struct iovec *iovecs,
                                            unsigned nr_vecs,
                                            off_t offset);
    static inline void io_uring_prep_write_fixed(struct io_uring_sqe *sqe,
                                                 int fd,
                                                 const void *buf,
                                                 unsigned nbytes,
                                                 off_t offset,
                                                 int buf_index);
    static inline void io_uring_prep_recvmsg(struct io_uring_sqe *sqe,
                                             int fd,
                                             struct msghdr *msg,
                                             unsigned flags);
    static inline void io_uring_prep_sendmsg(struct io_uring_sqe *sqe,
                                             int fd,
                                             const struct msghdr *msg,
                                             unsigned flags);
    static inline void io_uring_prep_poll_add(struct io_uring_sqe *sqe, int fd, short poll_mask);
    static inline void io_uring_prep_poll_remove(struct io_uring_sqe *sqe, void *user_data);
    static inline void io_uring_prep_fsync(struct io_uring_sqe *sqe, int fd, unsigned fsync_flags);
    static inline void io_uring_prep_nop(struct io_uring_sqe *sqe);
    static inline void io_uring_prep_timeout(struct io_uring_sqe *sqe,
                                             struct __kernel_timespec *ts,
                                             unsigned count,
                                             unsigned flags);
    static inline void io_uring_prep_timeout_remove(struct io_uring_sqe *sqe,
                                                    __u64 user_data,
                                                    unsigned flags);
    static inline void io_uring_prep_accept(struct io_uring_sqe *sqe,
                                            int fd,
                                            struct sockaddr *addr,
                                            socklen_t *addrlen,
                                            int flags);
    static inline void io_uring_prep_cancel(struct io_uring_sqe *sqe, void *user_data, int flags);
    static inline void io_uring_prep_link_timeout(struct io_uring_sqe *sqe,
                                                  struct __kernel_timespec *ts,
                                                  unsigned flags);
    static inline void io_uring_prep_connect(struct io_uring_sqe *sqe,
                                             int fd,
                                             struct sockaddr *addr,
                                             socklen_t addrlen);
    static inline void io_uring_prep_files_update(struct io_uring_sqe *sqe,
                                                  int *fds,
                                                  unsigned nr_fds);
    static inline void io_uring_prep_fallocate(struct io_uring_sqe *sqe,
                                               int fd,
                                               int mode,
                                               off_t offset,
                                               off_t len);
    static inline void io_uring_prep_openat(struct io_uring_sqe *sqe,
                                            int dfd,
                                            const char *path,
                                            int flags,
                                            mode_t mode);
    static inline void io_uring_prep_close(struct io_uring_sqe *sqe, int fd);

    struct statx;
    static inline void io_uring_prep_statx(struct io_uring_sqe *sqe,
                                           int dfd,
                                           const char *path,
                                           int flags,
                                           unsigned mask,
                                           struct statx *statxbuf);
    static inline unsigned io_uring_sq_ready(struct io_uring *ring);
    static inline unsigned io_uring_sq_space_left(struct io_uring *ring);
    static inline unsigned io_uring_cq_ready(struct io_uring *ring);

    /*
     * SKIPPING - should use `io_uring_peek_cqe` or `io_uring_wait_cqe`
     * static int __io_uring_peek_cqe(struct io_uring *ring, struct io_uring_cqe **cqe_ptr);
     */

    /*
     * Return an IO completion, waiting for 'wait_nr' completions if one isn't
     * readily available. Returns 0 with cqe_ptr filled in on success, -errno on
     * failure.
     */
    static inline int io_uring_wait_cqe_nr(struct io_uring *ring,
                                           struct io_uring_cqe **cqe_ptr,
                                           unsigned wait_nr);

    /*
     * Return an IO completion, if one is readily available. Returns 0 with
     * cqe_ptr filled in on success, -errno on failure.
     */
    static inline int io_uring_peek_cqe(struct io_uring *ring,
                                        struct io_uring_cqe **cqe_ptr);

    /*
     * Return an IO completion, waiting for it if necessary. Returns 0 with
     * cqe_ptr filled in on success, -errno on failure.
     */
    static inline int io_uring_wait_cqe(struct io_uring *ring,
                                        struct io_uring_cqe **cqe_ptr);
''')

# compat.h
ffi.cdef('''
    //
    typedef ... __kernel_rwf_t;
''')

# io_uring.h
ffi.cdef('''
    /* IO submission data structure (Submission Queue Entry) */
    struct io_uring_sqe { ...; };

    /* sqe->flags */
    #define IOSQE_FIXED_FILE    ...
    #define IOSQE_IO_DRAIN      ...
    #define IOSQE_IO_LINK       ...
    #define IOSQE_IO_HARDLINK   ...
    #define IOSQE_ASYNC         ...

    /* io_uring_setup() flags */
    #define IORING_SETUP_IOPOLL     ...
    #define IORING_SETUP_SQPOLL     ...
    #define IORING_SETUP_SQ_AFF     ...
    #define IORING_SETUP_CQSIZE     ...

    enum {
        IORING_OP_NOP,
        IORING_OP_READV,
        IORING_OP_WRITEV,
        IORING_OP_FSYNC,
        IORING_OP_READ_FIXED,
        IORING_OP_WRITE_FIXED,
        IORING_OP_POLL_ADD,
        IORING_OP_POLL_REMOVE,
        IORING_OP_SYNC_FILE_RANGE,
        IORING_OP_SENDMSG,
        IORING_OP_RECVMSG,
        IORING_OP_TIMEOUT,
        IORING_OP_TIMEOUT_REMOVE,
        IORING_OP_ACCEPT,
        IORING_OP_ASYNC_CANCEL,
        IORING_OP_LINK_TIMEOUT,
        IORING_OP_CONNECT,
        IORING_OP_FALLOCATE,
        IORING_OP_OPENAT,
        IORING_OP_CLOSE,
        IORING_OP_FILES_UPDATE,
        IORING_OP_STATX,

        /* this goes last, obviously */
        IORING_OP_LAST,
    };

    /* sqe->fsync_flags */
    #define IORING_FSYNC_DATASYNC   ...

    /* sqe->timeout_flags */
    #define IORING_TIMEOUT_ABS      ...

    /* IO completion data structure (Completion Queue Entry) */
    struct io_uring_cqe { ...; };

    /* Magic offsets for the application to mmap the data it needs */
    #define IORING_OFF_SQ_RING      ...
    #define IORING_OFF_CQ_RING      ...
    #define IORING_OFF_SQES         ...

    /* Filled with the offset for mmap(2) */
    struct io_sqring_offsets { ...; };

    /* sq_ring->flags */
    #define IORING_SQ_NEED_WAKEUP   ...

    struct io_cqring_offsets { ...; };

    /* io_uring_enter(2) flags */
    #define IORING_ENTER_GETEVENTS      ...
    #define IORING_ENTER_SQ_WAKEUP      ...

    /* Passed in for io_uring_setup(2). Copied back with updated info on success */
    struct io_uring_params { ...; };


    /* io_uring_params->features flags */
    #define IORING_FEAT_SINGLE_MMAP     ...
    #define IORING_FEAT_NODROP          ...
    #define IORING_FEAT_SUBMIT_STABLE   ...

    /* io_uring_register(2) opcodes and arguments */
    #define IORING_REGISTER_BUFFERS         ...
    #define IORING_UNREGISTER_BUFFERS       ...
    #define IORING_REGISTER_FILES           ...
    #define IORING_UNREGISTER_FILES         ...
    #define IORING_REGISTER_EVENTFD         ...
    #define IORING_UNREGISTER_EVENTFD       ...
    #define IORING_REGISTER_FILES_UPDATE    ...

    struct io_uring_files_update { ...; };
''')


if __name__ == '__main__':
    ffi.compile(verbose=True, tmpdir='./build')
