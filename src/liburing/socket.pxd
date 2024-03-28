from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from cpython.array cimport array
from .lib.uring cimport *
from .error cimport trap_error, memory_error, index_error
from .queue cimport io_uring_sqe


cdef class sockaddr:
    cdef:
        bint free
        void* ptr
        socklen_t sizeof
        readonly sa_family_t family


cdef __sockaddr_un* sockaddr_un(char* path) noexcept nogil
cdef __sockaddr_in* sockaddr_in(char* addr, in_port_t port) noexcept nogil
cdef __sockaddr_in6* sockaddr_in6(char *addr, in_port_t port, uint32_t scope_id) noexcept nogil


cdef class msghdr:
    cdef __msghdr* ptr

cdef class cmsghdr:
    cdef __cmsghdr* ptr


cdef class io_uring_recvmsg_out:
    cdef __io_uring_recvmsg_out* ptr


cpdef void io_uring_prep_socket(io_uring_sqe sqe,
                                int domain,
                                int type,
                                int protocol=?,
                                unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct(io_uring_sqe sqe,
                                       int domain,
                                       int type,
                                       int protocol=?,
                                       unsigned int file_index=?,
                                       unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct_alloc(io_uring_sqe sqe,
                                             int domain,
                                             int type,
                                             int protocol=?,
                                             unsigned int flags=?) noexcept nogil

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
                                 sockaddr addr) noexcept
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
# cpdef void* io_uring_recvmsg_name(io_uring_recvmsg_out o) noexcept nogil
cpdef cmsghdr io_uring_recvmsg_cmsg_firsthdr(io_uring_recvmsg_out o, msghdr msgh)
cpdef cmsghdr io_uring_recvmsg_cmsg_nexthdr(io_uring_recvmsg_out o,
                                            msghdr msgh,
                                            cmsghdr cmsg)
# TODO:
# cpdef void* io_uring_recvmsg_payload(io_uring_recvmsg_out o, msghdr msgh) noexcept nogil
cpdef unsigned int io_uring_recvmsg_payload_length(io_uring_recvmsg_out o,
                                                   int buf_len,
                                                   msghdr msgh) noexcept nogil
cpdef void io_uring_prep_shutdown(io_uring_sqe sqe, int fd, int how) noexcept nogil


cpdef void io_uring_prep_cmd_sock(io_uring_sqe sqe,
                                  int cmd_op,
                                  int sockfd,
                                  int level,
                                  int optname,
                                  array optval)

cpdef void io_uring_prep_setsockopt(io_uring_sqe sqe,
                                    int sockfd,
                                    int level,
                                    int optname,
                                    array optval)
cpdef void io_uring_prep_getsockopt(io_uring_sqe sqe,
                                    int sockfd,
                                    int level,
                                    int optname,
                                    array optval)


# defines
cpdef enum SocketFamily:
    AF_UNIX = __AF_UNIX
    AF_INET = __AF_INET
    AF_INET6 = __AF_INET6

cpdef enum SocketType:
    SOCK_STREAM = __SOCK_STREAM
    SOCK_DGRAM = __SOCK_DGRAM
    SOCK_RAW = __SOCK_RAW
    SOCK_RDM = __SOCK_RDM
    SOCK_SEQPACKET = __SOCK_SEQPACKET
    SOCK_DCCP = __SOCK_DCCP
    SOCK_PACKET = __SOCK_PACKET
    SOCK_CLOEXEC = __SOCK_CLOEXEC
    SOCK_NONBLOCK = __SOCK_NONBLOCK

cpdef enum ShutdownHow:
    SHUT_RD = __SHUT_RD
    SHUT_WR = __SHUT_WR
    SHUT_RDWR = __SHUT_RDWR

cpdef enum io_uring_socket_op:
    SOCKET_URING_OP_SIOCINQ = __SOCKET_URING_OP_SIOCINQ
    SOCKET_URING_OP_SIOCOUTQ = __SOCKET_URING_OP_SIOCOUTQ
    SOCKET_URING_OP_GETSOCKOPT = __SOCKET_URING_OP_GETSOCKOPT
    SOCKET_URING_OP_SETSOCKOPT = __SOCKET_URING_OP_SETSOCKOPT

cpdef enum SocketProto:
    IPPROTO_IP = __IPPROTO_IP
    IPPROTO_ICMP = __IPPROTO_ICMP
    IPPROTO_IGMP = __IPPROTO_IGMP
    IPPROTO_IPIP = __IPPROTO_IPIP
    IPPROTO_TCP = __IPPROTO_TCP
    IPPROTO_EGP = __IPPROTO_EGP
    IPPROTO_PUP = __IPPROTO_PUP
    IPPROTO_UDP = __IPPROTO_UDP
    IPPROTO_IDP = __IPPROTO_IDP
    IPPROTO_TP = __IPPROTO_TP
    IPPROTO_DCCP = __IPPROTO_DCCP
    IPPROTO_IPV6 = __IPPROTO_IPV6
    IPPROTO_RSVP = __IPPROTO_RSVP
    IPPROTO_GRE = __IPPROTO_GRE
    IPPROTO_ESP = __IPPROTO_ESP
    IPPROTO_AH = __IPPROTO_AH
    IPPROTO_MTP = __IPPROTO_MTP
    IPPROTO_BEETPH = __IPPROTO_BEETPH
    IPPROTO_ENCAP = __IPPROTO_ENCAP
    IPPROTO_PIM = __IPPROTO_PIM
    IPPROTO_COMP = __IPPROTO_COMP
    # note: not supported
    # IPPROTO_L2TP = __IPPROTO_L2TP
    IPPROTO_SCTP = __IPPROTO_SCTP
    IPPROTO_UDPLITE = __IPPROTO_UDPLITE
    IPPROTO_MPLS = __IPPROTO_MPLS
    IPPROTO_ETHERNET = __IPPROTO_ETHERNET
    IPPROTO_RAW = __IPPROTO_RAW
    IPPROTO_MPTCP = __IPPROTO_MPTCP

# setsockopt & getsockopt start >>>
cpdef enum __socket_define__:
    SOL_SOCKET = __SOL_SOCKET
    SO_DEBUG = __SO_DEBUG
    SO_REUSEADDR = __SO_REUSEADDR
    SO_TYPE = __SO_TYPE
    SO_ERROR = __SO_ERROR
    SO_DONTROUTE = __SO_DONTROUTE
    SO_BROADCAST = __SO_BROADCAST
    SO_SNDBUF = __SO_SNDBUF
    SO_RCVBUF = __SO_RCVBUF
    SO_SNDBUFFORCE = __SO_SNDBUFFORCE
    SO_RCVBUFFORCE = __SO_RCVBUFFORCE
    SO_KEEPALIVE = __SO_KEEPALIVE
    SO_OOBINLINE = __SO_OOBINLINE
    SO_NO_CHECK = __SO_NO_CHECK
    SO_PRIORITY = __SO_PRIORITY
    SO_LINGER = __SO_LINGER
    SO_BSDCOMPAT = __SO_BSDCOMPAT
    SO_REUSEPORT = __SO_REUSEPORT
    SO_PASSCRED = __SO_PASSCRED
    SO_PEERCRED = __SO_PEERCRED
    SO_RCVLOWAT = __SO_RCVLOWAT
    SO_SNDLOWAT = __SO_SNDLOWAT
    SO_BINDTODEVICE = __SO_BINDTODEVICE

    # Socket filtering
    SO_ATTACH_FILTER = __SO_ATTACH_FILTER
    SO_DETACH_FILTER = __SO_DETACH_FILTER
    SO_GET_FILTER = __SO_GET_FILTER
    SO_PEERNAME = __SO_PEERNAME
    SO_ACCEPTCONN = __SO_ACCEPTCONN
    SO_PEERSEC = __SO_PEERSEC
    SO_PASSSEC = __SO_PASSSEC
    SO_MARK = __SO_MARK
    SO_PROTOCOL = __SO_PROTOCOL
    SO_DOMAIN = __SO_DOMAIN
    SO_RXQ_OVFL = __SO_RXQ_OVFL
    SO_WIFI_STATUS = __SO_WIFI_STATUS
    SCM_WIFI_STATUS = __SCM_WIFI_STATUS
    SO_PEEK_OFF = __SO_PEEK_OFF

    # not tested
    SO_TIMESTAMP = __SO_TIMESTAMP
    SO_TIMESTAMPNS = __SO_TIMESTAMPNS
    SO_TIMESTAMPING = __SO_TIMESTAMPING
    SO_RCVTIMEO = __SO_RCVTIMEO
    SO_SNDTIMEO = __SO_SNDTIMEO
    # setsockopt & getsockopt end <<<
