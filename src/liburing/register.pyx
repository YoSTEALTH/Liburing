cpdef int io_uring_register_buffers(io_uring ring,
                                    iovec iovecs,
                                    unsigned int nr_iovecs) nogil:
    return trap_error(__io_uring_register_buffers(ring.ptr, iovecs.ptr, nr_iovecs))

cpdef int io_uring_register_buffers_tags(io_uring ring,
                                         iovec iovecs,
                                         const __u64 tags,
                                         unsigned int nr) nogil:
    return trap_error(__io_uring_register_buffers_tags(ring.ptr, iovecs.ptr, &tags, nr))

cpdef int io_uring_register_buffers_sparse(io_uring ring,
                                           unsigned int nr) nogil:
    return trap_error(__io_uring_register_buffers_sparse(ring.ptr, nr))

cpdef int io_uring_register_buffers_update_tag(io_uring ring,
                                               unsigned int off,
                                               iovec iovecs,
                                               const __u64 tags,
                                               unsigned int nr) nogil:
    return trap_error(__io_uring_register_buffers_update_tag(ring.ptr, off, iovecs.ptr, &tags, nr))

cpdef int io_uring_unregister_buffers(io_uring ring) nogil:
    return trap_error(__io_uring_unregister_buffers(ring.ptr))


cpdef int io_uring_register_eventfd(io_uring ring, int fd) nogil:
    return trap_error(__io_uring_register_eventfd(ring.ptr, fd))

cpdef int io_uring_register_eventfd_async(io_uring ring, int fd) nogil:
    return trap_error(__io_uring_register_eventfd_async(ring.ptr, fd))

cpdef int io_uring_unregister_eventfd(io_uring ring) nogil:
    return trap_error(__io_uring_unregister_eventfd(ring.ptr))

cpdef int io_uring_register_personality(io_uring ring) nogil:
    return trap_error(__io_uring_register_personality(ring.ptr))

cpdef int io_uring_unregister_personality(io_uring ring, int id) nogil:
    return trap_error(__io_uring_unregister_personality(ring.ptr, id))

cpdef int io_uring_register_restrictions(io_uring ring,
                                         io_uring_restriction res,
                                         unsigned int nr_res) nogil:
    return trap_error(__io_uring_register_restrictions(ring.ptr, res.ptr, nr_res))


cpdef int io_uring_register_iowq_aff(io_uring ring,
                                     size_t cpusz,
                                     const cpu_set_t mask) nogil:
    return trap_error(__io_uring_register_iowq_aff(ring.ptr, cpusz, &mask))

cpdef int io_uring_unregister_iowq_aff(io_uring ring) nogil:
    return trap_error(__io_uring_unregister_iowq_aff(ring.ptr))

cpdef int io_uring_register_iowq_max_workers(io_uring ring, unsigned int values) nogil:
    return trap_error(__io_uring_register_iowq_max_workers(ring.ptr, &values))

cpdef int io_uring_register_ring_fd(io_uring ring) nogil:
    return trap_error(__io_uring_register_ring_fd(ring.ptr))

cpdef int io_uring_unregister_ring_fd(io_uring ring) nogil:
    return trap_error(__io_uring_unregister_ring_fd(ring.ptr))

cpdef int io_uring_register_buf_ring(io_uring ring,
                                     io_uring_buf_reg reg,
                                     unsigned int flags) nogil:
    return trap_error(__io_uring_register_buf_ring(ring.ptr, reg.ptr, flags))

cpdef int io_uring_unregister_buf_ring(io_uring ring,
                                       int bgid) nogil:
    return trap_error(__io_uring_unregister_buf_ring(ring.ptr, bgid))

cpdef int io_uring_register_sync_cancel(io_uring ring,
                                        io_uring_sync_cancel_reg reg) nogil:
    return trap_error(__io_uring_register_sync_cancel(ring.ptr, reg.ptr))


cpdef int io_uring_register_file_alloc_range(io_uring ring,
                                             unsigned int off,
                                             unsigned int len):
    return trap_error(__io_uring_register_file_alloc_range(ring.ptr, off, len))


cpdef int io_uring_register_napi(io_uring ring, io_uring_napi napi) nogil:
    return trap_error(__io_uring_register_napi(ring.ptr, napi.ptr))

cpdef int io_uring_unregister_napi(io_uring ring, io_uring_napi napi) nogil:
    return trap_error(__io_uring_unregister_napi(ring.ptr, napi.ptr))


cpdef int io_uring_register_files(io_uring ring, list[int] fds):
    ''' Register File Descriptor

        Example
            >>> fds = [1, 2, 3]
            >>> io_uring_register_files(ring, fds)
            ...
            >>> io_uring_unregister_files(ring)

        Note
            "Registered files have less overhead per operation than normal files.
             This is due to the kernel grabbing a reference count on a file when an
             operation begins, and dropping it when it's done. When the process file
             table is shared, for example if the process has ever created any
             threads, then this cost goes up even more. Using registered files
             reduces the overhead of file reference management across requests that
             operate on a file."
    '''
    cdef array[int] _fds = array('i', fds)
    return trap_error(__io_uring_register_files(ring.ptr, _fds.data.as_ints, len(_fds)))

cpdef int io_uring_register_files_tags(io_uring ring,
                                       int files,
                                       __u64 tags,
                                       unsigned int nr) nogil:
    return trap_error(__io_uring_register_files_tags(ring.ptr, &files, &tags, nr))

cpdef int io_uring_register_files_sparse(io_uring ring,
                                         unsigned int nr) nogil:
    return trap_error(__io_uring_register_files_sparse(ring.ptr, nr))

cpdef int io_uring_register_files_update_tag(io_uring ring,
                                             unsigned int off,
                                             int files,
                                             __u64 tags,
                                             unsigned int nr_files) nogil:
    return trap_error(__io_uring_register_files_update_tag(ring.ptr, off, &files, &tags, nr_files))

cpdef int io_uring_unregister_files(io_uring ring) nogil:
    ''' Unregister All File Descriptor(s) '''
    return trap_error(__io_uring_unregister_files(ring.ptr))

cpdef int io_uring_register_files_update(io_uring ring,
                                         unsigned int off,
                                         int files,
                                         unsigned int nr_files) nogil:
    return trap_error(__io_uring_register_files_update(ring.ptr, off, &files, nr_files))
