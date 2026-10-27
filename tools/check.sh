#!/usr/bin/env bash
# Runs every Liburing check: zig fmt, Zig line width, ruff (lint + format), `tools/setu_build.py`,
# `tools/setu_docs.py` and `docs/setu-guide.md` against the pinned Setu, `zig build develop` (the one stable-ABI
# `liburing/__init__.so`), then with each interpreter (3.15t, 3.15, 3.14t, 3.14) Setu's `check_symbols.py` and
# pytest, the same with the pre-release 3.16t / 3.16 when installed (`/opt/python/3.16{t,}-dev`), then the docstring
# examples (`setu_docs.py check`), then `mypy --strict` (as 3.14 and 3.15) + `stubtest` on the `liburing` package.
# Interpreters: PY_FT=... / PY_GIL=... (3.15), PY314_FT=... / PY314_GIL=..., PY316_FT=... / PY316_GIL=...;
# compiler: ZIG=...; Setu checkout: SETU=... (default: the `setu` path in build.zig.zon); ruff: RUFF=... (default:
# `ruff` on PATH, else `$PY_FT -m ruff`); extra pytest arguments after `--`.
set -euo pipefail

[[ -n ${SETU:-} ]] && SETU=$(realpath -m -- "$SETU") # relative to the caller's cwd, not the repo root
cd "$(dirname "$0")/.."
PY_FT=${PY_FT:-/opt/python/3.15t/bin/python3}
PY_GIL=${PY_GIL:-/opt/python/3.15/bin/python3}
PY314_FT=${PY314_FT:-/opt/python/3.14t/bin/python3}
PY314_GIL=${PY314_GIL:-/opt/python/3.14/bin/python3}
PY316_FT=${PY316_FT:-/opt/python/3.16t-dev/bin/python3}
PY316_GIL=${PY316_GIL:-/opt/python/3.16-dev/bin/python3}
SETU=${SETU:-../../../Setu/Setu/Code}
ZIG=${ZIG:-zig}
[[ ${1:-} == -- ]] && shift
PYTEST_ARGS=("$@")

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "zig fmt"
"$ZIG" fmt --check src tools example build.zig build.zig.zon

step "Zig lines are at most 120 characters"
# ruff holds Python to `line-length = 120`; `zig fmt` never wraps a long line (only a trailing comma splits a call).
"$PY_FT" - src tools example build.zig <<'PY'
import pathlib
import sys

bad = []
for arg in sys.argv[1:]:
    path = pathlib.Path(arg)
    for file in sorted(path.rglob("*.zig")) if path.is_dir() else [path]:
        for number, line in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
            if len(line) > 120:
                bad.append(f"{file}:{number}: {len(line)} characters")
print("\n".join(bad) or "ok")
sys.exit(1 if bad else 0)
PY

step "ruff check + ruff format --check"
if [[ -n ${RUFF:-} ]]; then
    ruff=("$RUFF")
elif command -v ruff >/dev/null; then
    ruff=(ruff)
elif "$PY_FT" -c 'import ruff' 2>/dev/null; then
    ruff=("$PY_FT" -m ruff)
else
    ruff=()
fi
if ((${#ruff[@]})); then
    "${ruff[@]}" check .
    "${ruff[@]}" format --check .
else
    echo "skipped: no ruff (RUFF=..., on PATH, or installed for $PY_FT)"
fi

step "c.io_uring_submit* only through Ring.submitPtr"
# `submitPtr` makes the in-flight table's entries and runs the skip checks: a submit with any other pointer
# (`checkedPtr`, `_ring`) would send SQEs whose `user_data` is no table index.
for f in src/liburing/*.zig; do
    awk -v f="$f" '
        function check() {
            if (body ~ /c\.io_uring_submit/ && (body !~ /submitPtr\(\)/ || body ~ /checkedPtr\(\)/)) {
                print f ": " name; bad = 1
            }
        }
        /^[[:space:]]*(pub )?(inline )?fn / { check(); name = $0; body = "" }
        { body = body "\n" $0 }
        END { check(); exit bad }
    ' "$f"
done

step "tools/setu_build.py is the pinned Setu's copy"
"$ZIG" build setu-build-check

step "tools/setu_docs.py is the pinned Setu's copy"
"$ZIG" build setu-docs-check

step "docs/setu-guide.md is the pinned Setu's copy"
"$ZIG" build setu-guide-check

step "zig build develop"
"$ZIG" build develop # src/liburing/__init__.so: one binary for every interpreter below

for py in "$PY_FT" "$PY_GIL" "$PY314_FT" "$PY314_GIL"; do
    step "$py"
    if [[ -f $SETU/tools/check_symbols.py ]]; then
        "$py" "$SETU/tools/check_symbols.py" src/liburing/__init__.so # exported by $py, and in abi3t (3.15+)
    else
        echo "skipped check_symbols.py: no Setu checkout at $SETU"
    fi
    "$py" -m pytest "${PYTEST_ARGS[@]}"
done

for py in "$PY316_FT" "$PY316_GIL"; do # pre-release CPython, only where installed (not CI)
    step "$py (pre-release)"
    if [[ ! -x $py ]]; then
        echo "skipped: not installed"
        continue
    fi
    if [[ -f $SETU/tools/check_symbols.py ]]; then
        "$py" "$SETU/tools/check_symbols.py" src/liburing/__init__.so
    else
        echo "skipped check_symbols.py: no Setu checkout at $SETU"
    fi
    "$py" -m pytest "${PYTEST_ARGS[@]}"
done

step "docstring examples ($PY_FT tools/setu_docs.py check)"
"$PY_FT" tools/setu_docs.py check # every `>>>` example in a docstring still prints what it shows

step "mypy --strict + stubtest ($PY_FT)"
if "$PY_FT" -c 'import mypy' 2>/dev/null; then
    (cd src && "$PY_FT" -m mypy --strict --python-version 3.14 -p liburing)
    (cd src && "$PY_FT" -m mypy --strict -p liburing)
    (cd src && PYTHONPATH=. "$PY_FT" -m mypy.stubtest liburing)
else
    echo "skipped: mypy is not installed for $PY_FT"
fi

step "all checks passed"
