from libc.string cimport memset
from .lib.socket cimport *
from .socket cimport *
from .error cimport trap_error


cdef class getaddrinfo:
    cdef __addrinfo* ptr


cpdef int bind(int sockfd, sockaddr addr) nogil
cpdef int listen(int sockfd, int backlog) nogil
cpdef int getpeername(int sockfd, sockaddr addr) nogil
cpdef tuple[bytes, uint16_t] getsockname(int sockfd, sockaddr addr)

cpdef tuple getnameinfo(sockaddr addr, int flags=?)

cpdef enum __extra_define__:
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
