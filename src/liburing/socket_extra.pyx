cpdef int bind(int sockfd, sockaddr addr) nogil:
    return trap_error(__bind(sockfd, <__sockaddr*>addr.ptr, addr.sizeof))

cpdef int listen(int sockfd, int backlog) nogil:
    return trap_error(__listen(sockfd, backlog))
