from posix.unistd cimport _SC_IOV_MAX


cpdef enum:
    SC_IOV_MAX = _SC_IOV_MAX


cdef extern from * nogil:
    ctypedef bint   bool


cdef extern from '<linux/types.h>' nogil:
    # NOTE: Does not matter that `ctypedef int` is given to all,
    #       compiler will assign it correct type(I think!).

    # Custom Types
    ctypedef int __s8
    ctypedef int __s16
    ctypedef int __s32
    ctypedef int __s64

    ctypedef unsigned int __u8
    ctypedef unsigned int __u16
    ctypedef unsigned int __u32
    ctypedef unsigned int __u64
    ctypedef unsigned int __aligned_u64

    ctypedef int off_t
    ctypedef int mode_t
    ctypedef int ssize_t
    ctypedef int int64_t

    ctypedef unsigned int uint8_t
    ctypedef unsigned int uint16_t
    ctypedef unsigned int uint32_t
    ctypedef unsigned int uint64_t
    ctypedef unsigned int atomic_uint

    ctypedef unsigned int uintptr_t

    struct iovec_t 'iovec':
        void *  iov_base
        size_t  iov_len

    ctypedef fused string_t:
        bytes
        str

    # compat.h - this file is auto-created so its correct for these values to be here.
    # ========------------------------------------------------------------------------
    ctypedef int __kernel_rwf_t

    cpdef enum:
        # splice flags
        SPLICE_F_MOVE
        SPLICE_F_NONBLOCK
        SPLICE_F_MORE
        SPLICE_F_GIFT

        # renameat2 flags
        RENAME_NOREPLACE
        RENAME_EXCHANGE
        RENAME_WHITEOUT


cdef extern from '<fcntl.h>' nogil:
    cpdef enum:
        AT_FDCWD            # Use the current working directory.
        AT_REMOVEDIR        # Remove directory instead of unlinking file.
        AT_SYMLINK_FOLLOW   # Follow symbolic links.
        AT_EACCESS          # Test access permitted for effective IDs, not real IDs.


cdef extern from '<linux/time_types.h>' nogil:
    ctypedef int64_t __kernel_time64_t
    struct __kernel_timespec:
        __kernel_time64_t   tv_sec      # seconds
        long long           tv_nsec     # nanoseconds

cdef class timespec:
    cdef __kernel_timespec * ptr


cdef extern from '<sched.h>' nogil:
    ''' // C Source Code
        // need bit of help from C to get this to work properly.
        const int BITS = __CPU_SETSIZE / __NCPUBITS;
    '''
    enum:
        BITS
    ctypedef unsigned long  __cpu_mask
    ctypedef struct cpu_set_t:
        __cpu_mask    __bits[BITS]


cdef extern from '<bits/types/sigset_t.h>' nogil:
    enum: _SIGSET_NWORDS
    ctypedef struct __sigset_t:
        unsigned long int __val[_SIGSET_NWORDS]
    ctypedef __sigset_t sigset_t


cdef class iovec:
    cdef iovec_t *      ptr
    cdef unsigned int   len


