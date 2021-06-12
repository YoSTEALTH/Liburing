from liburing import skip_it


def test_skip_it():
    assert not skip_it('5.1')
    assert skip_it('10-10.0', 'Windows')
    assert skip_it('15.3.0', 'Darwin')
    assert not skip_it('5.11', 'linux')
    assert not skip_it('5.11', 'LINUx')
    assert skip_it('5.10004', 'LINUx')
