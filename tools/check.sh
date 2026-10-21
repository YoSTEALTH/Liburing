#!/usr/bin/env bash
# Runs every Liburing check: zig fmt, `tools/setu_build.py` against the pinned Setu, `zig build develop` (the one
# stable-ABI `liburing.so`), then with each interpreter (3.15t, 3.15, 3.14t, 3.14) Setu's `check_symbols.py` and
# pytest, then `mypy --strict` (as 3.14 and 3.15) + `stubtest` on `liburing.pyi`.
# Interpreters: PY_FT=... / PY_GIL=... (3.15), PY314_FT=... / PY314_GIL=...; compiler: ZIG=...; Setu checkout:
# SETU=... (default: the `setu` path in build.zig.zon); extra pytest arguments after `--`.
set -euo pipefail

[[ -n ${SETU:-} ]] && SETU=$(realpath -m -- "$SETU") # relative to the caller's cwd, not the repo root
cd "$(dirname "$0")/.."
PY_FT=${PY_FT:-/opt/python/3.15t/bin/python3}
PY_GIL=${PY_GIL:-/opt/python/3.15/bin/python3}
PY314_FT=${PY314_FT:-/opt/python/3.14t/bin/python3}
PY314_GIL=${PY314_GIL:-/opt/python/3.14/bin/python3}
SETU=${SETU:-../../../Setu/Setu/Code}
ZIG=${ZIG:-zig}
[[ ${1:-} == -- ]] && shift
PYTEST_ARGS=("$@")

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "zig fmt"
"$ZIG" fmt --check src tools build.zig build.zig.zon

step "tools/setu_build.py is the pinned Setu's copy"
"$ZIG" build setu-build-check

step "zig build develop"
"$ZIG" build develop # src/liburing/liburing.so: one binary for every interpreter below

for py in "$PY_FT" "$PY_GIL" "$PY314_FT" "$PY314_GIL"; do
    step "$py"
    if [[ -f $SETU/tools/check_symbols.py ]]; then
        "$py" "$SETU/tools/check_symbols.py" src/liburing/liburing.so # exported by $py, and in abi3t (3.15+)
    else
        echo "skipped check_symbols.py: no Setu checkout at $SETU"
    fi
    "$py" -m pytest "${PYTEST_ARGS[@]}"
done

step "mypy --strict + stubtest ($PY_FT)"
if "$PY_FT" -c 'import mypy' 2>/dev/null; then
    (cd src && "$PY_FT" -m mypy --strict --python-version 3.14 liburing/liburing.pyi)
    (cd src && "$PY_FT" -m mypy --strict liburing/liburing.pyi)
    (cd src && PYTHONPATH=. "$PY_FT" -m mypy.stubtest liburing.liburing)
else
    echo "skipped: mypy is not installed for $PY_FT"
fi

step "all checks passed"
