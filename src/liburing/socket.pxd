from cpython.array cimport array
from .lib.uring cimport *
from .queue cimport io_uring_sqe


cdef class sockaddr:
    cdef:
        void* ptr
        socklen_t sizeof
        readonly sa_family_t family


cdef __sockaddr_un* sockaddr_un(char* path) noexcept nogil
cdef __sockaddr_in* sockaddr_in(char* addr, in_port_t port) noexcept nogil
cdef __sockaddr_in6* sockaddr_in6(char *addr, in_port_t port, uint32_t scope_id) noexcept nogil


cdef class msghdr:
    cdef __msghdr* ptr

cdef class cmsghdr:
    cdef __cmsghdr* ptr


cdef class io_uring_recvmsg_out:
    cdef __io_uring_recvmsg_out* ptr


cpdef void io_uring_prep_socket(io_uring_sqe sqe,
                                int domain,
                                int type,
                                int protocol=?,
                                unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct(io_uring_sqe sqe,
                                       int domain,
                                       int type,
                                       int protocol=?,
                                       unsigned int file_index=?,
                                       unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_socket_direct_alloc(io_uring_sqe sqe,
                                             int domain,
                                             int type,
                                             int protocol=?,
                                             unsigned int flags=?) noexcept nogil

cpdef void io_uring_prep_recvmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg=?,
                                 unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_recvmsg_multishot(io_uring_sqe sqe,
                                           int fd, 
                                           msghdr msg=?,
                                           unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_sendmsg(io_uring_sqe sqe,
                                 int fd,
                                 msghdr msg=?,
                                 unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_accept(io_uring_sqe sqe,
                                int fd,
                                sockaddr addr=?,
                                int flags=?) noexcept nogil
cpdef void io_uring_prep_accept_direct(io_uring_sqe sqe,
                                       int fd,
                                       sockaddr addr=?,
                                       int flags=?,
                                       unsigned int file_index=?) noexcept nogil
cpdef void io_uring_prep_multishot_accept(io_uring_sqe sqe,
                                          int fd,
                                          sockaddr addr=?,
                                          int flags=?) noexcept nogil
cpdef void io_uring_prep_multishot_accept_direct(io_uring_sqe sqe,
                                                 int fd,
                                                 sockaddr addr=?,
                                                 int flags=?) noexcept nogil
cpdef void io_uring_prep_connect(io_uring_sqe sqe,
                                 int fd,
                                 sockaddr addr) noexcept
cpdef void io_uring_prep_send(io_uring_sqe sqe,
                              int sockfd,
                              const unsigned char[:] buf,
                              size_t len,
                              int flags=?) noexcept nogil
cpdef void io_uring_prep_send_set_addr(io_uring_sqe sqe,
                                       sockaddr dest_addr) noexcept nogil
cpdef void io_uring_prep_sendto(io_uring_sqe sqe,
                                int sockfd,
                                const unsigned char[:] buf,
                                size_t len,
                                sockaddr addr,
                                int flags=?) noexcept nogil
cpdef void  io_uring_prep_send_zc(io_uring_sqe sqe,
                                  int sockfd,
                                  const unsigned char[:] buf,
                                  size_t len,
                                  int flags=?,
                                  unsigned int zc_flags=?) noexcept nogil
cpdef void io_uring_prep_send_zc_fixed(io_uring_sqe sqe,
                                       int sockfd,
                                       const unsigned char[:] buf,
                                       size_t len,
                                       unsigned int buf_index,
                                       int flags=?,
                                       unsigned int zc_flags=?) noexcept nogil
cpdef void io_uring_prep_sendmsg_zc(io_uring_sqe sqe,
                                    int fd,
                                    msghdr msg,
                                    unsigned int flags=?) noexcept nogil
cpdef void io_uring_prep_recv(io_uring_sqe sqe,
                              int sockfd,
                              unsigned char[:] buf,
                              size_t len,
                              int flags=?) noexcept nogil
cpdef void io_uring_prep_recv_multishot(io_uring_sqe sqe,
                                        int sockfd,
                                        unsigned char[:] buf,
                                        size_t len,
                                        int flags=?) noexcept nogil
cpdef io_uring_recvmsg_out io_uring_recvmsg_validate(unsigned char[:] buf,
                                                     int buf_len,
                                                     msghdr msgh)
# TODO:
# cpdef void* io_uring_recvmsg_name(io_uring_recvmsg_out o) noexcept nogil
cpdef cmsghdr io_uring_recvmsg_cmsg_firsthdr(io_uring_recvmsg_out o, msghdr msgh)
cpdef cmsghdr io_uring_recvmsg_cmsg_nexthdr(io_uring_recvmsg_out o,
                                            msghdr msgh,
                                            cmsghdr cmsg)
# TODO:
# cpdef void* io_uring_recvmsg_payload(io_uring_recvmsg_out o, msghdr msgh) noexcept nogil
cpdef unsigned int io_uring_recvmsg_payload_length(io_uring_recvmsg_out o,
                                                   int buf_len,
                                                   msghdr msgh) noexcept nogil
cpdef void io_uring_prep_shutdown(io_uring_sqe sqe, int fd, int how) noexcept nogil


cpdef void io_uring_prep_cmd_sock(io_uring_sqe sqe,
                                  int cmd_op,
                                  int sockfd,
                                  int level,
                                  int optname,
                                  array optval)

cpdef void io_uring_prep_setsockopt(io_uring_sqe sqe,
                                    int sockfd,
                                    int level,
                                    int optname,
                                    array optval)
cpdef void io_uring_prep_getsockopt(io_uring_sqe sqe,
                                    int sockfd,
                                    int level,
                                    int optname,
                                    array optval)
