from cpython.array cimport array
from .lib.uring cimport *
from .error cimport trap_error
from .common cimport iovec
from .queue cimport io_uring


cdef class io_uring_restriction:
    cdef __io_uring_restriction * ptr

cdef class io_uring_buf_reg:
    cdef __io_uring_buf_reg * ptr

cdef class io_uring_sync_cancel_reg:
    cdef __io_uring_sync_cancel_reg * ptr

cdef class io_uring_napi:
    cdef __io_uring_napi * ptr

cdef class io_uring_mem_region_reg:
    cdef __io_uring_mem_region_reg * ptr


cpdef int io_uring_register_buffers(io_uring ring,
                                    iovec iovecs,
                                    unsigned int nr_iovecs) nogil
cpdef int io_uring_register_buffers_tags(io_uring ring,
                                         iovec iovecs,
                                         const __u64 tags,
                                         unsigned int nr) nogil
cpdef int io_uring_register_buffers_sparse(io_uring ring,
                                           unsigned int nr) nogil
cpdef int io_uring_register_buffers_update_tag(io_uring ring,
                                               unsigned int off,
                                               iovec iovecs,
                                               const __u64 tags,
                                               unsigned int nr) nogil
cpdef int io_uring_unregister_buffers(io_uring ring) nogil

cpdef int io_uring_register_eventfd(io_uring ring, int fd) nogil
cpdef int io_uring_register_eventfd_async(io_uring ring, int fd) nogil
cpdef int io_uring_unregister_eventfd(io_uring ring) nogil

cpdef int io_uring_register_personality(io_uring ring) nogil
cpdef int io_uring_unregister_personality(io_uring ring, int id) nogil
cpdef int io_uring_register_restrictions(io_uring ring,
                                         io_uring_restriction res,
                                         unsigned int nr_res) nogil

cpdef int io_uring_register_iowq_aff(io_uring ring,
                                     size_t cpusz,
                                     const cpu_set_t mask) nogil
cpdef int io_uring_unregister_iowq_aff(io_uring ring) nogil
cpdef int io_uring_register_iowq_max_workers(io_uring ring, unsigned int values) nogil
cpdef int io_uring_register_ring_fd(io_uring ring) nogil
cpdef int io_uring_unregister_ring_fd(io_uring ring) nogil

cpdef int io_uring_register_buf_ring(io_uring ring,
                                     io_uring_buf_reg reg,
                                     unsigned int flags) nogil
cpdef int io_uring_unregister_buf_ring(io_uring ring,
                                       int bgid) nogil
cpdef int io_uring_register_sync_cancel(io_uring ring,
                                        io_uring_sync_cancel_reg reg) nogil

cpdef int io_uring_register_file_alloc_range(io_uring ring,
                                             unsigned int off,
                                             unsigned int len)

cpdef int io_uring_register_napi(io_uring ring, io_uring_napi napi) nogil
cpdef int io_uring_unregister_napi(io_uring ring, io_uring_napi napi) nogil


cpdef int io_uring_register_files(io_uring ring, list[int] fds)
cpdef int io_uring_register_files_tags(io_uring ring,
                                       int files,
                                       __u64 tags,
                                       unsigned int nr) nogil
cpdef int io_uring_register_files_sparse(io_uring ring,
                                         unsigned int nr) nogil
cpdef int io_uring_register_files_update_tag(io_uring ring,
                                             unsigned int off,
                                             int files,
                                             __u64 tags,
                                             unsigned int nr_files) nogil
cpdef int io_uring_unregister_files(io_uring ring) nogil
cpdef int io_uring_register_files_update(io_uring ring,
                                         unsigned int off,
                                         int files,
                                         unsigned int nr_files) nogil

cpdef int io_uring_register_region(io_uring ring, io_uring_mem_region_reg reg) nogil
