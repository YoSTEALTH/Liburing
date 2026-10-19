# Baseline (phase 1)

2026-10-19 · branch `zig-0.17-setu`

## What was run, and why it is a proxy

The plan asks for the current PyOZ build on Zig 0.15.2 and Python <= 3.14. On this machine:

- **Zig 0.15.2 is not installed** (only `/usr/bin/zig` 0.17.0), so `python -m pyoz build` could not be run.
- **Python 3.14.8** (`/usr/bin/python3.14`) has neither `pytest` nor `pyoz` installed.

Nothing was installed system-wide. Instead the baseline uses the prebuilt PyOZ wheel already in `dist/`:

| | |
| --- | --- |
| Wheel | `dist/liburing-2026.4.1-cp38-abi3-manylinux_2_17_x86_64.whl` (PyOZ 0.12.2, built 2026-04-04) |
| Python | 3.15.0 (`/opt/python/3.15/bin/python3`, GIL build), wheel installed into a throwaway venv with `--no-index` |
| pytest | 9.1.1 |
| Kernel | 7.2.11-1-garuda, x86_64 |
| Tests | working tree of `test/` at the branch point (includes the uncommitted `const_test.py` changes and the new `_get_cqe_test.py`, `_macro_test.py`, `getaddinfo_test.py`, `getnameinfo_test.py`) |

Caveat: the wheel predates the uncommitted `src/liburing/socket.zig` changes, so it is not exactly the
working-tree source. Each test id was run in its own process so a segfault could not hide later results.

## Summary

62 collected: **48 passed, 11 skipped, 3 crashed (SIGSEGV)**, 0 failed.

The 3 crashes all iterate a PyOZ iterator (`for fd in ids` over `FileIndex`, and the `iter_test.py` CQE
iteration). The C stack ends in `_PyForIter_VirtualIteratorNext`, i.e. the PyOZ abi3 iterator breaks on 3.15's
new for-loop path. Not verified on <= 3.14 here; they must pass after the Setu port.

All 11 skips are `pytest.mark.skip` in the tests themselves (TODO / BUG / "not going to implemented"), not
environment skips.

## Per-test results

```
SKIPPED test/const_test.py::test_enum
PASSED test/const_test.py::test_io_uring_defines
PASSED test/const_test.py::test_type_define
PASSED test/error_test.py::test_trap_error
PASSED test/file/file_test.py::test_files_read_write
PASSED test/file/file_test.py::test_readv_writev
PASSED test/file/file_test.py::test_rwf_nowait_flag
PASSED test/file/open_close_test.py::test_close_error
PASSED test/file/open_close_test.py::test_openat2_close
PASSED test/file/open_close_test.py::test_openat2_close_direct
PASSED test/file/open_close_test.py::test_openat2_close_direct_auto_file_index_alloc
PASSED test/file/open_close_test.py::test_open_close
PASSED test/file/open_close_test.py::test_open_close_direct
PASSED test/file/open_how_test.py::test_open_how
CRASH(rc=139) test/file/register_test.py::test_register_files
PASSED test/file/register_test.py::test_register_files_update
PASSED test/futex_test.py::test_futex_6_7
PASSED test/futex_test.py::test_futex_define
PASSED test/futex_test.py::test_futex_state
PASSED test/futex_test.py::test_futex_waitv_class
PASSED test/futex_test.py::test_futex_wake_zero
PASSED test/futex_test.py::test_multi_wake
PASSED test/futex_test.py::test_multi_wake_waitv
PASSED test/helper_test.py::test_file_index
PASSED test/helper_test.py::test_put_sqe
PASSED test/helper_test.py::test_timespec
PASSED test/iovec_test.py::test_iovec
PASSED test/os/splice_test.py::test_clone_file_using_splice
PASSED test/os/unlink_test.py::test_unlink
PASSED test/os/unlink_test.py::test_unlinkat_error
PASSED test/probe_test.py::test_probe
SKIPPED test/probe_test.py::test_probe_register
PASSED test/probe_test.py::test_probe_ring
SKIPPED test/queue/_get_cqe_test.py::test_for_each
SKIPPED test/queue/_get_cqe_test.py::test_peek_batch
SKIPPED test/queue/_get_cqe_test.py::test_wait_cqes
PASSED test/queue/init_exit_test.py::test_init_max
PASSED test/queue/init_exit_test.py::test_io_uring_init_exit
PASSED test/queue/init_exit_test.py::test_io_uring_submit_and_wait
PASSED test/queue/init_exit_test.py::test_max_entries_plus
PASSED test/queue/init_exit_test.py::test_setup_iopoll_sqpoll
CRASH(rc=139) test/queue/iter_test.py::test_iter_advance
CRASH(rc=139) test/queue/iter_test.py::test_iter_seen
SKIPPED test/queue/_macro_test.py::test_io_uring_cqe_index
SKIPPED test/queue/_macro_test.py::test_io_uring_cqe_shift
SKIPPED test/queue/_macro_test.py::test_io_uring_for_each_cqe
PASSED test/queue/sqe_cqe_test.py::test_Cqe
PASSED test/queue/sqe_cqe_test.py::test_Sqe
PASSED test/socket/cmd_sock_test.py::test_cmd_sock
PASSED test/socket/cmd_sock_test.py::test_setsockopt_getsockopt
SKIPPED test/socket/getaddinfo_test.py::test_getaddrinfo
SKIPPED test/socket/getnameinfo_test.py::test_getnameinfo
PASSED test/socket/getsockname_test.py::test_getsockname
PASSED test/socket/socket_connect_test.py::test_Sockaddr
PASSED test/socket/socket_connect_test.py::test_sockadr_un_connect
PASSED test/socket/socket_define_test.py::test_socket_define
SKIPPED test/socket/socket_define_test.py::test_socket_extra_define
PASSED test/statx_test.py::test_io_uring_prep_statx
PASSED test/statx_test.py::test_statx_define
PASSED test/version_test.py::test_liburing_version
PASSED test/version_test.py::test_linux_version
PASSED test/version_test.py::test_set_linux_version_define
```
