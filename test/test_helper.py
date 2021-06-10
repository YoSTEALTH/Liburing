from liburing import io_uring_submit, io_uring_wait_cqe, trap_error, io_uring_cqe_seen


__all__ = 'submit_wait_result'


def submit_wait_result(ring, cqes):
    io_uring_submit(ring)
    io_uring_wait_cqe(ring, cqes)
    cqe = cqes[0]
    result = trap_error(cqe.res)
    io_uring_cqe_seen(ring, cqe)
    return result  # type: int
