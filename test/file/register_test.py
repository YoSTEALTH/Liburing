import os
import liburing


def test_register_files(tmp_dir, ring):
    fds = liburing.Fds(
        [-1, -1, -1, os.open(tmp_dir / "1.txt", liburing.O_CREAT), os.open(tmp_dir / "2.txt", liburing.O_CREAT)]
    )
    try:
        assert liburing.io_uring_register_files(ring, fds) == 0
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        for fd in fds:
            if fd != -1:
                os.close(fd)


def test_register_files_update(tmp_dir, ring):
    fds = liburing.Fds(
        [-1, -1, -1, os.open(tmp_dir / "1.txt", liburing.O_CREAT), os.open(tmp_dir / "2.txt", liburing.O_CREAT)]
    )
    assert liburing.io_uring_register_files(ring, fds) == 0

    # close last fd & update all.
    current_fds = list(fds)
    os.close(current_fds[-1])
    current_fds[-1] = -1
    fds.update(current_fds)
    assert liburing.io_uring_register_files_update(ring, fds, 0) == 5

    # close second last & update last two
    update_fds = list(fds)
    os.close(update_fds[-2])
    new_fds = liburing.Fds([-1, -1])
    assert liburing.io_uring_register_files_update(ring, new_fds, 3) == 2

    assert liburing.io_uring_unregister_files(ring) == 0
