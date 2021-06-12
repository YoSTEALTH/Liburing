from os import O_CREAT, O_RDONLY, seteuid, setegid, getuid, unlink
from os.path import join, exists
from pytest import raises, mark
from liburing import AT_FDCWD, io_uring_queue_init, io_uring_queue_exit, io_uring, io_uring_cqes, \
                     io_uring_register_personality, io_uring_get_sqe, io_uring_prep_openat, \
                     io_uring_prep_close, io_uring_unregister_personality, skip_it
from test_helper import submit_wait_result


version = '5.6'


@mark.skipif(getuid() != 0, reason='need to be "root" user')
@mark.skipif(skip_it(version), reason=f'Requires Linux {version}+')
def test_personality(tmpdir):
    # note: `sqe.personality` has limited use-case like its restricts to opening `fd`
    #       but not for read, write, close, ...

    ring = io_uring()
    cqes = io_uring_cqes()
    file_path = join(tmpdir, 'test_personality_root_file.txt').encode()
    try:
        assert io_uring_queue_init(2, ring, 0) == 0

        # create & open file only root can access!
        sqe = io_uring_get_sqe(ring)
        io_uring_prep_openat(sqe, AT_FDCWD, file_path, O_CREAT, 0o700)
        fd = submit_wait_result(ring, cqes)
        close_file(ring, cqes, fd)

        root_cred_id = io_uring_register_personality(ring)
        assert root_cred_id == 1

        # normal "user"
        setegid(1000)
        seteuid(1000)

        user_cred_id = io_uring_register_personality(ring)
        assert user_cred_id == 2

        # try to open root file as normal user.
        with raises(PermissionError):
            open_file(ring, cqes, file_path, None)

        # bad personality
        with raises(OSError):  # Invalid argument
            open_file(ring, cqes, file_path, 2)

        # what about default `0` for personality
        with raises(PermissionError):
            open_file(ring, cqes, file_path, 0)

        # try again to open file with root credential
        fd = open_file(ring, cqes, file_path, root_cred_id)
        close_file(ring, cqes, fd)

        # "root" again
        setegid(0)
        seteuid(0)

        # try again to open file with root credential
        fd = open_file(ring, cqes, file_path, root_cred_id)
        close_file(ring, cqes, fd)

        # try again to open file with no credential
        fd = open_file(ring, cqes, file_path, None)
        close_file(ring, cqes, fd)

        # try again to open file with "user" credential
        with raises(PermissionError):
            open_file(ring, cqes, file_path, user_cred_id)

        # "user" again
        setegid(1000)
        seteuid(1000)

        # try to unregister "root" personality
        assert io_uring_unregister_personality(ring, root_cred_id) == 0

        # try to unregister "user" personality
        assert io_uring_unregister_personality(ring, user_cred_id) == 0

        # try to open file with unregistered old "root" credential
        with raises(OSError):  # Invalid argument
            open_file(ring, cqes, file_path, root_cred_id)

    finally:
        # make sure its "root" again to allow proper cleanup
        seteuid(0)
        setegid(0)

        if exists(file_path):
            unlink(file_path)

        io_uring_queue_exit(ring)


def open_file(ring, cqes, file_path, cred_id):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_openat(sqe, AT_FDCWD, file_path, O_RDONLY, 0)
    if cred_id is not None:
        sqe.personality = cred_id
    return submit_wait_result(ring, cqes)  # fd


def close_file(ring, cqes, fd):
    sqe = io_uring_get_sqe(ring)
    io_uring_prep_close(sqe, fd)
    assert submit_wait_result(ring, cqes) == 0
