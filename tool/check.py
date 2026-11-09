#!/usr/bin/env python3
'''Runs every Liburing check and stops at the first failure.

    tool/check.py [-- PYTEST_ARGS...]

Steps
    - `zig fmt`, Zig line width, ruff (lint + format), `c.io_uring_submit*` only through `Ring.submitPtr`.
    - `tool/setu_build.py`, `tool/setu_doc.py` and `doc/setu-guide.md` against the pinned Setu.
    - `zig build develop` (the one stable-ABI `liburing/__init__.so`), then with each interpreter (3.15t, 3.15, 3.14t,
      3.14) Setu's symbol check (`zig build check-symbol`) and pytest, the same with the pre-release 3.16t / 3.16
      when installed (`/opt/python/3.16{t,}-dev`).
    - With kcov installed, line coverage over the four (into `doc/coverage.json`; fails below 100% for Liburing's own
      code).
    - The docstring examples (`setu_doc.py check`), then `mypy --strict` (as 3.14 and 3.15) + `stubtest` on the
      `liburing` package.

Environment
    Interpreters: PY_FT=... / PY_GIL=... (3.15), PY314_FT=... / PY314_GIL=..., PY316_FT=... / PY316_GIL=...;
    compiler: ZIG=...; ruff: RUFF=... (default: `ruff` on PATH, else `$PY_FT -m ruff`).
'''

import json
import os
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

PY_FT = os.environ.get('PY_FT', '/opt/python/3.15t/bin/python3')
PY_GIL = os.environ.get('PY_GIL', '/opt/python/3.15/bin/python3')
PY314_FT = os.environ.get('PY314_FT', '/opt/python/3.14t/bin/python3')
PY314_GIL = os.environ.get('PY314_GIL', '/opt/python/3.14/bin/python3')
PY316_FT = os.environ.get('PY316_FT', '/opt/python/3.16t-dev/bin/python3')
PY316_GIL = os.environ.get('PY316_GIL', '/opt/python/3.16-dev/bin/python3')
ZIG = os.environ.get('ZIG', 'zig')


class Failed(Exception):
    '''A check failed: its message is printed, the exit status is 1.'''


def step(title):
    '''Prints a step's bold header.'''
    print(f'\n\033[1m== {title}\033[0m', flush=True)


def run(*cmd, cwd=None, env=None):
    '''Runs `cmd` (from the repository root, or `cwd` under it); a non-zero exit raises `CalledProcessError`.'''
    full_env = None if env is None else {**os.environ, **env}
    subprocess.run(cmd, cwd=ROOT / cwd if cwd else ROOT, env=full_env, check=True)


def check_zig_line_width(*paths):
    '''ruff holds Python to `line-length = 120`; `zig fmt` never wraps a long line (only a trailing comma splits a
    call), so a Zig line over 120 characters fails here.'''
    bad = []
    for arg in paths:
        path = ROOT / arg
        for file in sorted(path.rglob('*.zig')) if path.is_dir() else [path]:
            for number, line in enumerate(file.read_text(encoding='utf-8').splitlines(), 1):
                if len(line) > 120:
                    bad.append(f'{file.relative_to(ROOT)}:{number}: {len(line)} characters')
    print('\n'.join(bad) or 'ok')
    if bad:
        raise Failed('Zig line width')


def check_submit_ptr():
    '''`submitPtr` makes the in-flight table's entries and runs the skip checks: a submit with any other pointer
    (`checkedPtr`, `_ring`) would send SQEs whose `user_data` is no table index.'''
    fn = re.compile(r'^\s*(pub )?(inline )?fn ')
    bad = []
    for file in sorted((ROOT / 'src/liburing').glob('*.zig')):
        name, body = '', []
        for line in [*file.read_text(encoding='utf-8').splitlines(), None]:
            if line is None or fn.match(line):
                text = '\n'.join(body)
                if 'c.io_uring_submit' in text and ('submitPtr()' not in text or 'checkedPtr()' in text):
                    bad.append(f'{file.relative_to(ROOT)}: {name}')
                if line is None:
                    break
                name, body = line, []
            body.append(line)
    print('\n'.join(bad) or 'ok')
    if bad:
        raise Failed('c.io_uring_submit* outside Ring.submitPtr')


def check_own_coverage(path):
    '''Liburing's own lines in kcov's merged `path` are all covered (Setu's lines count on the page, not here).'''
    files = json.loads((ROOT / path).read_text(encoding='utf-8'))['files']
    own = {name: f for name, f in files.items() if not name.startswith('setu/')}
    covered, lines = sum(f['covered'] for f in own.values()), sum(f['lines'] for f in own.values())
    for name, f in sorted(own.items()):
        if f['covered'] < f['lines']:
            print(f'{name}: {f["covered"]}/{f["lines"]} lines')
    print(f'Liburing: {covered}/{lines} lines')
    if covered != lines:
        raise Failed("coverage: Liburing's own lines below 100%")


def ruff_command():
    '''`$RUFF`, else `ruff` on PATH, else `$PY_FT -m ruff`; None without any.'''
    if os.environ.get('RUFF'):
        return [os.environ['RUFF']]
    if shutil.which('ruff'):
        return ['ruff']
    if subprocess.run([PY_FT, '-c', 'import ruff'], check=False, capture_output=True).returncode == 0:
        return [PY_FT, '-m', 'ruff']
    return None


def has_mypy(py):
    '''Whether `py` can import mypy.'''
    return subprocess.run([py, '-c', 'import mypy'], check=False, capture_output=True).returncode == 0


def main(argv):
    '''Runs every step; `argv` after an optional `--` goes to pytest.'''
    pytest_args = argv[1:] if argv[:1] == ['--'] else argv

    step('zig fmt')
    run(ZIG, 'fmt', '--check', 'src', 'tool', 'example', 'build.zig', 'build.zig.zon')

    step('Zig lines are at most 120 characters')
    check_zig_line_width('src', 'tool', 'example', 'build.zig')

    step('ruff check + ruff format --check')
    ruff = ruff_command()
    if ruff:
        run(*ruff, 'check', '.')
        run(*ruff, 'format', '--check', '.')
    else:
        print(f'skipped: no ruff (RUFF=..., on PATH, or installed for {PY_FT})')

    step('c.io_uring_submit* only through Ring.submitPtr')
    check_submit_ptr()

    step("tool/setu_build.py is the pinned Setu's copy")
    run(ZIG, 'build', 'setu-build-check')

    step("tool/setu_doc.py is the pinned Setu's copy")
    run(ZIG, 'build', 'setu-doc-check')

    step("doc/setu-guide.md is the pinned Setu's copy")
    run(ZIG, 'build', 'setu-guide-check')

    step('zig build develop')
    run(ZIG, 'build', 'develop')  # src/liburing/__init__.so: one binary for every interpreter below

    pythons = [(py, '') for py in (PY_FT, PY_GIL, PY314_FT, PY314_GIL)]
    pythons += [(py, ' (pre-release)') for py in (PY316_FT, PY316_GIL)]  # only where installed (not CI)
    for py, note in pythons:
        step(f'{py}{note}')
        if note and not os.access(py, os.X_OK):
            print('skipped: not installed')
            continue
        run(ZIG, 'build', 'check-symbol', f'-Dpython={py}')  # exported by py, and in abi3t (3.15+)
        run(py, '-m', 'pytest', *pytest_args)

    step("coverage: Liburing's own Zig code at 100% (zig build coverage, kcov)")
    # Every supported interpreter, merged, into doc/coverage.json (the committed snapshot the docs' Coverage page
    # reads) and this version's line of doc/coverage-history.json (its history chart).
    if shutil.which('kcov'):
        others = [arg for py in (PY_GIL, PY314_FT, PY314_GIL) for arg in ('--python', py)]
        run(ZIG, 'build', 'coverage', f'-Dpython={PY_FT}', '--', '--json', 'doc/coverage.json', *others, *pytest_args)
        check_own_coverage('doc/coverage.json')
    else:
        print('skipped: no kcov')

    step(f'docstring examples ({PY_FT} tool/setu_doc.py check)')
    run(PY_FT, 'tool/setu_doc.py', 'check')  # every `>>>` example in a docstring still prints what it shows

    step(f'mypy --strict + stubtest ({PY_FT})')
    if has_mypy(PY_FT):
        run(PY_FT, '-m', 'mypy', '--strict', '--python-version', '3.14', '-p', 'liburing', cwd='src')
        run(PY_FT, '-m', 'mypy', '--strict', '-p', 'liburing', cwd='src')
        run(PY_FT, '-m', 'mypy.stubtest', 'liburing', cwd='src', env={'PYTHONPATH': '.'})
    else:
        print(f'skipped: mypy is not installed for {PY_FT}')

    step('all checks passed')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except subprocess.CalledProcessError as e:
        print(f'\nfailed ({e.returncode}): {" ".join(map(str, e.cmd))}', file=sys.stderr)
        sys.exit(e.returncode or 1)
    except Failed as e:
        print(f'\nfailed: {e}', file=sys.stderr)
        sys.exit(1)
