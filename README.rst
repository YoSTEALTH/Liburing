|test-status| |downloads|

Liburing
========

Liburing is Python + Cython wrapper around `C Liburing`_, which is a helper to setup and tear-down io_uring instances.

* Fast & scalable asynchronous I/O (storage, networking, ...) interface.
* ``io_uring`` reduces number of syscalls overhead & context switches, thus improving speed.
* ...

Good(old) documentation `Lord of the io_uring`_

Check out `Shakti`_. It uses ``liburing`` and provides an easy to use Python ``async`` ``await`` Interface.


Requires
--------

    - Linux 6.11+
    - Python 3.9+


Includes (battery)
------------------

    - C liburing 2.9+


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
    help(liburing)        # to see all the help docs (this will load all the modules.)


Find out which ``io_uring`` operations is supported by the kernel:

.. code-block:: python
    
    # example/probe.py
    import liburing

    probe = liburing.probe()
    print(probe)


Simple File Example
-------------------

.. code-block:: python

    # example/open_write_read_close.py
    from liburing import O_CREAT, O_RDWR, AT_FDCWD, iovec, io_uring, io_uring_get_sqe, \
                         io_uring_prep_openat, io_uring_prep_write, io_uring_prep_read, \
                         io_uring_prep_close, io_uring_submit, io_uring_wait_cqe, \
                         io_uring_cqe_seen, io_uring_cqe, io_uring_queue_init, io_uring_queue_exit, \
                         io_uring_sqe_set_data64, trap_error


    def open(ring, cqe, path, flags, mode=0o660, dir_fd=AT_FDCWD):
        _path = path if isinstance(path, bytes) else str(path).encode()
        # if `path` is relative and `dir_fd` is `AT_FDCWD`, then `path` is relative
        # to current working directory. Also `_path` must be in bytes

        sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
        io_uring_prep_openat(sqe, _path, flags, mode, dir_fd)
        # set submit entry identifier as `1` which is returned back in `cqe.user_data`
        # so you can keep track of submit/completed entries.
        io_uring_sqe_set_data64(sqe, 1)
        return _submit_and_wait(ring, cqe)  # returns fd


    def write(ring, cqe, fd, data, offset=0):
        iov = iovec(data)  # or iovec([bytearray(data)])
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_write(sqe, fd, iov.iov_base, iov.iov_len, offset)
        io_uring_sqe_set_data64(sqe, 2)
        return _submit_and_wait(ring, cqe)  # returns length(s) of bytes written


    def read(ring, cqe, fd, length, offset=0):
        iov = iovec(bytearray(length))  # or [bytearray(length)]
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_read(sqe, fd, iov.iov_base, iov.iov_len, offset)
        io_uring_sqe_set_data64(sqe, 3)
        _submit_and_wait(ring, cqe)  # get actual length of file read.
        return iov.iov_base


    def close(ring, cqe, fd):
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_close(sqe, fd)
        io_uring_sqe_set_data64(sqe, 4)
        _submit_and_wait(ring, cqe)  # no error means success!


    def _submit_and_wait(ring, cqe):
        io_uring_submit(ring)  # submit entry
        io_uring_wait_cqe(ring, cqe)  # wait for entry to finish
        result = trap_error(cqe.res)  # auto raise appropriate exception if failed
        # note `cqe.res` returns results, if ``< 0`` its an error, if ``>= 0`` its the value

        # done with current entry so clear it from completion queue.
        io_uring_cqe_seen(ring, cqe)
        return result  # type: int


    def main():
        ring = io_uring()
        cqe = io_uring_cqe()  # completion queue entry
        try:
            io_uring_queue_init(32, ring, 0)

            fd = open(ring, cqe, '/tmp/liburing-test-file.txt', O_CREAT | O_RDWR)
            print('fd:', fd)

            length = write(ring, cqe, fd, b'hello world')
            print('wrote:', length)

            content = read(ring, cqe, fd, length)
            print('read:', content)

            close(ring, cqe, fd)
            print('closed.')
        finally:
            io_uring_queue_exit(ring)


    if __name__ == '__main__':
        main()


Note
----
    - Try not to use ``from liburing import *`` this will load all the modules at once, unless that's what you want!


Cython Note
-----------
    - You can ``cimport`` ``liburing`` directly into your project if you are planning on compiling your project as well.
    - There is also ``src/liburing/lib`` directory with raw ``.pxd`` header files.
    - All raw ``C`` wrapped function, enum, struct, defines starts with ``__``, not including anything that's ``ctypedef``. This is to prevent naming confusion between whats ``C`` and ``Cython`` side.
    - ``liburing`` must be included in both ``build-system.requires`` and ``project.dependencies`` in ``pyproject.toml`` to compile and use properly.
    - Check out `Shakti`_ to see how to include ``liburing`` using ``cython``.


TODO
----
    - Stable Release (currently still in alpha)
    - Linux 6.1 Backwards compatibility.


License
-------
Free, Public Domain (CC0). `Read more`_

.. _pip: https://pip.pypa.io/en/stable/getting-started/
.. _Read more: https://github.com/YoSTEALTH/Liburing/blob/master/LICENSE.txt
.. _C Liburing: https://github.com/axboe/liburing
.. _Lord of the io_uring: https://unixism.net/loti/
.. _Shakti: https://github.com/YoSTEALTH/Shakti
.. |test-status| image:: https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml/badge.svg?branch=master
    :target: https://github.com/YoSTEALTH/Liburing/actions/workflows/test.yml
    :alt: Test status
.. |downloads| image:: https://img.shields.io/pypi/dm/liburing
   :alt: PyPI - Downloads
