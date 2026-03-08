import os
import liburing


def test_register_files(tmp_dir, ring):
    ids = liburing.FileIndex(
        [-1, -1, -1, os.open(tmp_dir / "1.txt", liburing.O_CREAT), os.open(tmp_dir / "2.txt", liburing.O_CREAT)]
    )
    try:
        assert liburing.io_uring_register_files(ring, ids) == 0
        assert liburing.io_uring_unregister_files(ring) == 0
    finally:
        for fd in ids:
            if fd != -1:
                os.close(fd)


def test_register_files_update(tmp_dir, ring):
    ids = liburing.FileIndex(
        [-1, -1, -1, os.open(tmp_dir / "1.txt", liburing.O_CREAT), os.open(tmp_dir / "2.txt", liburing.O_CREAT)]
    )
    assert liburing.io_uring_register_files(ring, ids) == 0

    # close last fd & update all.
    current_fds = list(ids)
    os.close(current_fds[-1])
    current_fds[-1] = -1
    ids.update(current_fds)
    assert liburing.io_uring_register_files_update(ring, ids) == 5

    # close second last & update last two
    update_fds = list(ids)
    os.close(update_fds[-2])
    new_fds = liburing.FileIndex([-1, -1])
    assert liburing.io_uring_register_files_update(ring, new_fds, 3) == 2

    assert liburing.io_uring_unregister_files(ring) == 0
