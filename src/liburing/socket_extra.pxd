from .lib.socket cimport *
from .socket cimport *
from .error cimport trap_error


cpdef int bind(int sockfd, sockaddr addr) nogil
cpdef int listen(int sockfd, int backlog) nogil
cpdef int getpeername(int sockfd, sockaddr addr) nogil
cpdef tuple[bytes, uint16_t] getsockname(int sockfd, sockaddr addr)

cpdef tuple getnameinfo(sockaddr addr, int flags=?)
