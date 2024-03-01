from .lib.uring cimport *
from .queue cimport io_uring_sqe


cdef class io_uring_recvmsg_out:
    cdef __io_uring_recvmsg_out * ptr

cdef class sockaddr_storage:
    cdef __sockaddr_storage *ptr

cdef class sockaddr:
    cdef __sockaddr *ptr

cdef class sockaddr_un:
    cdef __sockaddr_un *ptr

cdef class sockaddr_in:
    cdef __sockaddr_in *ptr

cdef class sockaddr_in6:
    cdef __sockaddr_in6 *ptr

cdef class msghdr:
    cdef __msghdr *ptr

cdef class cmsghdr:
    cdef __cmsghdr *ptr


cpdef void io_uring_prep_recvmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg,
                                 unsigned int flags) noexcept nogil
cpdef void io_uring_prep_recvmsg_multishot(io_uring_sqe sqe,
                                           int fd, 
                                           msghdr msg,
                                           unsigned int flags) noexcept nogil
cpdef void io_uring_prep_sendmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg,
                                 unsigned int flags) noexcept nogil
cpdef void io_uring_prep_accept(io_uring_sqe sqe,
                                int fd,
                                sockaddr addr,
                                socklen_t addrlen,
                                int flags) noexcept nogil
cpdef void io_uring_prep_accept_direct(io_uring_sqe sqe,
                                       int fd,
                                       sockaddr addr,
                                       socklen_t addrlen,
                                       int flags,
                                       unsigned int file_index) noexcept nogil
cpdef void io_uring_prep_multishot_accept(io_uring_sqe sqe,
                                          int fd,
                                          sockaddr addr,
                                          socklen_t addrlen,
                                          int flags) noexcept nogil
cpdef void io_uring_prep_multishot_accept_direct(io_uring_sqe sqe,
                                                 int fd,
                                                 sockaddr addr,
                                                 socklen_t addrlen,
                                                 int flags) noexcept nogil
cpdef void io_uring_prep_connect(io_uring_sqe sqe,
                                 int fd,
                                 sockaddr addr,
                                 socklen_t addrlen) noexcept nogil
cpdef void io_uring_prep_send(io_uring_sqe sqe,
                              int sockfd,
                              const unsigned char[:] buf,
                              size_t len,
                              int flags) noexcept nogil
cpdef void io_uring_prep_send_set_addr(io_uring_sqe sqe,
                                       sockaddr dest_addr,
                                       __u16 addr_len) noexcept nogil
cpdef void io_uring_prep_sendto(io_uring_sqe sqe,
                                int sockfd,
                                const unsigned char[:] buf,
                                size_t len,
                                int flags,
                                sockaddr addr,
                                socklen_t addrlen) noexcept nogil
cpdef void  io_uring_prep_send_zc(io_uring_sqe sqe,
                                  int sockfd,
                                  const unsigned char[:] buf,
                                  size_t len,
                                  int flags,
                                  unsigned int zc_flags) noexcept nogil
cpdef void io_uring_prep_send_zc_fixed(io_uring_sqe sqe,
                                       int sockfd,
                                       const unsigned char[:] buf,
                                       size_t len,
                                       int flags,
                                       unsigned int zc_flags,
                                       unsigned int buf_index) noexcept nogil
cpdef void io_uring_prep_sendmsg_zc(io_uring_sqe sqe,
                                    int fd,
                                    msghdr msg,
                                    unsigned int flags) noexcept nogil
cpdef void io_uring_prep_recv(io_uring_sqe sqe,
                              int sockfd,
                              unsigned char[:] buf,
                              size_t len,
                              int flags) noexcept nogil
cpdef void io_uring_prep_recv_multishot(io_uring_sqe sqe,
                                        int sockfd,
                                        unsigned char[:] buf,
                                        size_t len,
                                        int flags) noexcept nogil
cpdef io_uring_recvmsg_out io_uring_recvmsg_validate(unsigned char[:] buf,
                                                     int buf_len,
                                                     msghdr msgh)
# TODO:
# cpdef void * io_uring_recvmsg_name(io_uring_recvmsg_out o) noexcept nogil
cpdef cmsghdr io_uring_recvmsg_cmsg_firsthdr(io_uring_recvmsg_out o, msghdr msgh)
cpdef cmsghdr io_uring_recvmsg_cmsg_nexthdr(io_uring_recvmsg_out o,
                                            msghdr msgh,
                                            cmsghdr cmsg)
# TODO:
# cpdef void * io_uring_recvmsg_payload(io_uring_recvmsg_out o, msghdr msgh) noexcept nogil
cpdef unsigned int io_uring_recvmsg_payload_length(io_uring_recvmsg_out o,
                                                   int buf_len,
                                                   msghdr msgh) noexcept nogil
cpdef void io_uring_prep_shutdown(io_uring_sqe sqe, int fd, int how) noexcept nogil
cpdef void io_uring_prep_socket(io_uring_sqe sqe,
                                int domain,
                                int type,
                                int protocol,
                                unsigned int flags) noexcept nogil
cpdef void io_uring_prep_socket_direct(io_uring_sqe sqe,
                                       int domain,
                                       int type,
                                       int protocol,
                                       unsigned int file_index,
                                       unsigned int flags) noexcept nogil
cpdef void io_uring_prep_socket_direct_alloc(io_uring_sqe sqe,
                                             int domain,
                                             int type,
                                             int protocol,
                                             unsigned int flags) noexcept nogil
cpdef void io_uring_prep_cmd_sock(io_uring_sqe sqe,
                                  int cmd_op,
                                  int fd,
                                  int level,
                                  int optname,
                                  unsigned char[:] optval,
                                  int optlen) noexcept nogil