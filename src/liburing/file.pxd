from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from .type cimport __u64, int64_t, mode_t, iovec_t, iovec
from .error cimport trap_error, memory_error
from .io_uring cimport io_uring_sqe_t, io_uring_sqe
from .liburing cimport io_uring_t, io_uring


cdef extern from '<linux/openat2.h>' nogil:
    # Definition of RESOLVE_* constants
    struct open_how_t 'open_how':
        __u64   flags
        __u64   mode
        __u64   resolve

    cpdef enum:
        # `open_how` resolve
        RESOLVE_NO_XDEV
        RESOLVE_NO_MAGICLINKS
        RESOLVE_NO_SYMLINKS
        RESOLVE_BENEATH
        RESOLVE_IN_ROOT
        RESOLVE_CACHED

        # splice flags
        SPLICE_F_MOVE
        SPLICE_F_NONBLOCK
        SPLICE_F_MORE
        SPLICE_F_GIFT

        # renameat2 flags
        RENAME_NOREPLACE
        RENAME_EXCHANGE
        RENAME_WHITEOUT

cdef class open_how:
    cdef open_how_t *ptr


cdef extern from "<fcntl.h>" nogil:
    cpdef enum:
        O_ACCMODE
        O_RDONLY
        O_WRONLY
        O_RDWR
        O_CREAT
        O_EXCL
        O_NOCTTY
        O_TRUNC
        O_APPEND
        O_NONBLOCK
        O_DSYNC
        FASYNC
        O_DIRECT
        O_LARGEFILE
        O_DIRECTORY
        O_NOFOLLOW
        O_NOATIME
        O_CLOEXEC

        O_SYNC
        O_PATH
        O_TMPFILE
        O_NDELAY

        # AT_* flags
        AT_FDCWD            # Use the current working directory.
        AT_REMOVEDIR        # Remove directory instead of unlinking file.
        AT_SYMLINK_FOLLOW   # Follow symbolic links.
        AT_EACCESS          # Test access permitted for effective IDs, not real IDs.


cdef extern from *nogil:
    int io_uring_register_files_c 'io_uring_register_files'(io_uring_t *ring,
                                                            const int *files,
                                                            unsigned int nr_files)
    int io_uring_register_files_tags_c 'io_uring_register_files_tags'(io_uring_t *ring,
                                                                      const int *files,
                                                                      const __u64 *tags,
                                                                      unsigned int nr)
    int io_uring_register_files_sparse_c 'io_uring_register_files_sparse'(io_uring_t *ring,
                                                                          unsigned int nr)
    int io_uring_register_files_update_tag_c 'io_uring_register_files_update_tag'(io_uring_t *ring,
                                                                                  unsigned int off,
                                                                                  const int *files,
                                                                                  const __u64 *tags,
                                                                                  unsigned int nr_files)
    int io_uring_unregister_files_c 'io_uring_unregister_files'(io_uring_t *ring)
    int io_uring_register_files_update_c 'io_uring_register_files_update'(io_uring_t *ring,
                                                                          unsigned int off,
                                                                          const int *files,
                                                                          unsigned int nr_files)
    void io_uring_prep_splice_c 'io_uring_prep_splice'(io_uring_sqe_t *sqe,
                                                       int fd_in,
                                                       int64_t off_in,
                                                       int fd_out,
                                                       int64_t off_out,
                                                       unsigned int nbytes,
                                                       unsigned int splice_flags)
    void io_uring_prep_tee_c 'io_uring_prep_tee'(io_uring_sqe_t *sqe,
                                                 int fd_in,
                                                 int fd_out,
                                                 unsigned int nbytes,
                                                 unsigned int splice_flags)
    void io_uring_prep_readv_c 'io_uring_prep_readv'(io_uring_sqe_t *sqe,
                                                     int fd,
                                                     const iovec_t *iovecs,
                                                     unsigned int nr_vecs,
                                                     __u64 offset)
    void io_uring_prep_readv2_c 'io_uring_prep_readv2'(io_uring_sqe_t *sqe,
                                                       int fd,
                                                       const iovec_t *iovecs,
                                                       unsigned int nr_vecs,
                                                       __u64 offset,
                                                       int flags)
    void io_uring_prep_read_fixed_c 'io_uring_prep_read_fixed'(io_uring_sqe_t *sqe,
                                                               int fd,
                                                               void *buf,
                                                               unsigned int nbytes,
                                                               __u64 offset,
                                                               int buf_index)
    void io_uring_prep_writev_c 'io_uring_prep_writev'(io_uring_sqe_t *sqe,
                                                       int fd,
                                                       const iovec_t *iovecs,
                                                       unsigned int nr_vecs,
                                                       __u64 offset)
    void io_uring_prep_writev2_c 'io_uring_prep_writev2'(io_uring_sqe_t *sqe,
                                                         int fd,
                                                         const iovec_t *iovecs,
                                                         unsigned nr_vecs, __u64 offset,
                                                         int flags)
    void io_uring_prep_write_fixed_c 'io_uring_prep_write_fixed'(io_uring_sqe_t *sqe,
                                                                 int fd,
                                                                 const char *buf,
                                                                 unsigned int nbytes,
                                                                 __u64 offset,
                                                                 int buf_index)

    void io_uring_prep_fsync_c 'io_uring_prep_fsync'(io_uring_sqe_t *sqe, int fd, unsigned int fsync_flags)

    void io_uring_prep_openat_c 'io_uring_prep_openat'(io_uring_sqe_t *sqe,
                                                       int dfd,
                                                       const char *path,
                                                       int flags,
                                                       mode_t mode)
    void io_uring_prep_openat2_c 'io_uring_prep_openat2'(io_uring_sqe_t *sqe,
                                                         int dfd,
                                                         const char *path,
                                                         open_how_t *how)
    void io_uring_prep_openat_direct_c 'io_uring_prep_openat_direct'(io_uring_sqe_t *sqe,
                                                                     int dfd,
                                                                     const char *path,
                                                                     int flags,
                                                                     mode_t mode,
                                                                     unsigned int file_index)
    void io_uring_prep_openat2_direct_c 'io_uring_prep_openat2_direct'(io_uring_sqe_t *sqe,
                                                                       int dfd,
                                                                       const char *path,
                                                                       open_how_t *how,
                                                                       unsigned int file_index)

    void io_uring_prep_close_c 'io_uring_prep_close'(io_uring_sqe_t *sqe,
                                                     int fd)
    void io_uring_prep_close_direct_c 'io_uring_prep_close_direct'(io_uring_sqe_t *sqe,
                                                                   unsigned int file_index)
    void io_uring_prep_read_c 'io_uring_prep_read'(io_uring_sqe_t *sqe,
                                                   int fd,
                                                   void *buf,
                                                   unsigned int nbytes,
                                                   __u64 offset)
    void io_uring_prep_read_multishot_c 'io_uring_prep_read_multishot'(io_uring_sqe_t *sqe,
                                                                       int fd,
                                                                       unsigned int nbytes,
                                                                       __u64 offset,
                                                                       int buf_group)
    void io_uring_prep_write_c 'io_uring_prep_write'(io_uring_sqe_t *sqe,
                                                     int fd,
                                                     const void *buf,
                                                     unsigned int nbytes,
                                                     __u64 offset)


cpdef int io_uring_register_files(io_uring ring,
                                  int files,
                                  unsigned int nr_files) nogil
cpdef int io_uring_register_files_tags(io_uring ring,
                                       int files,
                                       __u64 tags,
                                       unsigned int nr) nogil
cpdef int io_uring_register_files_sparse(io_uring ring,
                                         unsigned int nr) nogil
cpdef int io_uring_register_files_update_tag(io_uring ring,
                                             unsigned int off,
                                             int files,
                                             __u64 tags,
                                             unsigned int nr_files) nogil
cpdef int io_uring_unregister_files(io_uring ring) nogil
cpdef int io_uring_register_files_update(io_uring ring,
                                         unsigned int off,
                                         int files,
                                         unsigned int nr_files) nogil
cpdef void io_uring_prep_splice(io_uring_sqe sqe,
                                       int fd_in,
                                       int64_t off_in,
                                       int fd_out,
                                       int64_t off_out,
                                       unsigned int nbytes,
                                       unsigned int splice_flags) noexcept nogil
cpdef void io_uring_prep_tee(io_uring_sqe sqe,
                             int fd_in,
                             int fd_out,
                             unsigned int nbytes,
                             unsigned int splice_flags) noexcept nogil
cpdef void io_uring_prep_readv(io_uring_sqe sqe,
                               int fd,
                               iovec iovecs,
                               unsigned int nr_vecs,
                               __u64 offset) noexcept nogil
cpdef void io_uring_prep_readv2(io_uring_sqe sqe,
                                int fd,
                                iovec iovecs,
                                unsigned int nr_vecs,
                                __u64 offset,
                                int flags) noexcept nogil
cpdef void io_uring_prep_read_fixed(io_uring_sqe sqe,
                                    int fd,
                                    char *buf,
                                    unsigned int nbytes,
                                    __u64 offset,
                                    int buf_index) noexcept nogil
cpdef void io_uring_prep_writev(io_uring_sqe sqe,
                                int fd,
                                iovec iovecs,
                                unsigned int nr_vecs,
                                __u64 offset) noexcept nogil
cpdef void io_uring_prep_writev2(io_uring_sqe sqe,
                                 int fd,
                                 iovec iovecs,
                                 unsigned int nr_vecs,
                                 __u64 offset,
                                 int flags) noexcept nogil
cpdef void io_uring_prep_write_fixed(io_uring_sqe sqe,
                                     int fd,
                                     char *buf,
                                     unsigned int nbytes,
                                     __u64 offset,
                                     int buf_index) noexcept nogil
cpdef void io_uring_prep_fsync(io_uring_sqe sqe, int fd, unsigned int fsync_flags) noexcept nogil
cpdef void io_uring_prep_openat(io_uring_sqe sqe,
                                int dfd,
                                const char *path,
                                int flags,
                                mode_t mode) noexcept nogil
cpdef void io_uring_prep_openat2(io_uring_sqe sqe,
                                 int dfd,
                                 const char *path,
                                 open_how how) noexcept nogil
cpdef void io_uring_prep_openat_direct(io_uring_sqe sqe,
                                       int dfd,
                                       const char *path,
                                       int flags,
                                       mode_t mode,
                                       unsigned int file_index) noexcept nogil
cpdef void io_uring_prep_openat2_direct(io_uring_sqe sqe,
                                        int dfd,
                                        const char *path,
                                        open_how how,
                                        unsigned int file_index) noexcept nogil
cpdef void io_uring_prep_close(io_uring_sqe sqe, int fd) noexcept nogil
cpdef void io_uring_prep_close_direct(io_uring_sqe sqe, unsigned int file_index) noexcept nogil
cpdef void io_uring_prep_read(io_uring_sqe sqe,
                              int fd,
                              unsigned char[:] buf,  # `void *buf`
                              unsigned int nbytes,
                              __u64 offset) noexcept nogil
cpdef void io_uring_prep_read_multishot(io_uring_sqe sqe,
                                        int fd,
                                        unsigned int nbytes,
                                        __u64 offset,
                                        int buf_group) noexcept nogil
cpdef void io_uring_prep_write(io_uring_sqe sqe,
                               int fd,
                               const unsigned char[:] buf,  # `const void * buf`
                               unsigned int nbytes,
                               __u64 offset) noexcept nogil
