import socket
import liburing


def test_socket():
    ring = liburing.io_uring()

    # socket
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, True)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, True)
    server.setblocking(False)
    server.bind(('0.0.0.0', 3000))
    server.listen(32)

    # prepare
    fd = server.fileno()
    addr = liburing.ffi.new('struct sockaddr *')
    addrlen = liburing.ffi.new('socklen_t *', liburing.ffi.sizeof(addr))

    try:
        # initialization
        assert liburing.io_uring_queue_init(32, ring, 0) == 0

        # accept
        sqe = liburing.io_uring_get_sqe(ring)
        liburing.io_uring_prep_accept(sqe, fd, addr, addrlen, 0)
        assert liburing.io_uring_submit(ring) == 1

        print()
        while True:
            try:
                cqes = liburing.io_uring_cqes()
                assert liburing.io_uring_peek_cqe(ring, cqes) == 0

            except BlockingIOError:
                print('waiting')
            else:
                cqe = cqes[0]

                print('res:', cqe.res)
                print('user_data:', cqe.user_data)

                # Error: OSError: [Errno 22] Invalid argument
                assert cqe.res >= 0

                liburing.io_uring_cqe_seen(ring, cqe)
                print('task done')
                break
    finally:
        server.close()
        liburing.io_uring_queue_exit(ring)
