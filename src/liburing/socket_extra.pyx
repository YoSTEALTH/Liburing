cdef class getaddrinfo:
    def __cinit__(self, const char* host, char* port_service,
                  int family=0, int type=0, int proto=0, int flags=0):
        '''
            Example
                >>> for af_, sock_, proto, canon, addr in getaddrinfo(b'127.0.0.1', b'12345'):
                ...     ...
                ...     io_uring_prep_socket(sqe, af_, sock_)
                ...     ...
                ...     io_uring_prep_connect(sqe, sockfd, addr)
                ...     ...
                ...     break  # if connected successfully, break, else try next.
        '''
        # TODO: `port_service` should handle both `int` & `bytes` types.
        cdef:
            int         no
            __addrinfo  hints

        memset(&hints, 0, sizeof(__addrinfo))
        hints.ai_flags = flags
        hints.ai_family = family
        hints.ai_socktype = type
        hints.ai_protocol = proto
        if no := __getaddrinfo(host, port_service, &hints, &self.ptr):
            trap_error(no, __gai_strerror(no).decode())

    def __dealloc__(self):
        if self.ptr is not NULL:
            __freeaddrinfo(self.ptr)
            self.ptr = NULL

    def __iter__(self):
        cdef:
            __addrinfo* p = self.ptr
            sockaddr addr
        while p.ai_next is not NULL:
            addr = sockaddr()
            addr.ptr = p.ai_addr
            addr.family = p.ai_family
            addr.sizeof = p.ai_addrlen
            yield (
                p.ai_family,
                p.ai_socktype,
                p.ai_protocol,
                p.ai_canonname or b'',
                addr
            )
            p = p.ai_next


cpdef int getpeername(int sockfd, sockaddr addr) nogil:
    ''' TODO '''
    return trap_error(__getpeername(sockfd, <__sockaddr*>addr.ptr, &addr.sizeof))

cpdef tuple getsockname(int sockfd, sockaddr addr):
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

        Note
            - return type will depend on content being returned.
    '''
    cdef:
        char host[__NI_MAXHOST]
        char service[__NI_MAXSERV]

    trap_error(__getnameinfo(<__sockaddr*>addr.ptr, addr.sizeof,
                             host, sizeof(host), service, sizeof(service), flags))
    return (host, int(service) if service.isdigit() else service)


cpdef bint isIP(sa_family_t family, char* value) noexcept nogil:
    '''
        Example
            >>> isIP(AF_INET, b'0.0.0.0')
            True
            >>> isIP(AF_INET6, b'::1')
            True
            >>> isIP(AF_INET6, b'domain.ext')
            False
            >>> isIP(AF_INET, b'domain.ext')
            False
            >>> isIP(AF_UNIX, b'/path/socket')
            False
    '''
    cdef:
        __sockaddr_in  ptr_in
        __sockaddr_in6 ptr_in6

    if family == __AF_INET:
        return __inet_pton(family, value, &ptr_in.sin_addr)
    elif family == __AF_INET6:
        return __inet_pton(family, value, &ptr_in6.sin6_addr)
    else:
        return False
