from .type cimport *


cdef extern from '<sys/socket.h>' nogil:
    # socket domain | address families.
    enum:
        __AF_UNIX 'AF_UNIX'
        __AF_INET 'AF_INET'
        __AF_INET6 'AF_INET6'
        # note: currently there is no plans to add other `AF_*` flags, unless user requests it.

    # types of sockets.
    enum:
        # sequenced, reliable, connection-based byte streams.
        __SOCK_STREAM 'SOCK_STREAM'
        # connectionless, unreliable datagrams of fixed maximum length.
        __SOCK_DGRAM 'SOCK_DGRAM'
        # raw protocol interface.
        __SOCK_RAW 'SOCK_RAW'
        # reliably-delivered messages.
        __SOCK_RDM 'SOCK_RDM'
        # sequenced, reliable, connection-based, datagrams of fixed maximum length.
        __SOCK_SEQPACKET 'SOCK_SEQPACKET'
        # datagram congestion control protocol.
        __SOCK_DCCP 'SOCK_DCCP'
        # linux specific way of getting packets at the dev level.
        # for writing rarp and other similar things on the user level.
        __SOCK_PACKET 'SOCK_PACKET'

        # flags combination with socket type using `|`
        # atomically set close-on-exec flag for the new descriptor(s).
        __SOCK_CLOEXEC 'SOCK_CLOEXEC'
        # atomically mark descriptor(s) as non-blocking.
        __SOCK_NONBLOCK 'SOCK_NONBLOCK'

    ctypedef int socklen_t
    ctypedef int sa_family_t

    struct __sockaddr_storage 'sockaddr_storage':
        sa_family_t ss_family  # address family

    # generic socket address. 
    struct __sockaddr 'sockaddr':
        sa_family_t sa_family
        char        sa_data[14]  # protocol-specific address

    int __setsockopt 'setsockopt'(int sockfd,
                                  int level,
                                  int optname,
                                  const void *optval,
                                  socklen_t optlen)
    int __getsockopt 'getsockopt'(int sockfd,
                                  int level,
                                  int optname,
                                  void *optval,
                                  socklen_t *optlen)
    int __getpeername 'getpeername'(int sockfd,
                                    __sockaddr *addr,
                                    socklen_t *addrlen)
    int __getsockname 'getsockname'(int sockfd,
                                    __sockaddr *addr,
                                    socklen_t *addrlen)


cdef extern from '<netinet/in.h>' nogil:
    enum:
        __INET_ADDRSTRLEN 'INET_ADDRSTRLEN'
        __INET6_ADDRSTRLEN 'INET6_ADDRSTRLEN'

cdef extern from '<sys/un.h>' nogil:
    # UNIX domain sockets - for local interprocess communication
    struct __sockaddr_un 'sockaddr_un':
        sa_family_t sun_family      # AF_UNIX, AF_LOCAL
        char        sun_path[108]   # Path name.


cdef extern from '<netinet/in.h>' nogil:
    ctypedef uint16_t in_port_t
    ctypedef uint32_t in_addr_t

    # IPv4 - Internet address
    # -----------------------
    struct __in_addr 'in_addr':
        in_addr_t s_addr  # Address in network byte order */

    struct __sockaddr_in 'sockaddr_in':
        sa_family_t sin_family  # address family: AF_INET
        in_port_t   sin_port    # port in network byte order
        __in_addr   sin_addr    # internet address

    # IPv6 - Internet address
    # -----------------------
    struct __in6_addr 'in6_addr':
        unsigned char s6_addr[16]  # IPv6 address

    struct __sockaddr_in6 'sockaddr_in6':
        sa_family_t sin6_family    # AF_INET6
        in_port_t   sin6_port      # port number
        uint32_t    sin6_flowinfo  # IPv6 flow information
        __in6_addr  sin6_addr      # IPv6 address
        uint32_t    sin6_scope_id  # Scope ID (new in 2.4)

    struct __msghdr 'msghdr':
        void       *msg_name        # Address to send to/receive from.
        socklen_t   msg_namelen     # Length of address data.
        __iovec    *msg_iov         # Vector of data to send/receive into.
        size_t      msg_iovlen      # Number of elements in the vector.
        void       *msg_control     # Ancillary data (eg BSD filedesc passing).
        size_t      msg_controllen  # Ancillary data buffer length.
        int         msg_flags       # Flags on received message.

    struct __cmsghdr 'cmsghdr':
        size_t cmsg_len    # Length of data in `cmsg_data` plus length of `cmsghdr` structure.
        int    cmsg_level  # Originating protocol.
        int    cmsg_type   # Protocol specific type.


cdef extern from '<arpa/inet.h>' nogil:
    # converts to network address
    int __inet_pton 'inet_pton'(int af,
                                const char *src,  # restrict
                                void *dst)        # restrict

    # converts network address to address family
    const char *__inet_ntop 'inet_ntop'(int af,
                                        const void *src,  # restrict
                                        char *dst,        # restrict
                                        socklen_t size)

    # converting host to network order.
    uint16_t __htons 'htons'(uint16_t hostshort)
    uint32_t __htonl 'htonl'(uint32_t hostlong)

    # converting network to host order,
    uint16_t __ntohs 'ntohs'(uint16_t netshort)
    uint32_t __ntohl 'ntohl'(uint32_t netlong)
