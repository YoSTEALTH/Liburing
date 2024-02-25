from .type cimport *


cdef extern from '<sys/socket.h>' nogil:
    ctypedef int socklen_t
    ctypedef int sa_family_t

    struct __sockaddr_storage 'sockaddr_storage':
        sa_family_t ss_family  # address family

    # generic socket address. 
    struct __sockaddr 'sockaddr':
        sa_family_t sa_family
        char        sa_data[14]  # protocol-specific address

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
    struct in_addr:
        in_addr_t s_addr  # Address in network byte order */

    struct __sockaddr_in 'sockaddr_in':
        sa_family_t sin_family  # address family: AF_INET
        in_port_t   sin_port    # port in network byte order
        in_addr     sin_addr    # internet address

    # IPv6 - Internet address
    # -----------------------
    struct in6_addr:
        unsigned char   s6_addr[16]  # IPv6 address

    struct __sockaddr_in6 'sockaddr_in6':
        sa_family_t sin6_family    # AF_INET6
        in_port_t   sin6_port      # port number
        uint32_t    sin6_flowinfo  # IPv6 flow information
        in6_addr    sin6_addr      # IPv6 address
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


cdef extern from '<sys/epoll.h>' nogil:
    ctypedef union epoll_data_t:
        void *   ptr
        int      fd
        uint32_t u32
        uint64_t u64

    struct __epoll_event 'epoll_event':
        uint32_t events    # Epoll events
        epoll_data_t data  # User data variable
