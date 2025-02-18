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

    int __getpeername 'getpeername'(int sockfd,
                                    __sockaddr* addr,
                                    socklen_t* addrlen)
    int __getsockname 'getsockname'(int sockfd,
                                    __sockaddr* addr,
                                    socklen_t* addrlen)


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
        in_addr_t s_addr  # Address in network byte order

    struct __sockaddr_in 'sockaddr_in':
        sa_family_t sin_family  # address family: AF_INET
        in_port_t   sin_port    # port in network byte order
        __in_addr   sin_addr    # internet address

    # IPv6 - Internet address
    # -----------------------
    struct __in6_addr 'in6_addr':
        uint8_t s6_addr[16]  # IPv6 address

    struct __sockaddr_in6 'sockaddr_in6':
        sa_family_t sin6_family    # AF_INET6
        in_port_t   sin6_port      # port number
        uint32_t    sin6_flowinfo  # IPv6 flow information
        __in6_addr  sin6_addr      # IPv6 address
        uint32_t    sin6_scope_id  # Scope ID (new in 2.4)

    struct __msghdr 'msghdr':
        void*     msg_name        # Address to send to/receive from.
        socklen_t msg_namelen     # Length of address data.
        __iovec*  msg_iov         # Vector of data to send/receive into.
        size_t    msg_iovlen      # Number of elements in the vector.
        void*     msg_control     # Ancillary data (eg BSD filedesc passing).
        size_t    msg_controllen  # Ancillary data buffer length.
        int       msg_flags       # Flags on received message.

    struct __cmsghdr 'cmsghdr':
        size_t cmsg_len    # Length of data in `cmsg_data` plus length of `cmsghdr` structure.
        int    cmsg_level  # Originating protocol.
        int    cmsg_type   # Protocol specific type.


cdef extern from '<netdb.h>' nogil:
    struct __addrinfo 'addrinfo':
        int         ai_flags      # AI_* Input flags.
        int         ai_family     # AF_* Protocol family for socket.
        int         ai_socktype   # SOCK_* Socket type.
        int         ai_protocol   # IPPROTO_* Protocol for socket.
        socklen_t   ai_addrlen    # Length of `ai_addr` socket address.
        char*       ai_canonname  # Canonical name for service location.
        __sockaddr* ai_addr       # Socket address for socket.
        __addrinfo* ai_next       # Pointer to next in list.

    int __getaddrinfo 'getaddrinfo'(const char* name,
                                    const char* service,
                                    const __addrinfo* req,
                                    __addrinfo** pai)
    # Translate a socket address to a location and service name.
    int __getnameinfo 'getnameinfo'(const __sockaddr* sa,
                                    socklen_t salen,
                                    char* host,
                                    socklen_t hostlen,
                                    char* serv,
                                    socklen_t servlen,
                                    int flags)
    void __freeaddrinfo 'freeaddrinfo'(__addrinfo* ai)  # free `addrinfo'
    const char* __gai_strerror 'gai_strerror'(int ecode)

    enum:
        # Possible values for `ai_flags' field in `addrinfo' structure.
        __AI_PASSIVE 'AI_PASSIVE'           # Socket address is intended for `bind'.
        __AI_CANONNAME 'AI_CANONNAME'       # Request for canonical name.
        __AI_NUMERICHOST 'AI_NUMERICHOST'   # Don't use name resolution.
        __AI_V4MAPPED 'AI_V4MAPPED'         # IPv4 mapped addresses are acceptable.
        __AI_ALL 'AI_ALL'                   # Return IPv4 mapped and IPv6 addresses.
        __AI_ADDRCONFIG 'AI_ADDRCONFIG'     # Use config of host to choose returned address type.
        __AI_IDN 'AI_IDN'                   # IDN encode input before looking it up.
        __AI_CANONIDN 'AI_CANONIDN'         # Translate canonical name from IDN format.
        __AI_NUMERICSERV 'AI_NUMERICSERV'   # Don't use name resolution.

    enum:
        # internal use only.
        __NI_MAXHOST 'NI_MAXHOST'  # 1025
        __NI_MAXSERV 'NI_MAXSERV'  # 32

        # getnameinfo flags
        __NI_NUMERICHOST 'NI_NUMERICHOST'   # Don't try to look up hostname.
        __NI_NUMERICSERV 'NI_NUMERICSERV'   # Don't convert port number to name.
        __NI_NOFQDN 'NI_NOFQDN'             # Only return nodename portion.
        __NI_NAMEREQD 'NI_NAMEREQD'         # Don't return numeric addresses.
        __NI_DGRAM 'NI_DGRAM'               # Look up UDP service rather than TCP.
        __NI_IDN 'NI_IDN'                   # Convert name from IDN format.


cdef extern from '<arpa/inet.h>' nogil:
    # converts to network address
    int __inet_pton 'inet_pton'(int af, const char* src, void* dst)

    # converts network address to address family
    const char* __inet_ntop 'inet_ntop'(int af, const void* src, char* dst, socklen_t size)

    # converting host to network order.
    uint16_t __htons 'htons'(uint16_t hostshort)
    uint32_t __htonl 'htonl'(uint32_t hostlong)

    # converting network to host order,
    uint16_t __ntohs 'ntohs'(uint16_t netshort)
    uint32_t __ntohl 'ntohl'(uint32_t netlong)


cdef extern from * nogil:  # <sys/socket.h>
    # socket domain | address families.
    enum:
        __AF_UNIX 'AF_UNIX'
        __AF_INET 'AF_INET'
        __AF_INET6 'AF_INET6'
        # note: currently there is no plans to add other `AF_*` flags, unless user requests it.

        # types of sockets.
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

        # shutdown "how" flags
        __SHUT_RD 'SHUT_RD'
        __SHUT_WR 'SHUT_WR'
        __SHUT_RDWR 'SHUT_RDWR'

        # socket
        __SOL_SOCKET 'SOL_SOCKET'

        __SO_DEBUG 'SO_DEBUG'
        __SO_REUSEADDR 'SO_REUSEADDR'
        __SO_TYPE 'SO_TYPE'
        __SO_ERROR 'SO_ERROR'
        __SO_DONTROUTE 'SO_DONTROUTE'
        __SO_BROADCAST 'SO_BROADCAST'
        __SO_SNDBUF 'SO_SNDBUF'
        __SO_RCVBUF 'SO_RCVBUF'
        __SO_SNDBUFFORCE 'SO_SNDBUFFORCE'
        __SO_RCVBUFFORCE 'SO_RCVBUFFORCE'
        __SO_KEEPALIVE 'SO_KEEPALIVE'
        __SO_OOBINLINE 'SO_OOBINLINE'
        __SO_NO_CHECK 'SO_NO_CHECK'
        __SO_PRIORITY 'SO_PRIORITY'
        __SO_LINGER 'SO_LINGER'
        __SO_BSDCOMPAT 'SO_BSDCOMPAT'
        __SO_REUSEPORT 'SO_REUSEPORT'

        __SO_PASSCRED 'SO_PASSCRED'
        __SO_PEERCRED 'SO_PEERCRED'
        __SO_RCVLOWAT 'SO_RCVLOWAT'
        __SO_SNDLOWAT 'SO_SNDLOWAT'

        __SO_BINDTODEVICE 'SO_BINDTODEVICE'

        # Socket filtering
        __SO_ATTACH_FILTER 'SO_ATTACH_FILTER'
        __SO_DETACH_FILTER 'SO_DETACH_FILTER'
        __SO_GET_FILTER 'SO_GET_FILTER'
        __SO_PEERNAME 'SO_PEERNAME'
        __SO_ACCEPTCONN 'SO_ACCEPTCONN'
        __SO_PEERSEC 'SO_PEERSEC'
        __SO_PASSSEC 'SO_PASSSEC'
        __SO_MARK 'SO_MARK'
        __SO_PROTOCOL 'SO_PROTOCOL'
        __SO_DOMAIN 'SO_DOMAIN'
        __SO_RXQ_OVFL 'SO_RXQ_OVFL'
        __SO_WIFI_STATUS 'SO_WIFI_STATUS'
        __SCM_WIFI_STATUS 'SCM_WIFI_STATUS'
        __SO_PEEK_OFF 'SO_PEEK_OFF'

        # not tested
        __SO_TIMESTAMP 'SO_TIMESTAMP'
        __SO_TIMESTAMPNS 'SO_TIMESTAMPNS'
        __SO_TIMESTAMPING 'SO_TIMESTAMPING'
        __SO_RCVTIMEO 'SO_RCVTIMEO'
        __SO_SNDTIMEO 'SO_SNDTIMEO'


cdef extern from '<netinet/in.h>' nogil:
    enum:  # internal use only
        __INET_ADDRSTRLEN 'INET_ADDRSTRLEN'
        __INET6_ADDRSTRLEN 'INET6_ADDRSTRLEN'

    # IP protocols.
    enum:
        __IPPROTO_IP 'IPPROTO_IP'               # Dummy protocol for TCP
        __IPPROTO_ICMP 'IPPROTO_ICMP'           # Internet Control Message Protocol
        __IPPROTO_IGMP 'IPPROTO_IGMP'           # Internet Group Management Protocol
        __IPPROTO_IPIP 'IPPROTO_IPIP'           # IPIP tunnels (older KA9Q tunnels use 94)
        __IPPROTO_TCP 'IPPROTO_TCP'             # Transmission Control Protocol
        __IPPROTO_EGP 'IPPROTO_EGP'             # Exterior Gateway Protocol
        __IPPROTO_PUP 'IPPROTO_PUP'             # PUP protocol
        __IPPROTO_UDP 'IPPROTO_UDP'             # User Datagram Protocol
        __IPPROTO_IDP 'IPPROTO_IDP'             # XNS IDP protocol
        __IPPROTO_TP 'IPPROTO_TP'               # SO Transport Protocol Class 4
        __IPPROTO_DCCP 'IPPROTO_DCCP'           # Datagram Congestion Control Protocol
        __IPPROTO_IPV6 'IPPROTO_IPV6'           # IPv6-in-IPv4 tunnelling
        __IPPROTO_RSVP 'IPPROTO_RSVP'           # RSVP Protocol
        __IPPROTO_GRE 'IPPROTO_GRE'             # Cisco GRE tunnels (rfc 1701,1702)
        __IPPROTO_ESP 'IPPROTO_ESP'             # Encapsulation Security Payload protocol
        __IPPROTO_AH 'IPPROTO_AH'               # Authentication Header protocol
        __IPPROTO_MTP 'IPPROTO_MTP'             # Multicast Transport Protocol
        __IPPROTO_BEETPH 'IPPROTO_BEETPH'       # IP option pseudo header for BEET
        __IPPROTO_ENCAP 'IPPROTO_ENCAP'         # Encapsulation Header
        __IPPROTO_PIM 'IPPROTO_PIM'             # Protocol Independent Multicast
        __IPPROTO_COMP 'IPPROTO_COMP'           # Compression Header Protocol
        # note: not supported
        # __IPPROTO_L2TP 'IPPROTO_L2TP'           # Layer 2 Tunnelling Protocol
        __IPPROTO_SCTP 'IPPROTO_SCTP'           # Stream Control Transport Protocol
        __IPPROTO_UDPLITE 'IPPROTO_UDPLITE'     # UDP-Lite (RFC 3828)
        __IPPROTO_MPLS 'IPPROTO_MPLS'           # MPLS in IP (RFC 4023)
        __IPPROTO_ETHERNET 'IPPROTO_ETHERNET'   # Ethernet-within-IPv6 Encapsulation
        __IPPROTO_RAW 'IPPROTO_RAW'             # Raw IP packets
        __IPPROTO_MPTCP 'IPPROTO_MPTCP'         # Multipath TCP connection
