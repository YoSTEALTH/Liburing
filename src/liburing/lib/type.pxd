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


cdef extern from '<sched.h>' nogil:
    ''' // C Source Code
        // need bit of help from C to get this to work properly.
        const int BITS = __CPU_SETSIZE / __NCPUBITS;
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
    # renameat2 flags
    enum:
        __RENAME_NOREPLACE 'RENAME_NOREPLACE'
        __RENAME_EXCHANGE 'RENAME_EXCHANGE'
        __RENAME_WHITEOUT 'RENAME_WHITEOUT'


cdef extern from '<fcntl.h>' nogil:
    enum:
        # splice flags
        __SPLICE_F_MOVE 'SPLICE_F_MOVE'
        __SPLICE_F_NONBLOCK 'SPLICE_F_NONBLOCK'
        __SPLICE_F_MORE 'SPLICE_F_MORE'
        __SPLICE_F_GIFT 'SPLICE_F_GIFT'
