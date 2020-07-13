Liburing
========

This is a Python + CFFI wrapper around Liburing C library, which is a helper to setup and tear-down ``io_uring`` instances.

Read how to use `Liburing`_ (pdf)

Another good documentation `Lord of the io_uring`_


Requires
--------

    - Linux 5.5+ (5.7+ recommended)
    - Python 3.6+


Includes
--------

    - liburing 0.7.0


Install, update & uninstall (Alpha)
-----------------------------------

Use `pip`_ to install, upgrade & uninstall Python wrapper:

.. code-block:: text

    pip install liburing

    pip install --upgrade liburing

    pip uninstall liburing

Install directly from GitHub:

.. code-block:: text

    pip install --upgrade git+https://github.com/YoSTEALTH/Liburing


To find out all the functions and definitions:

.. code-block:: text
    
    import liburing

    help(liburing)


Simple File Example
-------------------

.. code-block:: python

    import os
    import os.path
    from liburing import *


    def open(ring, cqes, path, flags, mode=0o660, dir_fd=-1):
        # file path must be absolute path and in bytes.
        _path = os.path.abspath(path).encode()

        sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
        io_uring_prep_openat(sqe, dir_fd, _path, flags, mode)
        return _submit_and_wait(ring, cqes)  # returns fd


    def write(ring, cqes, fd, data, offset=0):
        buffer = bytearray(data)
        iov = iovec(buffer)

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, iov[0].iov_base, iov[0].iov_len, offset)
        return _submit_and_wait(ring, cqes)  # returns length(s) of bytes written


    def read(ring, cqes, fd, length, offset=0):
        buffer = bytearray(length)
        iov = iovec(buffer)

        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, iov[0].iov_base, iov[0].iov_len, offset)
        read_length = _submit_and_wait(ring, cqes)  # get actual length of file read.
        return buffer[:read_length]


    def close(ring, cqes, fd):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        _submit_and_wait(ring, cqes)  # no error means success!


    def _submit_and_wait(ring, cqes):
        io_uring_submit(ring)  # submit entry
        io_uring_wait_cqe(ring, cqes)  # wait for entry to finish
        cqe = cqes[0]  # cqe(completion queue entry)
        result = trap_error(cqe.res)  # auto raise appropriate exception if failed
        # note `cqe.res` returns results, if ``< 0`` its an error, if ``>= 0`` its the value

        # done with current entry so clear it from completion queue.
        io_uring_cqe_seen(ring, cqe)
        return result  # type: int


    def main():
        ring = io_uring()
        cqes = io_uring_cqes()
        try:
            io_uring_queue_init(8, ring, 0)

            fd = open(ring, cqes, '/tmp/liburing-test-file.txt', os.O_CREAT | os.O_RDWR)
            print('fd:', fd)

            length = write(ring, cqes, fd, b'hello world')
            print('wrote:', length)

            content = read(ring, cqes, fd, length)
            print('read:', content)

            close(ring, cqes, fd)
            print('closed.')
        finally:
            io_uring_queue_exit(ring)


    if __name__ == '__main__':
        main()


License
-------
Free, Public Domain (CC0). `Read more`_


TODO
----

    - create more test
    - Development Status :: 4 - Beta
    - create example
    - Development Status :: 5 - Production/Stable
    

.. _pip: https://pip.pypa.io/en/stable/quickstart/
.. _Read more: https://github.com/YoSTEALTH/Liburing/blob/master/LICENSE.txt
.. _Liburing: https://kernel.dk/io_uring.pdf
.. _Lord of the io_uring: https://unixism.net/loti/
