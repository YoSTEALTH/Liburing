from .lib.socket cimport *
from .socket cimport *
from .error cimport trap_error


cpdef int bind(int sockfd, sockaddr addr) nogil
cpdef int listen(int sockfd, int backlog) nogil
cpdef int setsockopt(int sockfd, int level, int optname, int optval) nogil
cpdef int getsockopt(int sockfd, int level, int optname) nogil