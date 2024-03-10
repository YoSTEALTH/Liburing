cpdef int bind(int sockfd, sockaddr addr) nogil:
    return trap_error(__bind(sockfd, <__sockaddr*>addr.ptr, addr.sizeof))

cpdef int listen(int sockfd, int backlog) nogil:
    return trap_error(__listen(sockfd, backlog))

cpdef int setsockopt(int sockfd, int level, int optname, int optval) nogil:
    '''
        Example
            >>> setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, 1)
            >>> setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, 0)
            >>> setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, 123)
    '''
    return trap_error(__setsockopt(sockfd, level, optname, &optval, sizeof(optval)))
    # note: only commonly used features provided.

cpdef int getsockopt(int sockfd, int level, int optname) nogil:
    '''
        Example
            >>> getsockopt(fd, SOL_SOCKET, SO_ERROR)
    '''
    cdef:
        int32_t optval
        socklen_t length = sizeof(optval)
    return trap_error(__getsockopt(sockfd, level, optname, &optval, &length))
    # note: only commonly used features provided.

# defines
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

SO_TIMESTAMP = __SO_TIMESTAMP
SO_TIMESTAMPNS = __SO_TIMESTAMPNS
SO_TIMESTAMPING = __SO_TIMESTAMPING
SO_RCVTIMEO = __SO_RCVTIMEO
SO_SNDTIMEO = __SO_SNDTIMEO
