from os import O_CREAT, O_RDWR
from os.path import join
from pytest import mark, skip
from liburing import AT_FDCWD, RESOLVE_CACHED, io_uring, io_uring_cqes, iovec, io_uring_queue_init, \
                     io_uring_get_sqe, io_uring_prep_openat2, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_queue_exit, io_uring_register_buffers, \
                     open_how, skip_os
from test_helper import submit_wait_result


version = '5.6'


@mark.skipif(skip_os(version), reason=f'Requires Linux {version}+')
def test_openat2(tmpdir):
    ring = io_uring()
    cqes = io_uring_cqes()
    # prep
    buffers = (bytearray(b'hello world'), bytearray(11))
    iov = iovec(*buffers)
    file_path = join(tmpdir, 'openat2_test.txt').encode()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0
        assert io_uring_register_buffers(ring, iov, len(iov)) == 0

        # open
        how = open_how(O_CREAT | O_RDWR, 0o700)
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat2(sqe, AT_FDCWD, file_path, how)
        fd = submit_wait_result(ring, cqes)

        # write
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, iov[0].iov_base, iov[0].iov_len, 0)
        assert submit_wait_result(ring, cqes) == 11

        # read
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, iov[1].iov_base, iov[1].iov_len, 0)
        assert submit_wait_result(ring, cqes) == 11

        # confirm
        assert buffers[0] == buffers[1]

        # close
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        submit_wait_result(ring, cqes)

        if skip_os('5.12'):
            skip('RESOLVE_CACHED 5.12+ Linux required')
        else:
            # second open for resolve test
            how = open_how(O_RDWR, 0, RESOLVE_CACHED)
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_openat2(sqe, AT_FDCWD, file_path, how)
            fd2 = submit_wait_result(ring, cqes)

            assert fd2 > 0

            # close `fd2`
            sqe = io_uring_get_sqe(ring)
            io_uring_prep_close(sqe, fd2)
            assert submit_wait_result(ring, cqes) == 0
    finally:
        io_uring_queue_exit(ring)


@mark.skipif(skip_os('5.12'), reason='Requires Linux 5.12+')
def test_openat2_resolve_cache(tmpdir):
    ring = io_uring()
    cqes = io_uring_cqes()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        how = open_how(O_CREAT, 0o600, RESOLVE_CACHED)
        lookup_path = join(tmpdir, 'lookup-file.txt').encode()

        for _ in range(2, 0, -1):  # countdown
            try:
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_openat2(sqe, AT_FDCWD, lookup_path, how)
                fd = submit_wait_result(ring, cqes)
            except BlockingIOError:
                if how[0].resolve & RESOLVE_CACHED:
                    how[0].resolve = how[0].resolve & ~RESOLVE_CACHED
                # note:
                #   must retry without `RESOLVE_CACHED` since
                #   file path was not in kernel's lookup cache.
            else:
                assert fd > 0

                # close `fd`
                sqe = io_uring_get_sqe(ring)
                io_uring_prep_close(sqe, fd)
                assert submit_wait_result(ring, cqes) == 0
                break
        else:
            assert False  # failed to create file
    finally:
        io_uring_queue_exit(ring)
