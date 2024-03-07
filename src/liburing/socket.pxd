from .lib.uring cimport *
from .queue cimport io_uring_sqe


cdef class io_uring_recvmsg_out:
    cdef __io_uring_recvmsg_out * ptr

cdef class sockaddr_storage:
    cdef __sockaddr_storage *ptr

cdef class sockaddr:
    cdef __sockaddr *ptr

cdef class sockaddr_un:
    cdef __sockaddr_un *ptr

cdef class sockaddr_in:
    cdef __sockaddr_in *ptr

cdef class sockaddr_in6:
    cdef __sockaddr_in6 *ptr

cdef class msghdr:
    cdef __msghdr *ptr

cdef class cmsghdr:
    cdef __cmsghdr *ptr


cpdef void io_uring_prep_recvmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg=?,
                                 unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_recvmsg_multishot(io_uring_sqe sqe,
                                           int fd, 
                                           msghdr msg=?,
                                           unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_sendmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg=?,
                                 unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_accept(io_uring_sqe sqe,
                                int fd,
                                sockaddr addr=?,
                                int flags=?) noexcept nogil
cpdef void io_uring_prep_accept_direct(io_uring_sqe sqe,
                                       int fd,
                                       sockaddr addr=?,
                                       int flags=?,
                                       unsigned int file_index=?) noexcept nogil
cpdef void io_uring_prep_multishot_accept(io_uring_sqe sqe,
                                          int fd,
                                          sockaddr addr=?,
                                          int flags=?) noexcept nogil
cpdef void io_uring_prep_multishot_accept_direct(io_uring_sqe sqe,
                                                 int fd,
                                                 sockaddr addr=?,
                                                 int flags=?) noexcept nogil
cpdef void io_uring_prep_connect(io_uring_sqe sqe,
                                 int fd,
                                 sockaddr addr) noexcept nogil
cpdef void io_uring_prep_send(io_uring_sqe sqe,
                              int sockfd,
                              const unsigned char[:] buf,
                              size_t len,
                              int flags=?) noexcept nogil
cpdef void io_uring_prep_send_set_addr(io_uring_sqe sqe,
                                       sockaddr dest_addr) noexcept nogil
cpdef void io_uring_prep_sendto(io_uring_sqe sqe,
                                int sockfd,
                                const unsigned char[:] buf,
                                size_t len,
                                sockaddr addr,
                                int flags=?) noexcept nogil
cpdef void  io_uring_prep_send_zc(io_uring_sqe sqe,
                                  int sockfd,
                                  const unsigned char[:] buf,
                                  size_t len,
                                  int flags=?,
                                  unsigned int zc_flags=?) noexcept nogil
cpdef void io_uring_prep_send_zc_fixed(io_uring_sqe sqe,
                                       int sockfd,
                                       const unsigned char[:] buf,
                                       size_t len,
                                       unsigned int buf_index,
                                       int flags=?,
                                       unsigned int zc_flags=?) noexcept nogil
cpdef void io_uring_prep_sendmsg_zc(io_uring_sqe sqe,
                                    int fd,
                                    msghdr msg,
                                    unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_recv(io_uring_sqe sqe,
                              int sockfd,
                              unsigned char[:] buf,
                              size_t len,
                              int flags=?) noexcept nogil
cpdef void io_uring_prep_recv_multishot(io_uring_sqe sqe,
                                        int sockfd,
                                        unsigned char[:] buf,
                                        size_t len,
                                        int flags=?) noexcept nogil
cpdef io_uring_recvmsg_out io_uring_recvmsg_validate(unsigned char[:] buf,
                                                     int buf_len,
                                                     msghdr msgh)
# TODO:
# cpdef void * io_uring_recvmsg_name(io_uring_recvmsg_out o) noexcept nogil
cpdef cmsghdr io_uring_recvmsg_cmsg_firsthdr(io_uring_recvmsg_out o, msghdr msgh)
cpdef cmsghdr io_uring_recvmsg_cmsg_nexthdr(io_uring_recvmsg_out o,
                                            msghdr msgh,
                                            cmsghdr cmsg)
# TODO:
# cpdef void * io_uring_recvmsg_payload(io_uring_recvmsg_out o, msghdr msgh) noexcept nogil
cpdef unsigned int io_uring_recvmsg_payload_length(io_uring_recvmsg_out o,
                                                   int buf_len,
                                                   msghdr msgh) noexcept nogil
cpdef void io_uring_prep_shutdown(io_uring_sqe sqe, int fd, int how) noexcept nogil
cpdef void io_uring_prep_socket(io_uring_sqe sqe,
                                int domain,
                                int type,
                                int protocol,
                                unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct(io_uring_sqe sqe,
                                       int domain,
                                       int type,
                                       int protocol,
                                       unsigned int file_index=?,
                                       unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct_alloc(io_uring_sqe sqe,
                                             int domain,
                                             int type,
                                             int protocol,
                                             unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_cmd_sock(io_uring_sqe sqe,
                                  int cmd_op,
                                  int fd,
                                  int level,
                                  int optname,
                                  unsigned char[:] optval,
                                  int optlen) noexcept nogil


cpdef enum:  # TODO: need to name this.
    AF_UNIX = __AF_UNIX
    AF_INET = __AF_INET
    AF_INET6 = __AF_INET6

    SOCK_STREAM = __SOCK_STREAM
    SOCK_DGRAM = __SOCK_DGRAM
    SOCK_RAW = __SOCK_RAW
    SOCK_RDM = __SOCK_RDM
    SOCK_SEQPACKET = __SOCK_SEQPACKET
    SOCK_DCCP = __SOCK_DCCP
    SOCK_PACKET = __SOCK_PACKET
    SOCK_CLOEXEC = __SOCK_CLOEXEC
    SOCK_NONBLOCK = __SOCK_NONBLOCK

# used by `io_uring_prep_cmd_sock(cmd_op)`
cpdef enum io_uring_socket_op:
    SOCKET_URING_OP_SIOCINQ = __SOCKET_URING_OP_SIOCINQ
    SOCKET_URING_OP_SIOCOUTQ = __SOCKET_URING_OP_SIOCOUTQ
    SOCKET_URING_OP_GETSOCKOPT = __SOCKET_URING_OP_GETSOCKOPT
    SOCKET_URING_OP_SETSOCKOPT = __SOCKET_URING_OP_SETSOCKOPT
