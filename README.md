# Liburing (Work in Process...)

Liburing is Python + Zig wrapper around C Liburing, which is a helper to setup and tear-down io_uring instances.

- Fast & scalable asynchronous I/O (storage, networking, ...) interface.
- io_uring reduces number of syscalls overhead & context switches, thus improving speed.

Good(old) documentation [Lord of the io_uring](https://unixism.net/loti/)

### Requires
 - Linux 6.11+
 - Python 3.10+

### Includes (battery)
 - C liburing 2.15+

### Install, update & uninstall (Alpha)

Use [pip](https://pip.pypa.io/en/stable/getting-started/) to install, upgrade & uninstall Python wrapper

```bash
python3 -m pip install liburing             # install

python3 -m pip install --upgrade liburing   # upgrade

python3 -m pip uninstall liburing           # uninstall
```

### Install directly from GitHub

```bash
python3 -m pip install --upgrade git+https://github.com/YoSTEALTH/Liburing
```

### To find out all the class, functions and definitions

```python
import liburing

# To see all the importable names
print(dir(liburing))

# To see all the help docs
help(liburing)
```

### Find out which `io_uring` operations is supported by the kernel

```python
# example/probe.py
import liburing

for k, v in liburing.probe().items():
    print(k, v)

```

### Simple File Example

```python
# example/open_write_read_close.py
from liburing import O_CREAT, O_RDWR, Ring, Cqe, io_uring_get_sqe, \
                     io_uring_prep_open, io_uring_prep_write, io_uring_prep_read, \
                     io_uring_prep_close, io_uring_submit, io_uring_wait_cqe, \
                     io_uring_cqe_seen, io_uring_queue_init, io_uring_queue_exit, trap_error


def open(ring, cqe, path, flags):
    sqe = io_uring_get_sqe(ring)  # sqe(submission queue entry)
    io_uring_prep_open(sqe, path, flags)
    # set submit entry identifier as `1` which is returned back in `cqe.user_data`
    # so you can keep track of submit/completed entries.
    sqe.user_data = 1
    return _submit_and_wait(ring, cqe)  # returns fd


def write(ring, cqe, fd, data):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_write(sqe, fd, data)
    sqe.user_data = 2
    return _submit_and_wait(ring, cqe)  # returns length(s) of bytes written


def read(ring, cqe, fd, length):
    buffer = bytearray(length)  # where read data will be stored
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_read(sqe, fd, buffer)
    sqe.user_data = 3
    _submit_and_wait(ring, cqe)  # get actual length of file read.
    return buffer


def close(ring, cqe, fd):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    sqe.user_data = 4
    _submit_and_wait(ring, cqe)  # no error means success!


def _submit_and_wait(ring, cqe):
    io_uring_submit(ring)  # submit entry
    io_uring_wait_cqe(ring, cqe)  # wait for entry to finish
    entry = cqe[0]
    result = trap_error(entry.res)  # auto raise appropriate exception if failed
    # note `entry.res` returns results, if ``< 0`` its an error, if ``>= 0`` its the value

    # done with current entry so clear it from completion queue.
    io_uring_cqe_seen(ring, entry)
    return result  # type: int


def main():
    ring = Ring()
    cqe = Cqe()  # completion queue entry
    try:
        io_uring_queue_init(8, ring)

        fd = open(ring, cqe, '/tmp/liburing-test-file.txt', O_CREAT | O_RDWR)
        print('fd:', fd)

        length = write(ring, cqe, fd, b'hi... bye!')
        print('wrote:', length)

        content = read(ring, cqe, fd, length)
        print('read:', content)

        close(ring, cqe, fd)
        print('closed.')
    finally:
        io_uring_queue_exit(ring)


if __name__ == '__main__':
    main()

```

### Note
 - This project has been moved to using Zig as back-end, thus leading to breaking changes from previous release.
 - Try using latest Linux if possible to enable all `io_uring` features.

### Check Out
<!-- - [Shakti](https://github.com/YoSTEALTH/Shakti) -->
- [PyOZ](https://pyoz.dev/)

### License
Free, Public Domain (CC0). [Read more](https://github.com/YoSTEALTH/Liburing/blob/dev/LICENSE.txt)