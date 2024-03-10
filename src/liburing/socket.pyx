from cpython.mem cimport PyMem_RawCalloc, PyMem_RawFree
from libc.string cimport memset
from .error cimport trap_error, memory_error, index_error


cdef class sockaddr:
    ''' Generic Socket Address.

        Example
            >>> addr = sockaddr(AF_UNIX, b'./path')
            >>> addr = sockaddr(AF_INET, b'0.0.0.0', 12345)
            >>> addr = sockaddr(AF_INET6, b'::1', 12345)
            >>> bind(sockfd, addr)
    '''
    def __cinit__(self, sa_family_t family=0, char* addr=b'', in_port_t port=0,
                  uint32_t scope_id=0):
        addr_len = len(addr)  # note: `char*` is pointer, have to use `len` to check logic.

        if family == __AF_UNIX:  # outgoing
            if not addr_len:
                raise ValueError('`sockaddr(AF_UNIX)` - `addr` not provided!')
            if addr_len > 108:
                raise ValueError('`sockaddr(AF_UNIX)` length of `addr` can not be `> 108`')

            self.ptr = <void*>sockaddr_un(addr)
            if self.ptr is NULL:
                memory_error(self)
            self.sizeof = sizeof(__sockaddr_un)
            self.family = family

        elif family == __AF_INET:  # outgoing
            if not (addr_len and port):
                raise ValueError('`sockaddr(AF_INET)` - `addr` or `port` not provided!')
            self.ptr = <void*>sockaddr_in(addr, port)
            if self.ptr is NULL:
                raise ValueError('`sockaddr(AF_INET)` - `addr` did not receive IPv4 address!')
            self.sizeof = sizeof(__sockaddr_in)
            self.family = family

        elif family == __AF_INET6:  # outgoing
            if not (addr_len and port):
                raise ValueError('`sockaddr(AF_INET6)` - `addr` or `port` not provided!')
            self.ptr = <void*>sockaddr_in6(addr, port, scope_id)
            if self.ptr is NULL:
                raise ValueError('`sockaddr(AF_INET6)` - `addr` did not receive IPv6 address!')
            self.sizeof = sizeof(__sockaddr_in6)
            self.family = family

        elif not family:  # incoming
            raise NotImplementedError
        else:  # error
            raise NotImplementedError

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    def __repr__(self):
        return f'{self.__class__.__name__}({self._test})' 

    @property
    def _test(self)-> dict:
        cdef:
            __sockaddr_un* _un
            __sockaddr_in* _in
            __sockaddr_in6* _in6
        if self.ptr is not NULL:
            if self.family == __AF_UNIX:
                _un = <__sockaddr_un*>self.ptr
                return _un[0]
            elif self.family == __AF_INET:
                _in = <__sockaddr_in*>self.ptr
                return _in[0]
            elif self.family == __AF_INET6:
                _in6 = <__sockaddr_in6*>self.ptr
                return _in6[0]
            else:
                return {}
        else:
            return {}


cdef __sockaddr_un* sockaddr_un(char* path) noexcept nogil:
    ''' UNIX Domain Sockets

        Note
            - don't forget to free the return `ptr` if calling this function directly
    '''
    cdef __sockaddr_un* ptr = <__sockaddr_un*>PyMem_RawCalloc(1, sizeof(__sockaddr_un))
    if ptr is not NULL:
        ptr.sun_family = __AF_UNIX
        ptr.sun_path = path
    return ptr

cdef __sockaddr_in* sockaddr_in(char* addr, in_port_t port) noexcept nogil:
    ''' IPv4 Internet Socket 

        Note
            - don't forget to free the return `ptr` if calling this function directly
    '''
    cdef __sockaddr_in* ptr = <__sockaddr_in*>PyMem_RawCalloc(1, sizeof(__sockaddr_in))
    if ptr is not NULL:
        if not __inet_pton(__AF_INET, addr, &ptr.sin_addr):
            PyMem_RawFree(ptr)
            return NULL
        ptr.sin_family = __AF_INET
        ptr.sin_port = __htons(port)
    return ptr

cdef __sockaddr_in6* sockaddr_in6(char *addr, in_port_t port, uint32_t scope_id) noexcept nogil:
    ''' IPv6 Internet Socket

        Note
            - don't forget to free the return `ptr` if calling this function directly
    '''
    cdef __sockaddr_in6* ptr = <__sockaddr_in6*>PyMem_RawCalloc(1, sizeof(__sockaddr_in6))
    if ptr is not NULL:
        if not __inet_pton(__AF_INET6, addr, &ptr.sin6_addr):
            PyMem_RawFree(ptr)
            return NULL
        ptr.sin6_family = __AF_INET6
        ptr.sin6_port = __htons(port)
        ptr.sin6_scope_id = scope_id
    return ptr


cdef class msghdr:
    ''' Note: not tested!!! '''
    def __cinit__(self):
        self.ptr = <__msghdr*>PyMem_RawCalloc(1, sizeof(__msghdr))
        if self.ptr is NULL:
            raise memory_error(self)

    def __dealloc__(self):
        if self.ptr is not NULL:
            PyMem_RawFree(self.ptr)
            self.ptr = NULL

    @property
    def msg_name(self):
        ''' Address to send to/receive from. '''
        return <object>self.ptr.msg_name

    @msg_name.setter
    def msg_name(self, object msg_name):
        self.ptr.msg_name = <void*>msg_name

    @property
    def msg_namelen(self):
        ''' Length of address data. '''
        return self.ptr.msg_namelen

    @msg_namelen.setter
    def msg_namelen(self, socklen_t msg_namelen):
        self.ptr.msg_namelen = msg_namelen

    # TODO: fix this

    # @property
    # def msg_iov(self):
    #     ''' Vector of data to send/receive into. '''
    #     return self.ptr.msg_iov

    # @msg_iov.setter
    # def msg_iov(self, iovec msg_iov):
    #     self.ptr.msg_iov = msg_iov.ptr

    @property
    def msg_iovlen(self):
        ''' Number of elements in the `iovec` vector. e.g: 1 '''
        return self.ptr.msg_iovlen

    @msg_iovlen.setter
    def msg_iovlen(self, size_t msg_iovlen):
        self.ptr.msg_iovlen = msg_iovlen

    @property
    def msg_control(self):
        ''' Ancillary data (eg BSD filedesc passing). '''
        return <object>self.ptr.msg_control

    @msg_control.setter
    def msg_control(self, object msg_control):
        self.ptr.msg_control = <void*>msg_control

    @property
    def msg_controllen(self):
        ''' Ancillary data buffer length. '''
        return self.ptr.msg_controllen

    @msg_controllen.setter
    def msg_controllen(self, size_t msg_controllen):
        self.ptr.msg_controllen = msg_controllen

    @property
    def msg_flags(self):
        ''' Flags on received message. '''
        return self.ptr.msg_flags

    @msg_flags.setter
    def msg_flags(self, int msg_flags):
        self.ptr.msg_flags = msg_flags

cdef class cmsghdr:
    ''' Note: not tested!!! '''
    def __bool__(self):
        return self.ptr is not NULL

cdef class io_uring_recvmsg_out:
    ''' Note: not tested!!! '''
    pass


cpdef inline void io_uring_prep_socket(io_uring_sqe sqe,
                                       int domain,
                                       int type,
                                       int protocol=0,
                                       unsigned int flags=0) noexcept nogil:
    __io_uring_prep_socket(sqe.ptr, domain, type, protocol, flags)

cpdef inline void io_uring_prep_socket_direct(io_uring_sqe sqe,
                                              int domain,
                                              int type,
                                              int protocol=0,
                                              unsigned int file_index=__IORING_FILE_INDEX_ALLOC,
                                              unsigned int flags=0) noexcept nogil:
    __io_uring_prep_socket_direct(sqe.ptr, domain, type, protocol, file_index, flags)

cpdef inline void io_uring_prep_socket_direct_alloc(io_uring_sqe sqe,
                                                    int domain,
                                                    int type,
                                                    int protocol=0,
                                                    unsigned int flags=0) noexcept nogil:
    __io_uring_prep_socket_direct_alloc(sqe.ptr, domain, type, protocol, flags)

cpdef inline void io_uring_prep_recvmsg(io_uring_sqe sqe,
                                        int fd,
                                        msghdr msg=None,
                                        unsigned int flags=0) noexcept nogil:
    __io_uring_prep_recvmsg(sqe.ptr, fd, msg.ptr, flags)

cpdef inline void io_uring_prep_recvmsg_multishot(io_uring_sqe sqe,
                                                  int fd, 
                                                  msghdr msg=None,
                                                  unsigned int flags=0) noexcept nogil:
    __io_uring_prep_recvmsg_multishot(sqe.ptr, fd, msg.ptr, flags)

cpdef inline void io_uring_prep_sendmsg(io_uring_sqe sqe,
                                        int fd,
                                        msghdr msg=None,
                                        unsigned int flags=0) noexcept nogil:
    __io_uring_prep_sendmsg(sqe.ptr, fd, msg.ptr, flags)

cpdef inline void io_uring_prep_accept(io_uring_sqe sqe,
                                       int fd,
                                       sockaddr addr=None,
                                       int flags=0) noexcept nogil:
    __io_uring_prep_accept(sqe.ptr, fd, <__sockaddr*>addr.ptr, &addr.sizeof, flags)

# accept directly into the fixed file table
cpdef inline void io_uring_prep_accept_direct(
                        io_uring_sqe sqe,
                        int fd,
                        sockaddr addr=None,
                        int flags=0,
                        unsigned int file_index=__IORING_FILE_INDEX_ALLOC) noexcept nogil:
    __io_uring_prep_accept_direct(sqe.ptr, fd, <__sockaddr*>addr.ptr, &addr.sizeof, flags,
                                  file_index)

cpdef inline void io_uring_prep_multishot_accept(io_uring_sqe sqe,
                                                 int fd,
                                                 sockaddr addr=None,
                                                 int flags=0) noexcept nogil:
    __io_uring_prep_multishot_accept(sqe.ptr, fd, <__sockaddr*>addr.ptr, &addr.sizeof, flags)

# multishot accept directly into the fixed file table
cpdef inline void io_uring_prep_multishot_accept_direct(io_uring_sqe sqe,
                                                        int fd,
                                                        sockaddr addr=None,
                                                        int flags=0) noexcept nogil:
    __io_uring_prep_multishot_accept_direct(sqe.ptr, fd, <__sockaddr*>addr.ptr, &addr.sizeof, flags)

cpdef inline void io_uring_prep_connect(io_uring_sqe sqe,
                                        int fd,
                                        sockaddr addr) noexcept:
    __io_uring_prep_connect(sqe.ptr, fd, <__sockaddr*>addr.ptr, addr.sizeof)

cpdef inline void io_uring_prep_send(io_uring_sqe sqe,
                                     int sockfd,
                                     const unsigned char[:] buf,  # const void *buf,
                                     size_t len,
                                     int flags=0) noexcept nogil:
    __io_uring_prep_send(sqe.ptr, sockfd, &buf[0], len, flags)

cpdef inline void io_uring_prep_send_set_addr(io_uring_sqe sqe,
                                              sockaddr dest_addr) noexcept nogil:
    __io_uring_prep_send_set_addr(sqe.ptr, <__sockaddr*>dest_addr.ptr, dest_addr.sizeof)

cpdef inline void io_uring_prep_sendto(io_uring_sqe sqe,
                                       int sockfd,
                                       const unsigned char[:] buf,  # const void *buf,
                                       size_t len,
                                       sockaddr addr,
                                       int flags=0) noexcept nogil:
    __io_uring_prep_sendto(sqe.ptr, sockfd, &buf[0], len, flags, <__sockaddr*>addr.ptr, addr.sizeof)

cpdef inline void  io_uring_prep_send_zc(io_uring_sqe sqe,
                                         int sockfd,
                                         const unsigned char[:] buf,  # const void *buf,
                                         size_t len,
                                         int flags=0,
                                         unsigned int zc_flags=0) noexcept nogil:
    __io_uring_prep_send_zc(sqe.ptr, sockfd, &buf[0], len, flags, zc_flags)

cpdef inline void io_uring_prep_send_zc_fixed(io_uring_sqe sqe,
                                              int sockfd,
                                              const unsigned char[:] buf,  # const void *buf,
                                              size_t len,
                                              unsigned int buf_index,
                                              int flags=0,
                                              unsigned int zc_flags=0) noexcept nogil:
    __io_uring_prep_send_zc_fixed(sqe.ptr, sockfd, &buf[0], len, flags, zc_flags, buf_index)

cpdef inline void io_uring_prep_sendmsg_zc(io_uring_sqe sqe,
                                           int fd,
                                           msghdr msg,  # const __msghdr *msg,
                                           unsigned int flags=0) noexcept nogil:
    __io_uring_prep_sendmsg_zc(sqe.ptr, fd, msg.ptr, flags)

cpdef inline void io_uring_prep_recv(io_uring_sqe sqe,
                                     int sockfd,
                                     unsigned char[:] buf,  # void *buf,
                                     size_t len,
                                     int flags=0) noexcept nogil:
    __io_uring_prep_recv(sqe.ptr, sockfd, &buf[0], len, flags)

cpdef inline void io_uring_prep_recv_multishot(io_uring_sqe sqe,
                                               int sockfd,
                                               unsigned char[:] buf,  # void *buf,
                                               size_t len,
                                               int flags=0) noexcept nogil:
    __io_uring_prep_recv_multishot(sqe.ptr, sockfd, &buf[0], len, flags)

cpdef inline io_uring_recvmsg_out io_uring_recvmsg_validate(unsigned char[:] buf,  # void *buf
                                                            int buf_len,
                                                            msghdr msgh):
    cdef io_uring_recvmsg_out msg = io_uring_recvmsg_out()
    msg.ptr = __io_uring_recvmsg_validate(&buf[0], buf_len, msgh.ptr)
    return msg

# TODO:
# cpdef inline void * io_uring_recvmsg_name(io_uring_recvmsg_out o) noexcept nogil:
#     __io_uring_recvmsg_name(o.ptr)

cpdef inline cmsghdr io_uring_recvmsg_cmsg_firsthdr(io_uring_recvmsg_out o,
                                                    msghdr msgh):
    cdef cmsghdr cms = cmsghdr()
    cms.ptr = __io_uring_recvmsg_cmsg_firsthdr(o.ptr, msgh.ptr)
    return cms

cpdef inline cmsghdr io_uring_recvmsg_cmsg_nexthdr(io_uring_recvmsg_out o,
                                                   msghdr msgh,
                                                   cmsghdr cmsg):
    cdef cmsghdr cms = cmsghdr()
    cms.ptr = __io_uring_recvmsg_cmsg_nexthdr(o.ptr, msgh.ptr, cmsg.ptr)
    return cms

# TODO:
# cpdef inline void * io_uring_recvmsg_payload(io_uring_recvmsg_out o, msghdr msgh) noexcept nogil:
#     __io_uring_recvmsg_payload(o.ptr, msgh.ptr)

cpdef inline unsigned int io_uring_recvmsg_payload_length(io_uring_recvmsg_out o,
                                                          int buf_len,
                                                          msghdr msgh) noexcept nogil:
    return __io_uring_recvmsg_payload_length(o.ptr, buf_len, msgh.ptr)

cpdef inline void io_uring_prep_shutdown(io_uring_sqe sqe, int fd, int how) noexcept nogil:
    __io_uring_prep_shutdown(sqe.ptr, fd, how)

# Prepare commands for sockets
cpdef inline void io_uring_prep_cmd_sock(io_uring_sqe sqe,
                                         int cmd_op,
                                         int fd,
                                         int level,
                                         int optname,
                                         unsigned char[:] optval,  # void *optval,
                                         int optlen) noexcept nogil:
    __io_uring_prep_cmd_sock(sqe.ptr, cmd_op, fd, level, optname, &optval[0], optlen)


# defines
cpdef enum SocketFamily:
    AF_UNIX = __AF_UNIX
    AF_INET = __AF_INET
    AF_INET6 = __AF_INET6

cpdef enum SocketType:
    SOCK_STREAM = __SOCK_STREAM
    SOCK_DGRAM = __SOCK_DGRAM
    SOCK_RAW = __SOCK_RAW
    SOCK_RDM = __SOCK_RDM
    SOCK_SEQPACKET = __SOCK_SEQPACKET
    SOCK_DCCP = __SOCK_DCCP
    SOCK_PACKET = __SOCK_PACKET
    SOCK_CLOEXEC = __SOCK_CLOEXEC
    SOCK_NONBLOCK = __SOCK_NONBLOCK

cpdef enum ShutdownHow:
    SHUT_RD = __SHUT_RD
    SHUT_WR = __SHUT_WR
    SHUT_RDWR = __SHUT_RDWR

cpdef enum io_uring_socket_op:
    SOCKET_URING_OP_SIOCINQ = __SOCKET_URING_OP_SIOCINQ
    SOCKET_URING_OP_SIOCOUTQ = __SOCKET_URING_OP_SIOCOUTQ
    SOCKET_URING_OP_GETSOCKOPT = __SOCKET_URING_OP_GETSOCKOPT
    SOCKET_URING_OP_SETSOCKOPT = __SOCKET_URING_OP_SETSOCKOPT
