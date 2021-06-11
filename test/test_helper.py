from liburing import io_uring_submit, io_uring_wait_cqe, io_uring_wait_cqes, trap_error, io_uring_cqe_seen


__all__ = 'submit_wait_result'


def submit_wait_result(ring, cqes, no=1):
    io_uring_submit(ring)
    if no == 1:
        io_uring_wait_cqe(ring, cqes)
        cqe = cqes[0]
        result = trap_error(cqe.res)
        io_uring_cqe_seen(ring, cqe)
        return result  # type: int
    else:  # multiple
        r = []
        for i in range(no, 0, -1):
            io_uring_wait_cqes(ring, cqes, i)
            cqe = cqes[0]
            result = trap_error(cqe.res)
            io_uring_cqe_seen(ring, cqe)
            r.append(result)
        return r  # type: list[int]
