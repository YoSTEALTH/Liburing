'''PEP 517 build backend: builds a Zig + Setu extension's wheel with `zig build`, no setuptools.

Kept in Setu (`tools/setu_build.py`) and copied unchanged into each project that uses Setu (Liburing,
Shakti): the package name (`[project].name`, with its sources in `src/<name>/`) and the release
matrix (`[tool.setu_build]`) come from `pyproject.toml`.

Only wheels are built (no sdist is published). `pip install .` / `pip install git+...` call
`build_wheel` for the running interpreter, which needs `zig` 0.17.0 on `PATH` (or `$ZIG`).
Release wheels are built from the command line, for either ABI and any Linux target:

    python3.15t tools/setu_build.py                                   # this interpreter, native CPU
    python3.15t tools/setu_build.py --abi cp315 --target x86_64-linux-gnu.2.28
    python3.15t tools/setu_build.py --abi cp315t --target aarch64-linux-musl -o dist
    python3.15t tools/setu_build.py --all                             # every release wheel -> dist/

Note
    - `--target` is a Zig target: `<arch>-linux-gnu.<glibc>` gives a `manylinux_<glibc>`
      wheel, `<arch>-linux-musl` a `musllinux_1_2` one. Without it the wheel is built for
      this machine's CPU and tagged `linux_<arch>` (fine locally, not for PyPI).
    - The extension links nothing from libpython (symbols resolve at import), so one build
      needs no Python headers or libraries: one interpreter can build every wheel.
    - Metadata comes from `pyproject.toml`; the version from `build.zig.zon`.
    - `zig build` also writes `<name>.pyi` (type stubs); the wheel ships it with `py.typed`.
    - `[tool.setu_build]` in `pyproject.toml`: `abis` and `targets` for `--all` (defaults:
      `RELEASE_ABIS`, `RELEASE_TARGETS`).
'''

import argparse
import base64
import hashlib
import os
import platform
import re
import struct
import subprocess
import sysconfig
import tempfile
import time
import tomllib
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Files in `src/<name>/` that are not shipped as they are: sources, caches, and what
# `zig build develop` copies there (the extension and `<name>.pyi` come from the build).
SKIP = re.compile(r'.*\.(zig|h|so|pyi|py[cod])$|__pycache__')
# `--all`: what a release ships, every ABI x every target (unless `[tool.setu_build]` says otherwise).
RELEASE_ABIS = ('cp315t', 'cp315')
RELEASE_TARGETS = ('x86_64-linux-gnu.2.28', 'aarch64-linux-gnu.2.28', 'x86_64-linux-musl', 'aarch64-linux-musl')
# Zip entries get this date unless `SOURCE_DATE_EPOCH` is set (reproducible wheels).
EPOCH = (1980, 1, 1, 0, 0, 0)


def version():
    '''`.version` from `build.zig.zon` (also `<name>.__version__`).'''
    with open(os.path.join(ROOT, 'build.zig.zon')) as f:
        return re.search(r'\.version\s*=\s*"([^"]+)"', f.read()).group(1)


def pyproject():
    with open(os.path.join(ROOT, 'pyproject.toml'), 'rb') as f:
        return tomllib.load(f)['project']


def release_matrix():
    '''`(abis, targets)` for `--all`: `[tool.setu_build]` in `pyproject.toml`, else the defaults.'''
    with open(os.path.join(ROOT, 'pyproject.toml'), 'rb') as f:
        settings = tomllib.load(f).get('tool', {}).get('setu_build', {})
    return tuple(settings.get('abis', RELEASE_ABIS)), tuple(settings.get('targets', RELEASE_TARGETS))


def metadata(project, ver):
    '''Core metadata 2.4 (`METADATA`) for `project` (`pyproject.toml`'s `[project]`).'''
    lines = [
        'Metadata-Version: 2.4',
        f'Name: {project["name"]}',
        f'Version: {ver}',
        f'Summary: {project["description"]}',
        f'Requires-Python: {project["requires-python"]}',
    ]
    lines += [f'Author: {a["name"]}' for a in project.get('authors', [])]
    if 'license' in project:
        lines.append(f'License-Expression: {project["license"]}')  # SPDX, like `CC0-1.0`
    lines += [f'License-File: {name}' for name in project.get('license-files', [])]
    lines += [f'Classifier: {c}' for c in project.get('classifiers', [])]
    lines += [f'Project-URL: {k}, {v}' for k, v in project.get('urls', {}).items()]
    lines += [f'Requires-Dist: {d}' for d in project.get('dependencies', [])]
    for extra, deps in project.get('optional-dependencies', {}).items():
        lines.append(f'Provides-Extra: {extra}')
        lines += [f'Requires-Dist: {d}; extra == "{extra}"' for d in deps]
    readme = project['readme']
    lines.append(f'Description-Content-Type: {readme["content-type"]}')
    with open(os.path.join(ROOT, readme['file'])) as f:
        return '\n'.join(lines) + '\n\n' + f.read()


def platform_tag(target):
    '''Wheel platform tag for a Zig `target` (`None` = this machine).'''
    if target is None:
        return f'linux_{platform.machine()}'
    m = re.fullmatch(r'(x86_64|aarch64)-linux-(gnu|musl)(?:\.(\d+)\.(\d+))?', target)
    if m is None:
        raise SystemExit(f'unsupported --target {target!r}: want <x86_64|aarch64>-linux-<gnu.2.X|musl>')
    arch, libc, major, minor = m.groups()
    if libc == 'musl':
        return f'musllinux_1_2_{arch}'
    if major is None:
        raise SystemExit(f'--target {target!r}: give the glibc version, like {arch}-linux-gnu.2.28')
    return f'manylinux_{major}_{minor}_{arch}'


def zig_build(abi, target, debug, prefix):
    '''Runs `zig build` into `prefix`; returns the built files (the extension, `<name>.pyi`).'''
    zig = os.environ.get('ZIG', 'zig')
    cmd = [zig, 'build', f'-Dfree-threaded={str(abi.endswith("t")).lower()}', '--prefix', prefix]
    if not debug:
        cmd += ['-Drelease', '-Dstrip']  # build.zig: ReleaseFast, no debug info
    if target is not None:
        cmd.append(f'-Dtarget={target}')
    subprocess.run(cmd, cwd=ROOT, check=True)
    names = sorted(os.listdir(os.path.join(prefix, 'lib')))
    (extension,) = [n for n in names if n.endswith('.so')]
    if target is None and abi == this_abi() and not extension.endswith(sysconfig.get_config_var('EXT_SUFFIX')):
        raise SystemExit(f'built {extension}, but this interpreter wants {sysconfig.get_config_var("EXT_SUFFIX")}')
    return [os.path.join(prefix, 'lib', n) for n in names]


def musl_needed(data, arch):
    '''Returns the ELF64 shared object `data` with `NEEDED libc.so` renamed to `libc.musl-<arch>.so.1`.

    Zig links musl through a stub named `libc.so`; musl itself accepts that name, but Alpine's soname is
    `libc.musl-<arch>.so.1`, the only libc name `auditwheel` accepts for `musllinux`, and what gcc builds
    record. The new name is longer, so it replaces the last strings of `.dynstr` (`libc.so` and the
    `SONAME`, which gcc-built extension modules do not have either) and the zero padding after them.
    '''
    data = bytearray(data)
    if data[:5] != b'\x7fELF\x02' or data[5] != 1:
        raise SystemExit('musl_needed: expected a little-endian ELF64 file')
    phoff, shoff = struct.unpack_from('<QQ', data, 0x20)
    phentsize, phnum, shentsize, shnum = struct.unpack_from('<HHHH', data, 0x36)
    loads, dynamic = [], None
    for i in range(phnum):
        p_type, _, p_offset, p_vaddr, _, p_filesz, _, _ = struct.unpack_from('<IIQQQQQQ', data, phoff + i * phentsize)
        if p_type == 1:  # PT_LOAD
            loads.append((p_vaddr, p_offset, p_filesz))
        elif p_type == 2:  # PT_DYNAMIC
            dynamic = (p_offset, p_filesz)

    def offset(vaddr):
        for start, file_offset, size in loads:
            if start <= vaddr < start + size:
                return vaddr - start + file_offset
        raise SystemExit(f'musl_needed: address {vaddr:#x} is not mapped')

    entries = []  # [index, tag, value] up to the first DT_NULL
    for i in range(dynamic[1] // 16):
        tag, value = struct.unpack_from('<qQ', data, dynamic[0] + i * 16)
        if tag == 0:
            break
        entries.append((i, tag, value))
    find = {tag: (i, value) for i, tag, value in entries if tag in (5, 10, 14)}  # STRTAB, STRSZ, SONAME
    needed = [(i, value) for i, tag, value in entries if tag == 1]
    strtab, strsz = offset(find[5][1]), find[10][1]

    def string(at):
        return bytes(data[strtab + at : data.index(b'\0', strtab + at)])

    (libc,) = [(i, v) for i, v in needed if string(v) == b'libc.so']
    freed = [libc[1]] + ([find[14][1]] if 14 in find else [])
    start = min(freed)
    tail = bytes(data[strtab + start : strtab + strsz])
    if sorted(tail.split(b'\0')[:-1]) != sorted(string(v) for v in freed) or not tail.endswith(b'\0'):
        raise SystemExit('musl_needed: `libc.so` and `SONAME` are not the last strings of .dynstr')
    padding = -(strtab + strsz) % 8
    if any(data[strtab + strsz : strtab + strsz + padding]):
        raise SystemExit('musl_needed: no zero padding after .dynstr')
    name = f'libc.musl-{arch}.so.1'.encode() + b'\0'
    if len(name) > len(tail) + padding:
        raise SystemExit(f'musl_needed: no room for {name!r} in .dynstr')
    data[strtab + start : strtab + strsz + padding] = name.ljust(len(tail) + padding, b'\0')
    struct.pack_into('<Q', data, dynamic[0] + libc[0] * 16 + 8, start)  # NEEDED -> the new name
    struct.pack_into('<Q', data, dynamic[0] + find[10][0] * 16 + 8, start + len(name))  # STRSZ
    if 14 in find:  # drop SONAME: shift the later entries up, the last slot stays DT_NULL
        at = dynamic[0] + find[14][0] * 16
        end = dynamic[0] + dynamic[1]
        data[at : end - 16] = data[at + 16 : end]
        data[end - 16 : end] = bytes(16)
    for i in range(shnum):  # .dynstr section header: sh_size
        base = shoff + i * shentsize
        sh_type, sh_addr = struct.unpack_from('<I', data, base + 4)[0], struct.unpack_from('<Q', data, base + 16)[0]
        if sh_type == 3 and offset(sh_addr) == strtab:
            struct.pack_into('<Q', data, base + 32, start + len(name))
    return bytes(data)


def this_abi():
    '''`cp315t` or `cp315` for the running interpreter.'''
    return 'cp315t' if sysconfig.get_config_var('Py_GIL_DISABLED') else 'cp315'


class Wheel:
    '''Writes a wheel zip and its `RECORD`.'''

    def __init__(self, path):
        self.zip = zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED)
        self.record = []
        epoch = os.environ.get('SOURCE_DATE_EPOCH')
        self.date = EPOCH if epoch is None else time.gmtime(int(epoch))[:6]

    def add(self, name, data, mode=0o644):
        info = zipfile.ZipInfo(name, self.date)
        info.external_attr = (0o100000 | mode) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        self.zip.writestr(info, data)
        digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()
        self.record.append(f'{name},sha256={digest},{len(data)}')

    def close(self, record):
        self.record.append(f'{record},,')
        self.zip.writestr(zipfile.ZipInfo(record, self.date), '\n'.join(self.record) + '\n')
        self.zip.close()


def build(wheel_directory, abi=None, target=None, debug=False):
    '''Builds one wheel into `wheel_directory`; returns its file name.'''
    abi = abi or this_abi()
    project, ver = pyproject(), version()
    name = project['name']
    tag = f'cp315-{abi}-{platform_tag(target)}'
    filename = f'{name}-{ver}-{tag}.whl'
    dist_info = f'{name}-{ver}.dist-info'
    os.makedirs(wheel_directory, exist_ok=True)

    with tempfile.TemporaryDirectory() as prefix:
        built = zig_build(abi, target, debug, prefix)
        wheel = Wheel(os.path.join(wheel_directory, filename))
        package = os.path.join(ROOT, 'src', name)
        for file in sorted(os.listdir(package)):
            if not SKIP.match(file) and os.path.isfile(os.path.join(package, file)):
                with open(os.path.join(package, file), 'rb') as f:
                    wheel.add(f'{name}/{file}', f.read())
        for file in built:
            with open(file, 'rb') as f:
                data = f.read()
            if file.endswith('.so') and target is not None and '-linux-musl' in target:
                data = musl_needed(data, target.split('-')[0])
            wheel.add(f'{name}/{os.path.basename(file)}', data, 0o755 if file.endswith('.so') else 0o644)
        wheel.add(f'{dist_info}/METADATA', metadata(project, ver).encode())
        wheel.add(
            f'{dist_info}/WHEEL',
            f'Wheel-Version: 1.0\nGenerator: setu_build\nRoot-Is-Purelib: false\nTag: {tag}\n'.encode(),
        )
        for license_file in project.get('license-files', []):
            with open(os.path.join(ROOT, license_file), 'rb') as f:
                wheel.add(f'{dist_info}/licenses/{license_file}', f.read())
        wheel.close(f'{dist_info}/RECORD')
    return filename


# --- PEP 517 hooks ----------------------------------------------------------------------


def get_requires_for_build_wheel(config_settings=None):
    '''Nothing to install: the build only needs `zig` on `PATH`.'''
    return []


def build_wheel(wheel_directory, config_settings=None, metadata_directory=None):
    '''Wheel for this interpreter. `pip ... -C target=<zig target>` / `-C debug=1` pass options.'''
    settings = config_settings or {}
    return build(wheel_directory, settings.get('abi'), settings.get('target'), bool(settings.get('debug')))


# --- command line -----------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description=f'Build a {pyproject()["name"]} wheel with zig build.')
    parser.add_argument('--abi', choices=['cp315', 'cp315t'], help='default: this interpreter')
    parser.add_argument('--target', help='Zig target, like x86_64-linux-gnu.2.28 (default: native)')
    parser.add_argument(
        '--all', action='store_true', help='build every release wheel ([tool.setu_build] abis x targets)'
    )
    parser.add_argument('--debug', action='store_true', help='Debug build instead of ReleaseFast')
    parser.add_argument('-o', '--out', default=os.path.join(ROOT, 'dist'), help='output directory (default: dist/)')
    args = parser.parse_args()
    if args.all and (args.abi or args.target):
        parser.error('--all builds every --abi and --target; give neither')
    abis, targets = release_matrix()
    jobs = [(a, t) for a in abis for t in targets] if args.all else [(args.abi, args.target)]
    for abi, target in jobs:
        print(os.path.join(args.out, build(args.out, abi, target, args.debug)))


if __name__ == '__main__':
    main()
