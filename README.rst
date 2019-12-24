Liburing
========

This is a light-weight python wrapper around liburing library, which is a helper to setup and tear-down io_uring instances.


Install, update & uninstall (Pre-Alpha)
---------------------------------------

Manually install `liburing`_ C library - simple example, use your own way to install.
.. code-block:: text

    cd /tmp

    # Download latest version.
    wget https://git.kernel.dk/cgit/liburing/snapshot/liburing-0.3.tar.bz2

    tar -xjvf liburing-0.3.tar.bz2

    cd liburing-0.3

    ./configure && make

    sudo make install


Use `pip`_ to install Python wrapper:
.. code-block:: text

    pip install liburing

    pip install --upgrade liburing

    pip uninstall liburing


License
-------
Free, No limit what so ever. `Read more`_


TODO
----
    - 'Development Status :: 3 - Alpha',
    - 'Development Status :: 4 - Beta',
    - 'Development Status :: 5 - Production/Stable',
    - Needs testing.
    - Create more test
    - Create example

.. _pip: https://pip.pypa.io/en/stable/quickstart/
.. _Read more: https://github.com/YoSTEALTH/Liburing/blob/master/LICENSE.txt
.. _liburing: https://git.kernel.dk/cgit/liburing/
