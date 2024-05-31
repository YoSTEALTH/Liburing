from liburing import io_uring_op, io_uring_get_probe, io_uring_opcode_supported, io_uring_free_probe


def probe() -> dict:
    ''' Probe your system to find out which `io_uring` operations are available.

        Example
            >>> probe()
            {'IORING_OP_NOP': True, ...}

            # or

            >>> for op, supported in probe().items():
            ...     op, supported
            IORING_OP_NOP True
            ...
    '''
    r = {}
    p = io_uring_get_probe()
    try:
        for i in io_uring_op:
            if i.name != 'IORING_OP_LAST':
                r[i.name] = io_uring_opcode_supported(p, i)
    finally:
        io_uring_free_probe(p)
    return r
