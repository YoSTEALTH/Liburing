ctypedef bint bool


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
    ctypedef int size_t
    ctypedef int ssize_t
    ctypedef int int64_t
    ctypedef int loff_t

    ctypedef unsigned int uint8_t
    ctypedef unsigned int uint16_t
    ctypedef unsigned int uint32_t
    ctypedef unsigned int uint64_t
    ctypedef unsigned int atomic_uint

    ctypedef unsigned int uintptr_t

    # compat.h - this file is auto-created so its correct for these values to be here.
    # ========------------------------------------------------------------------------
    ctypedef int __kernel_rwf_t


cdef extern from '<linux/version.h>' nogil:
    ''' #define __LINUX_VERSION_CHECK(major, minor) (major > LINUX_VERSION_MAJOR) || \
                                                    ((major == LINUX_VERSION_MAJOR) && \
                                                     (minor > LINUX_VERSION_PATCHLEVEL))
    '''
    __u8 __LINUX_VERSION_MAJOR 'LINUX_VERSION_MAJOR'
    __u8 __LINUX_VERSION_MINOR 'LINUX_VERSION_PATCHLEVEL'
    bint __LINUX_VERSION_CHECK(__u8 major, __u8 minor)


cdef extern from '<sched.h>' nogil:
    ''' const int BITS = __CPU_SETSIZE / __NCPUBITS;
    '''
    const int BITS
    ctypedef unsigned long  __cpu_mask
    ctypedef struct cpu_set_t:
        __cpu_mask __bits[BITS]


cdef extern from '<signal.h>' nogil:
    ctypedef int id_t
    ctypedef int idtype_t

    ctypedef int pid_t
    ctypedef int uid_t
    ctypedef int si_value

    union sigval:
        si_value value

    ctypedef struct siginfo_t:
        int si_signo     # Signal number
        int si_code      # Signal code
        pid_t si_pid     # Sending process ID
        uid_t si_uid     # Real user ID of sending process
        void *si_addr    # Address of faulting instruction
        int si_status    # Exit value or signal
        sigval si_value  # Signal value


cdef extern from '<bits/types/sigset_t.h>' nogil:
    enum: _SIGSET_NWORDS
    ctypedef struct __sigset_t:
        unsigned long int __val[_SIGSET_NWORDS]
    ctypedef __sigset_t sigset_t


cdef extern from '<bits/types/struct_iovec.h>' nogil:
    struct __iovec 'iovec':
        void *iov_base
        size_t iov_len


cdef extern from '<linux/time_types.h>' nogil:
    ctypedef int64_t __kernel_time64_t
    struct __kernel_timespec:
        __kernel_time64_t tv_sec      # seconds
        long long tv_nsec     # nanoseconds


cdef extern from '<stdio.h>' nogil:
    enum:
        # flags for `renameat2`.
        __RENAME_NOREPLACE 'RENAME_NOREPLACE'
        __RENAME_EXCHANGE 'RENAME_EXCHANGE'
        __RENAME_WHITEOUT 'RENAME_WHITEOUT'


cdef extern from '<fcntl.h>' nogil:
    enum:
        # AT_* flags
        __AT_FDCWD 'AT_FDCWD'  # Use current working directory.
        __AT_SYMLINK_FOLLOW 'AT_SYMLINK_FOLLOW'  # Follow symbolic links.
        __AT_SYMLINK_NOFOLLOW 'AT_SYMLINK_NOFOLLOW'  # Do not follow symbolic links.
        __AT_REMOVEDIR 'AT_REMOVEDIR'  # Remove directory instead of unlinking file.
        __AT_NO_AUTOMOUNT 'AT_NO_AUTOMOUNT'  # Suppress terminal automount traversal.
        __AT_EMPTY_PATH 'AT_EMPTY_PATH'  # Allow empty relative pathname.
        __AT_RECURSIVE 'AT_RECURSIVE'  # Apply to the entire subtree.

        # splice flags
        __SPLICE_F_MOVE 'SPLICE_F_MOVE'
        __SPLICE_F_NONBLOCK 'SPLICE_F_NONBLOCK'
        __SPLICE_F_MORE 'SPLICE_F_MORE'
        __SPLICE_F_GIFT 'SPLICE_F_GIFT'

        # `fallocate` mode
        __FALLOC_FL_KEEP_SIZE 'FALLOC_FL_KEEP_SIZE'
        __FALLOC_FL_PUNCH_HOLE 'FALLOC_FL_PUNCH_HOLE'
        __FALLOC_FL_NO_HIDE_STALE 'FALLOC_FL_NO_HIDE_STALE'
        __FALLOC_FL_COLLAPSE_RANGE 'FALLOC_FL_COLLAPSE_RANGE'
        __FALLOC_FL_ZERO_RANGE 'FALLOC_FL_ZERO_RANGE'
        __FALLOC_FL_INSERT_RANGE 'FALLOC_FL_INSERT_RANGE'
        __FALLOC_FL_UNSHARE_RANGE 'FALLOC_FL_UNSHARE_RANGE'
