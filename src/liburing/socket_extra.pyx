from libc.string cimport memset


cpdef int bind(int sockfd, sockaddr addr) nogil:
    return trap_error(__bind(sockfd, <__sockaddr*>addr.ptr, addr.sizeof))

cpdef int listen(int sockfd, int backlog) nogil:
    return trap_error(__listen(sockfd, backlog))

cpdef int getpeername(int sockfd, sockaddr addr) nogil:
    ''' TODO '''
    return trap_error(__getpeername(sockfd, <__sockaddr*>addr.ptr, &addr.sizeof))

cpdef tuple[bytes, uint16_t] getsockname(int sockfd, sockaddr addr):
    '''
        Example
            >>> addr = sockaddr(b'127.0.0.1', 0)
            >>> bind(sockfd, addr)
            >>> getsockname(sockfd, addr)
            b'127.0.0.1', 6744  # random port

        Note
            - if port is `0` & `bind` is used, socket will get assigned random port by OS.
    '''
    cdef:
        __sockaddr_in ptr4
        __sockaddr_in6 ptr6
        socklen_t size
        uint16_t port
        char* ip
        char ip4_char[__INET_ADDRSTRLEN]
        char ip6_char[__INET6_ADDRSTRLEN]

    if addr.family == __AF_INET:
        ip = ip4_char
        size = sizeof(__sockaddr_in)
        memset(&ptr4, 0, size)
        trap_error(__getsockname(sockfd, <__sockaddr*>&ptr4, &size))
        __inet_ntop(addr.family, &ptr4.sin_addr, ip, __INET_ADDRSTRLEN)
        port = __htons(ptr4.sin_port)

    elif addr.family == __AF_INET6:
        ip = ip6_char
        size = sizeof(__sockaddr_in6)
        memset(&ptr6, 0, size)
        trap_error(__getsockname(sockfd, <__sockaddr*>&ptr6, &size))
        __inet_ntop(addr.family, &ptr6.sin6_addr, ip, __INET6_ADDRSTRLEN)
        port = __htons(ptr6.sin6_port)
    else:
        raise TypeError('getsockname() - received `addr.family` type not supported!')
    return (ip, port)


cpdef tuple getnameinfo(sockaddr addr, int flags=0):
    '''
        Example
            >>> addr = sockaddr(liburing.AF_INET, b'0.0.0.0', 12345)
            >>> getnameinfo(addr, liburing.NI_NUMERICHOST | liburing.NI_NUMERICSERV)
            (b'0.0.0.0', b'12345')

        Flags
            NI_NUMERICHOST  # Don't try to look up hostname.
            NI_NUMERICSERV  # Don't convert port number to name.
            NI_NOFQDN       # Only return nodename portion.
            NI_NAMEREQD     # Don't return numeric addresses.
            NI_DGRAM        # Look up UDP service rather than TCP.
            NI_IDN          # Convert name from IDN format.
    '''
    cdef:
        char host[__NI_MAXHOST]
        char service[__NI_MAXSERV]

    trap_error(__getnameinfo(<__sockaddr*>addr.ptr, addr.sizeof,
                             host, sizeof(host), service, sizeof(service), flags))
    return (host, service)


# getaddrinfo/getnameinfo start >>>
AI_PASSIVE = __AI_PASSIVE
AI_CANONNAME = __AI_CANONNAME
AI_NUMERICHOST = __AI_NUMERICHOST
AI_V4MAPPED = __AI_V4MAPPED
AI_ALL = __AI_ALL
AI_ADDRCONFIG = __AI_ADDRCONFIG
AI_IDN = __AI_IDN
AI_CANONIDN = __AI_CANONIDN
AI_NUMERICSERV = __AI_NUMERICSERV

NI_NUMERICHOST = __NI_NUMERICHOST
NI_NUMERICSERV = __NI_NUMERICSERV
NI_NOFQDN = __NI_NOFQDN
NI_NAMEREQD = __NI_NAMEREQD
NI_DGRAM = __NI_DGRAM
NI_IDN = __NI_IDN
# getaddrinfo/getnameinfo end <<<
