from liburing import skip_os


def test_skip_os():
    assert not skip_os('5.1')
    assert skip_os('10-10.0', 'Windows')
    assert skip_os('15.3.0', 'Darwin')
    assert not skip_os('5.11', 'linux')
    assert not skip_os('5.11', 'LINUx')
    assert skip_os('5.10004', 'LINUx')
