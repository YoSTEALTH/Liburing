import os
import cffi
import subprocess

__all__ = ('ffi',)


# Configure
os.chdir('./libs/liburing')
subprocess.run('./configure')
os.chdir('../../')


ffi = cffi.FFI()

# Install from source files.
ffi.set_source('liburing._liburing',
               ''' #include <fcntl.h>       /* statx(2) - Definition of AT_* constants */
                   #include <netinet/in.h>
                   #include "liburing.h" ''',
               sources=['./libs/liburing/src/queue.c',
                        './libs/liburing/src/register.c',
                        './libs/liburing/src/setup.c',
                        './libs/liburing/src/syscall.c'],
               include_dirs=['./libs/liburing/src/include'])


# Socket
ffi.cdef('''
    typedef int...  socklen_t;
    typedef int...  in_addr_t;
    typedef int...  sa_family_t;
    typedef int...  in_port_t;

    struct sockaddr {
        sa_family_t     sa_family;      /* AF_INET, AF_UNIX, AF_NS, AF_IMPLINK */
        char            sa_data[14];    /* Protocol-specific Address */
    };

    struct in_addr {
        in_addr_t       s_addr;         /* Service Port */
    };

    struct sockaddr_in {
        sa_family_t     sin_family;     /* AF_INET, AF_UNIX, AF_NS, AF_IMPLINK */
        in_port_t       sin_port;       /* Service Port */
        struct  in_addr sin_addr;       /* IP Address */
        ...;
    };
''')


# Custom types
ffi.cdef('''
    typedef int...  __u8;
    typedef int...  __u16;
    typedef int...  __s32;
    typedef int...  __u32;
    typedef int...  __s64;
    typedef int...  __u64;

    typedef int...  off_t;
    typedef int...  loff_t;
    typedef int...  mode_t;
    typedef ...     igset_t;
    typedef int...  __aligned_u64;
    typedef int...  __kernel_rwf_t;

    /*
     * TypeError: initializer for ctype 'sigset_t *' must be a cdata pointer, not NoneType
     */
    struct __sigset_t { ...; };
    typedef struct __sigset_t sigset_t;

    /* `sigmask` */
    int sigemptyset(sigset_t *set);
    int sigaddset(sigset_t *set, int signum);

    const struct iovec {
        void * iov_base;    // starting address
        size_t iov_len;     // number of bytes to transfer
    };

    /*
     * Note: Bellow structs are needed or else error is raised while using, even though they are
     *       defined in `configure` file.
     */
    struct __kernel_timespec {
        int64_t     tv_sec;
        long long   tv_nsec;
    };

    struct open_how {
        uint64_t    flags;
        uint64_t    mode;
        uint64_t    resolve;
    };
''')


# liburing.h
ffi.cdef('''
    /*
     * Library interface to io_uring
     */
    struct io_uring_sq {
        unsigned *khead;
        unsigned *ktail;
        unsigned *kring_mask;
        unsigned *kring_entries;
        unsigned *kflags;
        unsigned *kdropped;
        unsigned *array;
        struct io_uring_sqe *sqes;

        unsigned sqe_head;
        unsigned sqe_tail;

        size_t ring_sz;
        void *ring_ptr;
    };

    struct io_uring_cq {
        unsigned *khead;
        unsigned *ktail;
        unsigned *kring_mask;
        unsigned *kring_entries;
        unsigned *kflags;
        unsigned *koverflow;
        struct io_uring_cqe *cqes;

        size_t ring_sz;
        void *ring_ptr;
    };

    struct io_uring {
        struct io_uring_sq sq;
        struct io_uring_cq cq;
        unsigned flags;
        int ring_fd;
    };

    /*
     * Library interface
     */

    /*
     * return an allocated io_uring_probe structure, or NULL if probe fails (for
     * example, if it is not available). The caller is responsible for freeing it
     */
    extern struct io_uring_probe *io_uring_get_probe_ring(struct io_uring *ring);
    /* same as io_uring_get_probe_ring, but takes care of ring init and teardown */
    extern struct io_uring_probe *io_uring_get_probe(void);

    static inline int io_uring_opcode_supported(struct io_uring_probe *p, int op);

    extern int io_uring_queue_init_params(unsigned entries,
                                          struct io_uring *ring,
                                          struct io_uring_params *p);
    extern int io_uring_queue_init(unsigned entries,
                                   struct io_uring *ring,
                                   unsigned flags);
    extern int io_uring_queue_mmap(int fd,
                                   struct io_uring_params *p,
                                   struct io_uring *ring);
    extern int io_uring_ring_dontfork(struct io_uring *ring);
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
    extern int io_uring_register_eventfd_async(struct io_uring *ring, int fd);
    extern int io_uring_unregister_eventfd(struct io_uring *ring);
    extern int io_uring_register_probe(struct io_uring *ring,
                                       struct io_uring_probe *p,
                                       unsigned nr);
    extern int io_uring_register_personality(struct io_uring *ring);
    extern int io_uring_unregister_personality(struct io_uring *ring, int id);
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

    #define LIBURING_UDATA_TIMEOUT      ...

    /*
     * SKIPPING - use *peak* or *wait* functions
     * #define io_uring_for_each_cqe(ring, head, cqe);
     */

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
    static inline void *io_uring_cqe_get_data(const struct io_uring_cqe *cqe);
    static inline void io_uring_sqe_set_flags(struct io_uring_sqe *sqe, unsigned flags);
    static inline void io_uring_prep_rw(int op,
                                        struct io_uring_sqe *sqe,
                                        int fd,
                                        const void *addr,
                                        unsigned len,
                                        __u64 offset);
    static inline void io_uring_prep_splice(struct io_uring_sqe *sqe,
                                            int fd_in,
                                            loff_t off_in,
                                            int fd_out,
                                            loff_t off_out,
                                            unsigned int nbytes,
                                            unsigned int splice_flags);
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
                                                  unsigned nr_fds,
                                                  int offset);
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
    static inline void io_uring_prep_read(struct io_uring_sqe *sqe,
                                          int fd,
                                          void *buf,
                                          unsigned nbytes,
                                          off_t offset);
    static inline void io_uring_prep_write(struct io_uring_sqe *sqe,
                                           int fd,
                                           const void *buf,
                                           unsigned nbytes,
                                           off_t offset);
    /* struct statx; - added full struct */
    static inline void io_uring_prep_statx(struct io_uring_sqe *sqe,
                                           int dfd,
                                           const char *path,
                                           int flags,
                                           unsigned mask,
                                           struct statx *statxbuf);
    static inline void io_uring_prep_fadvise(struct io_uring_sqe *sqe,
                                             int fd,
                                             off_t offset,
                                             off_t len,
                                             int advice);
    static inline void io_uring_prep_madvise(struct io_uring_sqe *sqe,
                                             void *addr,
                                             off_t length,
                                             int advice);
    static inline void io_uring_prep_send(struct io_uring_sqe *sqe,
                                          int sockfd,
                                          const void *buf,
                                          size_t len,
                                          int flags);
    static inline void io_uring_prep_recv(struct io_uring_sqe *sqe,
                                          int sockfd,
                                          void *buf,
                                          size_t len,
                                          int flags);
    static inline void io_uring_prep_openat2(struct io_uring_sqe *sqe,
                                             int dfd,
                                             const char *path,
                                             struct open_how *how);
    struct epoll_event;
    static inline void io_uring_prep_epoll_ctl(struct io_uring_sqe *sqe,
                                               int epfd,
                                               int fd,
                                               int op,
                                               struct epoll_event *ev);
    static inline void io_uring_prep_provide_buffers(struct io_uring_sqe *sqe,
                                                     void *addr,
                                                     int len,
                                                     int nr,
                                                     int bgid,
                                                     int bid);
    static inline void io_uring_prep_remove_buffers(struct io_uring_sqe *sqe,
                                                    int nr,
                                                    int bgid);
    static inline unsigned io_uring_sq_ready(struct io_uring *ring);
    static inline unsigned io_uring_sq_space_left(struct io_uring *ring);
    static inline unsigned io_uring_cq_ready(struct io_uring *ring);

    static inline bool io_uring_cq_eventfd_enabled(struct io_uring *ring);
    static inline int io_uring_cq_eventfd_toggle(struct io_uring *ring,
                         bool enabled);

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


# io_uring.h
ffi.cdef('''
    /*
     * IO submission data structure (Submission Queue Entry)
     */
    struct io_uring_sqe {
        __u8    opcode;     /* type of operation for this sqe */
        __u8    flags;      /* IOSQE_ flags */
        __u16   ioprio;     /* ioprio for the request */
        __s32   fd;         /* file descriptor to do IO on */
        union {
            __u64   off;    /* offset into file */
            __u64   addr2;
        };
        union {
            __u64   addr;   /* pointer to buffer or iovecs */
            __u64   splice_off_in;
        };
        __u32   len;        /* buffer size or number of iovecs */
        union {
            __kernel_rwf_t  rw_flags;
            __u32       fsync_flags;
            __u16       poll_events;    /* compatibility */
            __u32       poll32_events;  /* word-reversed for BE */
            __u32       sync_range_flags;
            __u32       msg_flags;
            __u32       timeout_flags;
            __u32       accept_flags;
            __u32       cancel_flags;
            __u32       open_flags;
            __u32       statx_flags;
            __u32       fadvise_advice;
            __u32       splice_flags;
        };
        __u64   user_data;  /* data to be passed back at completion time */
        union {
            struct {
                /*
                 * // pack this to avoid bogus arm OABI complaints
                 * union {
                 *    __u16   buf_index;      // index into fixed buffers, if used
                 *    __u16   buf_group;      // for grouped buffer selection
                 * } __attribute__((packed));
                 */
                ...;
                __u16   personality;    /* personality to use, if used */
                __s32   splice_fd_in;
            };
            __u64   __pad2[3];
        };
    };

    enum {
        IOSQE_FIXED_FILE_BIT,
        IOSQE_IO_DRAIN_BIT,
        IOSQE_IO_LINK_BIT,
        IOSQE_IO_HARDLINK_BIT,
        IOSQE_ASYNC_BIT,
        IOSQE_BUFFER_SELECT_BIT,
    };

    /*
     * sqe->flags
     */
    #define IOSQE_FIXED_FILE        ...     /* use fixed fileset */
    #define IOSQE_IO_DRAIN          ...     /* issue after inflight IO */
    #define IOSQE_IO_LINK           ...     /* links next sqe */
    #define IOSQE_IO_HARDLINK       ...     /* like LINK, but stronger */
    #define IOSQE_ASYNC             ...     /* always go async */
    #define IOSQE_BUFFER_SELECT     ...     /* select buffer from sqe->buf_group */

    /*
     * io_uring_setup() flags
     */
    #define IORING_SETUP_IOPOLL     ...     /* io_context is polled */
    #define IORING_SETUP_SQPOLL     ...     /* SQ poll thread */
    #define IORING_SETUP_SQ_AFF     ...     /* sq_thread_cpu is valid */
    #define IORING_SETUP_CQSIZE     ...     /* app defines CQ size */
    #define IORING_SETUP_CLAMP      ...     /* clamp SQ/CQ ring sizes */
    #define IORING_SETUP_ATTACH_WQ  ...     /* attach to existing wq */

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
        IORING_OP_READ,
        IORING_OP_WRITE,
        IORING_OP_FADVISE,
        IORING_OP_MADVISE,
        IORING_OP_SEND,
        IORING_OP_RECV,
        IORING_OP_OPENAT2,
        IORING_OP_EPOLL_CTL,
        IORING_OP_SPLICE,
        IORING_OP_PROVIDE_BUFFERS,
        IORING_OP_REMOVE_BUFFERS,
        IORING_OP_TEE,

        /* this goes last, obviously */
        IORING_OP_LAST,
    };

    /*
     * sqe->fsync_flags
     */
    #define IORING_FSYNC_DATASYNC   ...

    /*
     * sqe->timeout_flags
     */
    #define IORING_TIMEOUT_ABS      ...

    /*
     * sqe->splice_flags
     * extends splice(2) flags
     */
    #define SPLICE_F_FD_IN_FIXED    ...     /* the last bit of __u32 */

    /*
     * IO completion data structure (Completion Queue Entry)
     */
    struct io_uring_cqe {
        __u64   user_data;  /* sqe->data submission passed back */
        __s32   res;        /* result code for this event */
        __u32   flags;
    };

    /*
     * cqe->flags
     *
     * IORING_CQE_F_BUFFER  If set, the upper 16 bits are the buffer ID
     */
    #define IORING_CQE_F_BUFFER     ...

    enum {
        IORING_CQE_BUFFER_SHIFT     = 16,
    };

    /*
     * Magic offsets for the application to mmap the data it needs
     */
    #define IORING_OFF_SQ_RING      ...
    #define IORING_OFF_CQ_RING      ...
    #define IORING_OFF_SQES         ...

    /*
     * Filled with the offset for mmap(2)
     */
    struct io_sqring_offsets {
        __u32 head;
        __u32 tail;
        __u32 ring_mask;
        __u32 ring_entries;
        __u32 flags;
        __u32 dropped;
        __u32 array;
        __u32 resv1;
        __u64 resv2;
    };

    /*
     * sq_ring->flags
     */
    #define IORING_SQ_NEED_WAKEUP       ...     /* needs io_uring_enter wakeup */
    #define IORING_SQ_CQ_OVERFLOW       ...     /* CQ ring is overflown */

    struct io_cqring_offsets {
        __u32 head;
        __u32 tail;
        __u32 ring_mask;
        __u32 ring_entries;
        __u32 overflow;
        __u32 cqes;
        __u32 flags;
        __u32 resv1;
        __u64 resv2;
    };

    /*
     * cq_ring->flags
     */

    /* disable eventfd notifications */
    #define IORING_CQ_EVENTFD_DISABLED  ...

    /*
     * io_uring_enter(2) flags
     */
    #define IORING_ENTER_GETEVENTS      ...
    #define IORING_ENTER_SQ_WAKEUP      ...

    /*
     * Passed in for io_uring_setup(2). Copied back with updated info on success
     */
    struct io_uring_params {
        __u32 sq_entries;
        __u32 cq_entries;
        __u32 flags;
        __u32 sq_thread_cpu;
        __u32 sq_thread_idle;
        __u32 features;
        __u32 wq_fd;
        __u32 resv[3];
        struct io_sqring_offsets sq_off;
        struct io_cqring_offsets cq_off;
    };

    /*
     * io_uring_params->features flags
     */
    #define IORING_FEAT_SINGLE_MMAP         ...
    #define IORING_FEAT_NODROP              ...
    #define IORING_FEAT_SUBMIT_STABLE       ...
    #define IORING_FEAT_RW_CUR_POS          ...
    #define IORING_FEAT_CUR_PERSONALITY     ...
    #define IORING_FEAT_FAST_POLL           ...
    #define IORING_FEAT_POLL_32BITS         ...

    /*
     * io_uring_register(2) opcodes and arguments
     */
    #define IORING_REGISTER_BUFFERS         ...
    #define IORING_UNREGISTER_BUFFERS       ...
    #define IORING_REGISTER_FILES           ...
    #define IORING_UNREGISTER_FILES         ...
    #define IORING_REGISTER_EVENTFD         ...
    #define IORING_UNREGISTER_EVENTFD       ...
    #define IORING_REGISTER_FILES_UPDATE    ...
    #define IORING_REGISTER_EVENTFD_ASYNC   ...
    #define IORING_REGISTER_PROBE           ...
    #define IORING_REGISTER_PERSONALITY     ...
    #define IORING_UNREGISTER_PERSONALITY   ...

    struct io_uring_files_update {
        __u32 offset;
        __u32 resv;
        __aligned_u64 /* __s32 * */ fds;
    };

    #define IO_URING_OP_SUPPORTED           ...

    struct io_uring_probe_op {
        __u8 op;
        __u8 resv;
        __u16 flags;    /* IO_URING_OP_* flags */
        __u32 resv2;
    };

    struct io_uring_probe {
        __u8 last_op;   /* last opcode supported */
        __u8 ops_len;   /* length of ops[] array below */
        __u16 resv;
        __u32 resv2[3];
        struct io_uring_probe_op ops[0];
    };
''')


# compat.h
# Note: auto created in `./configure`


# statx(2)
ffi.cdef('''
    /* man page @ http://man7.org/linux/man-pages/man2/statx.2.html */

    struct statx_timestamp {
        __s64 tv_sec;    /* Seconds since the Epoch (UNIX time) */
        __u32 tv_nsec;   /* Nanoseconds since tv_sec */
        ...;
    };

    struct statx {
        __u32 stx_mask;             /* Mask of bits indicating filled fields */
        __u32 stx_blksize;          /* Block size for filesystem I/O */
        __u64 stx_attributes;       /* Extra file attribute indicators */
        __u32 stx_nlink;            /* Number of hard links */
        __u32 stx_uid;              /* User ID of owner */
        __u32 stx_gid;              /* Group ID of owner */
        __u16 stx_mode;             /* File type and mode */
        __u64 stx_ino;              /* Inode number */
        __u64 stx_size;             /* Total size in bytes */
        __u64 stx_blocks;           /* Number of 512B blocks allocated */
        __u64 stx_attributes_mask;  /* Mask to show what's supported in stx_attributes */

        /* The following fields are file timestamps */
        struct statx_timestamp stx_atime;  /* Last access */
        struct statx_timestamp stx_btime;  /* Creation */
        struct statx_timestamp stx_ctime;  /* Last status change */
        struct statx_timestamp stx_mtime;  /* Last modification */

        /*
         * If this file represents a device, then the next two fields contain the ID of the device
         */
        __u32 stx_rdev_major;  /* Major ID */
        __u32 stx_rdev_minor;  /* Minor ID */

        /*
         * The next two fields contain the ID of the devicecontaining the filesystem
         * where the file resides
         */
        __u32 stx_dev_major;   /* Major ID */
        __u32 stx_dev_minor;   /* Minor ID */
        ...;
    };

    /* Flags */
    #define AT_EMPTY_PATH           ...
    #define AT_NO_AUTOMOUNT         ...
    #define AT_SYMLINK_NOFOLLOW     ...
    #define AT_STATX_SYNC_AS_STAT   ...
    #define AT_STATX_FORCE_SYNC     ...
    #define AT_STATX_DONT_SYNC      ...

    /* Mask */
    #define STATX_TYPE              ...     /* Want stx_mode & S_IFMT */
    #define STATX_MODE              ...     /* Want stx_mode & ~S_IFMT */
    #define STATX_NLINK             ...     /* Want stx_nlink */
    #define STATX_UID               ...     /* Want stx_uid */
    #define STATX_GID               ...     /* Want stx_gid */
    #define STATX_ATIME             ...     /* Want stx_atime */
    #define STATX_MTIME             ...     /* Want stx_mtime */
    #define STATX_CTIME             ...     /* Want stx_ctime */
    #define STATX_INO               ...     /* Want stx_ino */
    #define STATX_SIZE              ...     /* Want stx_size */
    #define STATX_BLOCKS            ...     /* Want stx_blocks */
    #define STATX_BASIC_STATS       ...     /* [All of the above] */
    #define STATX_BTIME             ...     /* Want stx_btime */
    #define STATX_ALL               ...     /* [All currently available fields] */

    /* `stx_attributes` flags */
    #define STATX_ATTR_COMPRESSED   ...
    #define STATX_ATTR_IMMUTABLE    ...
    #define STATX_ATTR_APPEND       ...
    #define STATX_ATTR_NODUMP       ...
    #define STATX_ATTR_ENCRYPTED    ...
    #define STATX_ATTR_VERITY       ...
''')
