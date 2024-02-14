|test-status| |downloads|

Liburing (Work in progress ... )
========

This is a Python + Cython wrapper around Liburing C library, which is a helper to setup and tear-down `io_uring` instances.


Original Liburing C library can be found `here`_

Read how to use `Liburing`_ (PDF)

Good documentation `Lord of the io_uring`_


Requires
--------

    - Linux 5.1+ (5.12+ recommended)
    - Python 3.8+


Includes
--------

    - liburing 2.5+


Install, update & uninstall (Alpha)
-----------------------------------

Use `pip`_ to install, upgrade & uninstall Python wrapper:

.. code-block:: text

    python3 -m pip install liburing             # install

    python3 -m pip install --upgrade liburing   # upgrade

    python3 -m pip uninstall liburing           # uninstall


Install directly from GitHub:

.. code-block:: text

    python3 -m pip install --upgrade git+https://github.com/YoSTEALTH/Liburing


To find out all the class, functions and definitions:

.. code-block:: python
    
    import liburing

    print(dir(liburing))  # to see all the importable names (this will not load all the modules)
    help(liburing)  # to see all the help docs (this will load all the modules.)


Find out which `io_uring` operations is supported by the kernel:

.. code-block:: python
    
    import liburing

    probe = liburing.probe()
    print(probe)


Simple File Example
-------------------

.. code-block:: python

    from liburing import O_CREAT, O_RDWR, AT_FDCWD, iovec, io_uring, io_uring_get_sqe, \
                         io_uring_prep_openat, io_uring_prep_write, io_uring_prep_read, \
                         io_uring_prep_close, io_uring_submit, io_uring_wait_cqe, \
                         io_uring_cqe_seen, io_uring_cqe, io_uring_queue_init, io_uring_queue_exit, \
                         trap_error


    def open(ring, cqes, path, flags, mode=0o660, dir_fd=AT_FDCWD):
        _path = path if isinstance(path, bytes) else str(path).encode()
        # if `path` is relative and `dir_fd` is `AT_FDCWD`, then `path` is relative
        # to current working directory. Also `_path` must be in bytes

        sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
        io_uring_prep_openat(sqe, dir_fd, _path, flags, mode)
        return _submit_and_wait(ring, cqes)  # returns fd


    def write(ring, cqes, fd, data, offset=0):
        iov = iovec(data)  # or iovec([bytearray(data)])
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, iov.iov_base, iov.iov_len, offset)
        return _submit_and_wait(ring, cqes)  # returns length(s) of bytes written


    def read(ring, cqes, fd, length, offset=0):
        iov = iovec(bytearray(length))  # or [bytearray(length)]
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, iov.iov_base, iov.iov_len, offset)
        _submit_and_wait(ring, cqes)  # get actual length of file read.
        return iov.iov_base


    def close(ring, cqes, fd):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        _submit_and_wait(ring, cqes)  # no error means success!


    def _submit_and_wait(ring, cqes):
        io_uring_submit(ring)  # submit entry
        io_uring_wait_cqe(ring, cqes)  # wait for entry to finish
        result = trap_error(cqes.res)  # auto raise appropriate exception if failed
        # note `cqe.res` returns results, if ``< 0`` its an error, if ``>= 0`` its the value

        # done with current entry so clear it from completion queue.
        io_uring_cqe_seen(ring, cqes)
        return result  # type: int


    def main():
        ring = io_uring()
        cqes = io_uring_cqe()
        try:
            io_uring_queue_init(8, ring, 0)

            fd = open(ring, cqes, '/tmp/liburing-test-file.txt', O_CREAT | O_RDWR)
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



Note
----
    - try not to use ``from liburing import *`` this will load all the modules at once, unless thats what you want!


License
-------
Free, Public Domain (CC0). `Read more`_


TODO
----

    - Move everything to using Cython
    

.. _pip: https://pip.pypa.io/en/stable/getting-started/
.. _Read more: https://github.com/YoSTEALTH/Liburing/blob/master/LICENSE.txt
.. _here: https://github.com/axboe/liburing
.. _Liburing: https://kernel.dk/io_uring.pdf
.. _Lord of the io_uring: https://unixism.net/loti/
.. |test-status| image:: https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml/badge.svg?branch=master&event=push
    :target: https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml
    :alt: Test status
.. |downloads| image:: https://img.shields.io/pypi/dm/liburing
   :alt: PyPI - Downloads
