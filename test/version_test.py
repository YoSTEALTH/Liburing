from version import parse_version


def test_parse_line():
    assert parse_version(b"__version__ = '2020.2.3'\n") == '2020.2.3'
    assert parse_version(b'__version__= "2020.2.3"\n') == '2020.2.3'
    assert parse_version(b"__version__ = '1.2.3'\n") == '1.2.3'
    assert parse_version(b"__version__ = None\n") == ''
    assert parse_version(b"__version__ = ''\n") == ''
    assert parse_version(None) == ''
    assert parse_version(b"") == ''
